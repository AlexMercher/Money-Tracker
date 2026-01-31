import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/friend.dart';
import '../models/friend_split.dart';
import '../models/transaction.dart';
import '../models/split_item.dart';
import '../services/hive_service.dart';
import '../services/category_service.dart';
import '../utils/expression_parser.dart';

/// Screen for splitting a transaction among multiple friends
class SplitTransactionScreen extends StatefulWidget {
  const SplitTransactionScreen({super.key});

  @override
  State<SplitTransactionScreen> createState() => _SplitTransactionScreenState();
}

class _SplitTransactionScreenState extends State<SplitTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  final _noteController = TextEditingController();
  final List<TextEditingController> _amountControllers = [];
  final List<TextEditingController> _friendControllers = [];
  final List<FocusNode> _friendFocusNodes = [];
  
  DateTime _selectedDate = DateTime.now();
  List<Friend> _allFriends = [];
  List<FriendSplit> _friendSplits = [];
  bool _isLoading = false;
  bool _isSplitEqual = true;
  bool _showOperatorButtons = false;
  final FocusNode _totalAmountFocusNode = FocusNode();
  double? _totalAmount;
  double? _myShare;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _addInitialFriendSplit();
    _totalAmountFocusNode.addListener(() {
      setState(() {
        _showOperatorButtons = _totalAmountFocusNode.hasFocus;
        if (!_totalAmountFocusNode.hasFocus) {
           _updateTotalAmount();
        }
      });
    });
  }

  @override
  void dispose() {
    _totalAmountFocusNode.dispose();
    _totalAmountController.dispose();
    _noteController.dispose();
    for (var controller in _amountControllers) {
      controller.dispose();
    }
    for (var controller in _friendControllers) {
      controller.dispose();
    }
    for (var node in _friendFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _loadFriends() {
    _allFriends = HiveService.getAllFriends()
        .where((f) => f.id != 'cash_ledger' && f.id != 'self') // Exclude cash ledger and self
        .toList();
  }

  void _addInitialFriendSplit() {
    _friendSplits.add(FriendSplit(friendName: '', amount: 0));
    _amountControllers.add(TextEditingController());
    _friendControllers.add(TextEditingController());
    _friendFocusNodes.add(FocusNode());
  }

  void _addFriendSplit() {
    setState(() {
      _friendSplits.add(FriendSplit(friendName: '', amount: 0));
      _amountControllers.add(TextEditingController());
      _friendControllers.add(TextEditingController());
      _friendFocusNodes.add(FocusNode());
    });
  }

  void _removeFriendSplit(int index) {
    if (_friendSplits.length > 1) {
      setState(() {
        _friendSplits.removeAt(index);
        _amountControllers[index].dispose();
        _amountControllers.removeAt(index);
        _friendControllers[index].dispose();
        _friendControllers.removeAt(index);
        _friendFocusNodes[index].dispose();
        _friendFocusNodes.removeAt(index);
        _calculateSplit();
      });
    }
  }

  void _updateTotalAmount() {
    final expression = _totalAmountController.text.trim();
    if (expression.isEmpty) {
      setState(() {
        _totalAmount = null;
        _calculateSplit();
      });
      return;
    }

    final result = ExpressionParser.evaluateExpression(expression);
    setState(() {
      _totalAmount = result;
      _calculateSplit();
    });
  }

  void _calculateSplit() {
    if (_totalAmount == null) {
      if (_myShare != null) {
        setState(() {
          _myShare = null;
        });
      }
      return;
    }

    if (_isSplitEqual) {
      // Equal split among all friends + me
      // Count all split rows as participants, even if name is empty yet
      final totalPeople = _friendSplits.length + 1; // friends + me
      final perPerson = _totalAmount! / totalPeople;
      
      bool needsUpdate = false;
      for (var split in _friendSplits) {
        if (split.amount != perPerson) {
          split.amount = perPerson;
          needsUpdate = true;
        }
      }
      
      if (_myShare != perPerson || needsUpdate) {
        setState(() {
          _myShare = perPerson;
        });
      }
    } else {
      // Calculate remaining for me
      final totalSplitAssigned = _friendSplits.fold(0.0, (sum, fs) => sum + fs.amount);
      final newMyShare = _totalAmount! - totalSplitAssigned;
      
      if (_myShare != newMyShare) {
        setState(() {
          _myShare = newMyShare;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final oneYearAgo = DateTime(now.year - 1, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: oneYearAgo,
      lastDate: now,
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildMainOperatorButton(String operator, {bool isSpecial = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          onPressed: () {
            if (operator == 'C') {
              _totalAmountController.clear();
              setState(() {
                _totalAmount = null;
                _calculateSplit();
              });
            } else {
              final text = _totalAmountController.text;
              final selection = _totalAmountController.selection;
              
              // Handle case where selection is invalid (e.g. -1)
              final start = selection.start >= 0 ? selection.start : text.length;
              final end = selection.end >= 0 ? selection.end : text.length;
              
              final newText = text.replaceRange(start, end, operator);
              _totalAmountController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: start + operator.length,
                ),
              );
              _updateTotalAmount();
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            backgroundColor: isSpecial
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: isSpecial
                ? Theme.of(context).colorScheme.onError
                : Theme.of(context).colorScheme.onSurfaceVariant,
            elevation: 0,
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            operator,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String operator, int friendIndex, {bool isSpecial = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          onPressed: () {
            final controller = _amountControllers[friendIndex];
            if (operator == 'C') {
              // Clear button
              controller.clear();
              setState(() {
                _friendSplits[friendIndex].amount = 0;
                _calculateSplit();
              });
            } else {
              // Insert operator at cursor position
              final text = controller.text;
              final selection = controller.selection;
              final newText = text.replaceRange(
                selection.start,
                selection.end,
                operator,
              );
              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: selection.start + operator.length,
                ),
              );
              // Evaluate and update
              final result = ExpressionParser.evaluateExpression(newText);
              setState(() {
                _friendSplits[friendIndex].amount = result ?? 0;
                _calculateSplit();
              });
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            backgroundColor: isSpecial
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: isSpecial
                ? Theme.of(context).colorScheme.onError
                : Theme.of(context).colorScheme.onSurfaceVariant,
            elevation: 0,
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            operator,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  bool get _isFormValid {
    return _totalAmount != null &&
           _totalAmount! > 0 &&
           _myShare != null &&
           _myShare! >= 0 && // My share cannot be negative
           _friendSplits.any((fs) => fs.friendName.trim().isNotEmpty) &&
           (_isSplitEqual || _friendSplits.every((fs) => 
              fs.friendName.trim().isEmpty || fs.amount > 0));
  }

  Future<bool> _confirmNewFriend(String friendName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Friend?'),
        content: Text(
          'Friend "$friendName" doesn\'t exist. Do you want to create a new friend with this name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _processSplit() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    // Check for duplicate friend names
    final friendNames = _friendSplits
        .where((fs) => fs.friendName.trim().isNotEmpty)
        .map((fs) => fs.friendName.trim().toLowerCase())
        .toList();
    
    final uniqueNames = friendNames.toSet();
    if (friendNames.length != uniqueNames.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error: You cannot add the same friend multiple times. Please remove duplicates.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Additional validation: check for negative my share
    if (_myShare == null || _myShare! < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error: Friend amounts exceed the total amount. Please adjust the amounts.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final note = _noteController.text.trim();
      final baseNote = note.isNotEmpty ? note : 'Split transaction';
      
      // Filter valid friend splits
      final validSplits = _friendSplits
          .where((fs) => fs.friendName.trim().isNotEmpty && fs.amount > 0)
          .toList();

      // Check which friends exist and which need to be created
      final Map<String, Friend> existingFriends = {};
      final List<FriendSplit> newFriendsToCreate = [];

      for (var split in validSplits) {
        final normalizedName = split.friendName.trim();
        
        // Case-insensitive search for existing friend
        final existingFriend = _allFriends.firstWhere(
          (f) => f.name.toLowerCase() == normalizedName.toLowerCase(),
          orElse: () => Friend(id: '', name: ''),
        );

        if (existingFriend.id.isNotEmpty) {
          existingFriends[normalizedName] = existingFriend;
          split.isExistingFriend = true;
        } else {
          newFriendsToCreate.add(split);
        }
      }

      // Confirm creation of new friends
      for (var split in newFriendsToCreate) {
        final shouldCreate = await _confirmNewFriend(split.friendName);
        if (!shouldCreate) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Show summary before processing
      final confirmed = await _showSummaryDialog(validSplits, existingFriends);
      if (!confirmed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Build split info items for storage
      final List<SplitItem> splitItems = [];
      
      for (var fs in validSplits) {
        splitItems.add(SplitItem(
          amount: fs.amount,
          description: fs.friendName.trim(),
        ));
      }
      
      // Add self share to split items
      if (_myShare != null && _myShare! > 0) {
        splitItems.add(SplitItem(
          amount: _myShare!,
          description: 'You (My Share)',
        ));
      }

      // Process transactions
      for (var split in validSplits) {
        final normalizedName = split.friendName.trim();
        Friend targetFriend;

        if (existingFriends.containsKey(normalizedName)) {
          targetFriend = existingFriends[normalizedName]!;
        } else {
          // Create new friend
          targetFriend = Friend(
            id: DateTime.now().millisecondsSinceEpoch.toString() + normalizedName.hashCode.toString(),
            name: normalizedName,
          );
          await HiveService.saveFriend(targetFriend);
        }

        // Create transaction for this friend with split items
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + targetFriend.id.hashCode.toString(),
          amount: split.amount,
          type: TransactionType.lent, // You paid, so you lent money
          note: baseNote, // Clean note
          date: _selectedDate,
          splitItems: List.from(splitItems), // Store full split details
        );

        await HiveService.addTransaction(targetFriend.id, transaction);
      }

      // Add Self Transaction for my share
      if (_myShare != null && _myShare! > 0) {
        // Check if 'self' friend exists, if not create it
        // FIX: Use HiveService.getFriend directly to avoid overwriting existing self history
        // with a new empty friend object if _allFriends doesn't contain it.
        Friend? selfFriend = HiveService.getFriend('self');
        
        if (selfFriend == null) {
           selfFriend = Friend(id: 'self', name: 'Self');
           await HiveService.saveFriend(selfFriend);
        }

        final selfTransaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + 'self_share',
          amount: _myShare!,
          type: TransactionType.lent, // Spent
          note: '$baseNote (My Share)',
          date: _selectedDate,
          splitItems: List.from(splitItems), // Store full split details
        );
        
        await HiveService.addTransaction('self', selfTransaction);
      }

      // Learn note into Trie for future suggestions (only if valid note provided)
      if (note.isNotEmpty) {
        await CategoryService.learnCategory(note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split transaction created for ${validSplits.length} friend(s)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing split: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showSummaryDialog(List<FriendSplit> validSplits, Map<String, Friend> existingFriends) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Split Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Paid: ₹${_totalAmount!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Share: ₹${_myShare!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 24),
              Text(
                'Friends will owe you:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...validSplits.map((split) {
                final normalizedName = split.friendName.trim();
                final isExisting = existingFriends.containsKey(normalizedName);
                final status = isExisting ? 'Update' : 'New';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isExisting ? Icons.person : Icons.person_add,
                        size: 16,
                        color: isExisting ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${split.friendName} ($status)',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${split.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Transaction'),
        actions: [
          TextButton(
            onPressed: _isFormValid && !_isLoading ? _processSplit : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total amount card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalAmountController,
                      focusNode: _totalAmountFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Total Amount Paid',
                        prefixText: '₹',
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., 500 or 100+200',
                        helperText: 'Enter the total bill amount',
                        suffixIcon: _totalAmount != null
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  '= ₹${_totalAmount!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateTotalAmount(),
                    ),
                    
                    if (_showOperatorButtons) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMainOperatorButton('+'),
                          _buildMainOperatorButton('-'),
                          _buildMainOperatorButton('*'),
                          _buildMainOperatorButton('/'),
                          _buildMainOperatorButton('C', isSpecial: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // My Share Display
            if (_myShare != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _myShare! < 0 
                      ? Colors.red.withOpacity(0.1) 
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _myShare! < 0 
                        ? Colors.red.withOpacity(0.3) 
                        : Colors.green.withOpacity(0.3), 
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Share',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${_myShare!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _myShare! < 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_myShare! < 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: Friend amounts exceed total. Reduce amounts or increase total.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Split type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Equal Split'),
                          icon: Icon(Icons.balance),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Custom Split'),
                          icon: Icon(Icons.edit),
                        ),
                      ],
                      selected: {_isSplitEqual},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isSplitEqual = newSelection.first;
                          _calculateSplit();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Friends list
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Split With Friends',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: _addFriendSplit,
                          tooltip: 'Add Friend',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    ..._friendSplits.asMap().entries.map((entry) {
                      final index = entry.key;
                      final split = entry.value;
                      final amountText = _amountControllers[index].text;
                      final showCalculatorButtons = !_isSplitEqual && amountText.isNotEmpty;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: RawAutocomplete<String>(
                                        key: ValueKey('friend_$index'),
                                        focusNode: _friendFocusNodes[index],
                                        textEditingController: _friendControllers[index],
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return const Iterable<String>.empty();
                                          }
                                          return _allFriends
                                              .map((f) => f.name)
                                              .where((name) => name.toLowerCase().contains(
                                                    textEditingValue.text.toLowerCase(),
                                                  ));
                                        },
                                        onSelected: (String selection) {
                                          setState(() {
                                            split.friendName = selection;
                                            _calculateSplit();
                                          });
                                        },
                                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                          return TextFormField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            decoration: InputDecoration(
                                              labelText: 'Friend ${index + 1}',
                                              hintText: 'Enter friend name',
                                              border: const OutlineInputBorder(),
                                              suffixIcon: const Icon(Icons.person),
                                              helperText: _allFriends.isNotEmpty ? 'Start typing for suggestions' : null,
                                              helperMaxLines: 1,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return null; // Allow empty for now
                                              }
                                              // Check for duplicate names
                                              final trimmedValue = value.trim().toLowerCase();
                                              final duplicateCount = _friendSplits
                                                  .where((fs) => fs.friendName.trim().toLowerCase() == trimmedValue)
                                                  .length;
                                              if (duplicateCount > 1) {
                                                return 'This friend is already added';
                                              }
                                              return null;
                                            },
                                            onChanged: (name) {
                                              split.friendName = name;
                                              // Only recalculate if in equal split mode (to update per-person amount)
                                              if (_isSplitEqual) {
                                                _calculateSplit();
                                              }
                                            },
                                            onFieldSubmitted: (value) => onFieldSubmitted(),
                                          );
                                        },
                                        optionsViewBuilder: (context, onSelected, options) {
                                          return Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              elevation: 4.0,
                                              child: SizedBox(
                                                width: 250,
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder: (BuildContext context, int index) {
                                                    final String option = options.elementAt(index);
                                                    return ListTile(
                                                      title: Text(option),
                                                      onTap: () {
                                                        onSelected(option);
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    
                                    // Show amount badge next to friend name if equal split or amount is set
                                    if (_isSplitEqual && split.amount > 0) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₹${split.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ] else if (!_isSplitEqual && split.amount > 0 && amountText.isEmpty) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₹${split.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    
                                    if (_friendSplits.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Theme.of(context).colorScheme.error,
                                        onPressed: () => _removeFriendSplit(index),
                                      ),
                                  ],
                                ),
                                
                                // Amount input below friend name (only shown in manual split mode)
                                if (!_isSplitEqual) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _amountControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Amount',
                                      prefixText: '₹',
                                      border: const OutlineInputBorder(),
                                      helperText: amountText.isNotEmpty ? 'Use +, -, *, /' : null,
                                      helperMaxLines: 1,
                                      suffixIcon: split.amount > 0
                                          ? Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                '=${split.amount.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (value) {
                                      // Don't call setState here to avoid keyboard focus issues
                                      final result = ExpressionParser.evaluateExpression(value);
                                      split.amount = result ?? 0;
                                      _calculateSplit();
                                    },
                                  ),
                                  
                                  // Calculator buttons (only shown when amount field has text)
                                  if (showCalculatorButtons) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildOperatorButton('+', index),
                                        _buildOperatorButton('-', index),
                                        _buildOperatorButton('*', index),
                                        _buildOperatorButton('/', index),
                                        _buildOperatorButton('C', index, isSpecial: true),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Note and date
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Note field with autocomplete suggestions
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return await CategoryService.getSuggestions(textEditingValue.text);
                      },
                      onSelected: (String selection) {
                        _noteController.text = selection;
                      },
                      fieldViewBuilder: (
                        BuildContext context,
                        TextEditingController fieldController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        // Sync controllers
                        if (_noteController.text.isNotEmpty && fieldController.text.isEmpty) {
                          fieldController.text = _noteController.text;
                        }
                        fieldController.addListener(() {
                          if (_noteController.text != fieldController.text) {
                            _noteController.text = fieldController.text;
                          }
                        });
                        
                        return TextFormField(
                          controller: fieldController,
                          focusNode: fieldFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Restaurant bill, Movie tickets',
                            helperText: 'Type to see suggestions',
                          ),
                          maxLines: 1,
                        );
                      },
                      optionsViewBuilder: (
                        BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option),
                                    leading: const Icon(Icons.history, size: 18),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFormValid && !_isLoading ? _processSplit : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Process Split Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
