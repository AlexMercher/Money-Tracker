import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/friend.dart';
import '../models/friend_split.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
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
  
  DateTime _selectedDate = DateTime.now();
  List<Friend> _allFriends = [];
  List<FriendSplit> _friendSplits = [];
  bool _isLoading = false;
  bool _isSplitEqual = true;
  double? _totalAmount;
  double? _myShare;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _addInitialFriendSplit();
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _noteController.dispose();
    for (var controller in _amountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadFriends() {
    _allFriends = HiveService.getAllFriends();
  }

  void _addInitialFriendSplit() {
    _friendSplits.add(FriendSplit(friendName: '', amount: 0));
    _amountControllers.add(TextEditingController());
  }

  void _addFriendSplit() {
    setState(() {
      _friendSplits.add(FriendSplit(friendName: '', amount: 0));
      _amountControllers.add(TextEditingController());
    });
  }

  void _removeFriendSplit(int index) {
    if (_friendSplits.length > 1) {
      setState(() {
        _friendSplits.removeAt(index);
        _amountControllers[index].dispose();
        _amountControllers.removeAt(index);
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
      final validFriends = _friendSplits.where((fs) => fs.friendName.trim().isNotEmpty).length;
      if (validFriends > 0) {
        final totalPeople = validFriends + 1; // friends + me
        final perPerson = _totalAmount! / totalPeople;
        
        bool needsUpdate = false;
        for (var split in _friendSplits) {
          if (split.friendName.trim().isNotEmpty && split.amount != perPerson) {
            split.amount = perPerson;
            needsUpdate = true;
          }
        }
        
        if (_myShare != perPerson || needsUpdate) {
          setState(() {
            _myShare = perPerson;
          });
        }
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
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
                : Theme.of(context).primaryColor.withOpacity(0.1),
            foregroundColor: isSpecial
                ? Colors.white
                : Theme.of(context).primaryColor,
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

      // Build split info showing all friends involved
      final friendsSplitInfo = validSplits.map((fs) => 
        '${fs.friendName.trim()} (Rs. ${fs.amount.toStringAsFixed(2)})'
      ).toList();
      friendsSplitInfo.add('You (Rs. ${_myShare!.toStringAsFixed(2)})');
      
      final splitDetailsNote = '\nSplit of Rs. ${_totalAmount!.toStringAsFixed(2)} between: ${friendsSplitInfo.join(', ')}';

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

        // Create transaction for this friend with full split details
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + targetFriend.id.hashCode.toString(),
          amount: split.amount,
          type: TransactionType.lent, // You paid, so you lent money
          note: '$baseNote$splitDetailsNote',
          date: _selectedDate,
        );

        await HiveService.addTransaction(targetFriend.id, transaction);
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
                        ),
                      ),
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
                      decoration: InputDecoration(
                        labelText: 'Total Amount Paid',
                        prefixText: '₹',
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., 500',
                        helperText: 'Enter the total bill amount',
                        suffixIcon: _totalAmount != null
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  '= ₹${_totalAmount!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateTotalAmount(),
                    ),
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
                                      child: Autocomplete<String>(
                                        key: ValueKey('friend_$index'),
                                        initialValue: TextEditingValue(text: split.friendName),
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
                                          // Update controller if initialValue changes
                                          if (controller.text != split.friendName) {
                                            controller.text = split.friendName;
                                          }
                                          
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
                                      ),
                                    ),
                                    
                                    // Show amount badge next to friend name if equal split or amount is set
                                    if (_isSplitEqual && split.amount > 0) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₹${split.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ] else if (!_isSplitEqual && split.amount > 0 && amountText.isEmpty) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₹${split.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
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
                                                  color: Theme.of(context).primaryColor,
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
                    
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Restaurant bill, Movie tickets',
                      ),
                      maxLines: 2,
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
