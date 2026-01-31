import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../models/split_item.dart';
import '../services/hive_service.dart';
import '../services/category_service.dart';
import '../utils/expression_parser.dart';
import '../widgets/friend_autocomplete.dart';

/// Screen for adding or editing transactions
class AddTransactionScreen extends StatefulWidget {
  final Friend? friend;
  final Transaction? transaction;

  const AddTransactionScreen({
    super.key,
    this.friend,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _itemsController = TextEditingController(); // New controller for split items
  final _friendNameController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _amountFieldKey = GlobalKey();
  final GlobalKey _operatorRowKey = GlobalKey();
  
  TransactionType? _selectedType;
  DateTime _selectedDate = DateTime.now();
  Friend? _selectedFriend;
  String? _selectedFriendName; // Store the display name
  List<Friend> _allFriends = [];
  bool _isLoading = false;
  bool _isNewFriend = false;
  bool _isSplitTransaction = false;
  List<SplitItem> _splitItems = [];
  double? _calculatedAmount;
  String? _expressionError;
  bool _showOperatorButtons = false;
  bool _isSelfTransaction = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _initializeForm();
    
    // Listen to focus changes for amount field
    _amountFocusNode.addListener(() {
      setState(() {
        _showOperatorButtons = _amountFocusNode.hasFocus;
      });
      
      // Auto-scroll when keyboard appears
      if (_amountFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_operatorRowKey.currentContext != null && _scrollController.hasClients) {
            final RenderBox renderBox = _operatorRowKey.currentContext!.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            final screenHeight = MediaQuery.of(context).size.height;
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final visibleHeight = screenHeight - keyboardHeight;
            
            final bottomOfRow = position.dy + size.height;
            
            // Check if bottom of row is visible (with small buffer)
            if (bottomOfRow > visibleHeight - 10) {
              // Not fully visible, scroll just enough
              _scrollController.animateTo(
                _scrollController.offset + 120,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });
      }
    });
  }
  
  // void _scrollToAmountField() {
  //   if (_amountFieldKey.currentContext != null) {
  //     final RenderBox? renderBox = 
  //         _amountFieldKey.currentContext!.findRenderObject() as RenderBox?;
      
  //     if (renderBox != null) {
  //       final position = renderBox.localToGlobal(Offset.zero);
  //       final screenHeight = MediaQuery.of(context).size.height;
  //       final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        
  //       // Calculate scroll offset to show amount field and operator buttons
  //       // Add extra space for operator buttons (approximately 60px)
  //       final targetScroll = _scrollController.offset + 
  //           position.dy - 
  //           (screenHeight - keyboardHeight) / 2 +
  //           60;
        
  //       _scrollController.animateTo(
  //         targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     }
  //   }
  // }

  void _loadFriends() {
    _allFriends = HiveService.getAllFriends();
  }

  void _initializeForm() {
    if (widget.friend != null) {
      if (widget.friend!.id == 'self') {
        _isSelfTransaction = true;
      } else {
        _selectedFriend = widget.friend;
        _friendNameController.text = widget.friend!.name;
        _selectedFriendName = widget.friend!.name;
      }
    }

    if (widget.transaction != null) {
      final transaction = widget.transaction!;
      
      if (transaction.hasSplitItems) {
        // Initialize with split items
        _isSplitTransaction = true;
        _splitItems = List.from(transaction.splitItems!);
        
        // Reconstruct expression from split items
        final amounts = _splitItems.map((item) => item.amount.toString()).join('+');
        _amountController.text = amounts;
        
        // Note contains the descriptions
        _noteController.text = transaction.note;
        
        // Populate items controller from split items descriptions
        _itemsController.text = _splitItems.map((item) => item.description).join(' ');
      } else {
        _amountController.text = transaction.amount.toString();
        _noteController.text = transaction.note;
      }
      
      _selectedType = transaction.type;
      _selectedDate = transaction.date;
      _updateCalculatedAmount();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _itemsController.dispose();
    _friendNameController.dispose();
    _amountFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return (_calculatedAmount != null && _calculatedAmount! > 0) &&
           _selectedType != null &&
           (_isSelfTransaction || _selectedFriend != null || _friendNameController.text.isNotEmpty);
  }
  
  void _updateCalculatedAmount() {
    final expression = _amountController.text.trim();
    
    if (expression.isEmpty) {
      setState(() {
        _calculatedAmount = null;
        _expressionError = null;
        _splitItems = [];
        _isSplitTransaction = false;
      });
      return;
    }
    
    // Try to evaluate the expression
    final result = ExpressionParser.evaluateExpression(expression);
    
    if (result == null || result <= 0) {
      setState(() {
        _calculatedAmount = null;
        _expressionError = 'Invalid expression';
        _splitItems = [];
        _isSplitTransaction = false;
      });
      return;
    }
    
    setState(() {
      _calculatedAmount = result;
      _expressionError = null;
      
      // Check if this is a split transaction (multiple amounts)
      final amounts = ExpressionParser.extractAmounts(expression);
      if (amounts.length > 1) {
        _isSplitTransaction = true;
        // Don't parse descriptions yet - just show preview with Item 1, Item 2, etc.
        _splitItems = amounts.asMap().entries.map((entry) {
          return SplitItem(
            amount: entry.value.abs(),
            description: 'Item ${entry.key + 1}',
            isNegative: entry.value < 0,
          );
        }).toList();
      } else {
        _isSplitTransaction = false;
        _splitItems = [];
      }
    });
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

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = _calculatedAmount!;
      final note = _noteController.text.trim();
      final itemsText = _itemsController.text.trim();
      final expression = _amountController.text.trim();
      
      // Parse split items with descriptions ONLY when saving
      List<SplitItem>? finalSplitItems;
      if (_isSplitTransaction && itemsText.isNotEmpty) {
        // Parse descriptions from items field
        finalSplitItems = ExpressionParser.parseWithDescriptions(expression, itemsText);
      } else if (_isSplitTransaction) {
        // No descriptions provided, use "Item N"
        finalSplitItems = _splitItems;
      }
      
      // Handle friend selection or creation
      Friend targetFriend;
      
      if (_isSelfTransaction) {
        // Use or create 'self' friend
        final existingSelf = _allFriends.firstWhere(
          (f) => f.id == 'self',
          orElse: () => Friend(id: '', name: ''),
        );
        
        if (existingSelf.id.isNotEmpty) {
          targetFriend = existingSelf;
        } else {
          targetFriend = Friend(
            id: 'self',
            name: 'Self',
          );
          await HiveService.saveFriend(targetFriend);
        }
      } else if (_selectedFriend != null && !_isNewFriend) {
        targetFriend = _selectedFriend!;
      } else {
        // Use the selected friend name or text field value
        String friendName = _selectedFriendName?.trim() ?? _friendNameController.text.trim();
        
        // Capitalize Friend Name (Fix 5)
        if (friendName.isNotEmpty) {
          friendName = friendName[0].toUpperCase() + friendName.substring(1).toLowerCase();
        }
        
        // Case-insensitive check for existing friend
        final existingFriend = _allFriends.firstWhere(
          (f) => f.name.toLowerCase() == friendName.toLowerCase(),
          orElse: () => Friend(id: '', name: ''),
        );
        
        if (existingFriend.id.isNotEmpty) {
          // Friend exists, use it
          targetFriend = existingFriend;
        } else {
          // Auto-create friend without confirmation for single transactions
          targetFriend = Friend(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: friendName,
          );
          
          await HiveService.saveFriend(targetFriend);
        }
      }

      // Check for 12-month history limit
      // DISABLED to prevent truncation bug
      /*
      if (widget.transaction == null && HiveService.shouldCleanupHistory(_selectedDate)) {
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Older months detected'),
            content: const Text('Do you want to delete data older than 12 months?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep For Now'),
              ),
            ],
          ),
        );
        
        if (shouldDelete == true) {
          await HiveService.cleanupOldHistory();
        }
      }
      */

      // Create or update transaction
      final transaction = Transaction(
        id: widget.transaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: _selectedType!,
        note: note,
        date: _selectedDate,
        splitItems: finalSplitItems,
      );

      if (widget.transaction != null) {
        // Update existing transaction
        await HiveService.updateTransaction(targetFriend.id, transaction);
      } else {
        // Add new transaction
        await HiveService.addTransaction(targetFriend.id, transaction);
      }

      // Learn note into Trie for future suggestions (ALL transactions, not just self)
      // This populates the global vocabulary for autocomplete
      if (widget.transaction == null && note.isNotEmpty) {
        await CategoryService.learnCategory(note);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
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

  Widget _buildOperatorButton(String operator, {bool isSpecial = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            if (operator == 'C') {
              // Clear button
              _amountController.clear();
              _updateCalculatedAmount();
            } else {
              // Insert operator at cursor position
              final text = _amountController.text;
              final selection = _amountController.selection;
              final newText = text.replaceRange(
                selection.start,
                selection.end,
                operator,
              );
              _amountController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: selection.start + operator.length,
                ),
              );
              _updateCalculatedAmount();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSpecial 
                ? Theme.of(context).colorScheme.error 
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            operator,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Build note field with autocomplete suggestions.
  /// Suggestions come from the Trie populated by ALL past transaction notes.
  Widget _buildNoteCategoryAutocomplete() {
    return Autocomplete<String>(
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
        // Sync the controllers
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
            hintText: 'e.g., Groceries, Food, Lunch',
            helperText: 'Type to see suggestions from past transactions',
          ),
          maxLines: 1,
          validator: (value) {
            // Only validate word count for non-split transactions
            if (!_isSplitTransaction && value != null && value.trim().isNotEmpty) {
              final wordCount = value.trim().split(RegExp(r'\s+')).length;
              if (wordCount > 5) {
                return 'Note cannot exceed 5 words for single transactions';
              }
            }
            return null;
          },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          TextButton(
            onPressed: _isFormValid && !_isLoading ? _saveTransaction : null,
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
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Transaction Mode Toggle
            if (widget.transaction == null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Friend'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Self'),
                        icon: Icon(Icons.person_outline),
                      ),
                    ],
                    selected: {_isSelfTransaction},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isSelfTransaction = newSelection.first;
                        // Reset friend selection if switching to self
                        if (_isSelfTransaction) {
                          _selectedFriend = null;
                          _friendNameController.clear();
                        }
                      });
                    },
                  ),
                ),
              ),
            ],

            // Friend selection (only if not self transaction)
            if (!_isSelfTransaction)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friend',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Simple friend name input with autocomplete
                      FriendAutocomplete(
                          controller: _friendNameController,
                          existingFriends: _allFriends.where((f) => f.id != 'self').map((f) => f.name).toList(),
                          onFriendSelected: (name) {
                            // Check if this friend exists (case-insensitive)
                            final existingFriend = _allFriends.firstWhere(
                              (f) => f.name.toLowerCase() == name.toLowerCase().trim(),
                              orElse: () => Friend(id: '', name: ''),
                            );
                            
                            setState(() {
                              _selectedFriendName = name; // Store the display name
                              if (existingFriend.id.isNotEmpty) {
                                _selectedFriend = existingFriend;
                                _isNewFriend = false;
                              } else {
                                _selectedFriend = null;
                                _isNewFriend = true;
                              }
                            });
                          },
                          enabled: widget.friend == null,
                          validator: (value) {
                            if (!_isSelfTransaction && (value == null || value.trim().isEmpty)) {
                              return 'Please enter friend name';
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Transaction details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Transaction type (moved to top)
                    Text(
                      'Type',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: Text(_isSelfTransaction ? 'Spent' : 'Lend'),
                            subtitle: Text(_isSelfTransaction ? 'Money Out' : 'I gave money'),
                            value: TransactionType.lent,
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value;
                              });
                            },
                          ),
                        ),
                        
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: Text(_isSelfTransaction ? 'Gained' : 'Borrow'),
                            subtitle: Text(_isSelfTransaction ? 'Money In' : 'I received money'),
                            value: TransactionType.borrowed,
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Amount
                    Container(
                      key: _amountFieldKey,
                      child: TextFormField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹',
                          border: const OutlineInputBorder(),
                          hintText: 'e.g., 100 or 20+30+50',
                          helperText: 'Use operator buttons below for calculations',
                          errorText: _expressionError,
                          suffixIcon: _calculatedAmount != null
                              ? Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    '= ₹${_calculatedAmount!.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _updateCalculatedAmount(),
                      ),
                    ),
                    
                    // Operator buttons (shown when amount field is focused)
                    if (_showOperatorButtons) ...[
                      const SizedBox(height: 8),
                      Row(
                        key: _operatorRowKey,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOperatorButton('+'),
                          _buildOperatorButton('-'),
                          _buildOperatorButton('*'),
                          _buildOperatorButton('/'),
                          _buildOperatorButton('C', isSpecial: true),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Split Items Input
                    if (_isSplitTransaction) ...[
                      TextFormField(
                        controller: _itemsController,
                        decoration: const InputDecoration(
                          labelText: 'Item Names',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., corn coke cake (space or comma separated)',
                          helperText: 'Enter item names. Names will be mapped to amounts when you save.',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Note (Regular note) - with autocomplete suggestions for all transactions
                    _buildNoteCategoryAutocomplete(),
                    
                    if (_splitItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      
                      // Split items preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Split Items Preview',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._splitItems.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.description,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item.isNegative ? "-" : ""}₹${item.amount.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: item.isNegative ? Colors.red : null,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${_calculatedAmount!.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Date
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
                onPressed: _isFormValid && !_isLoading ? _saveTransaction : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.transaction != null ? 'Update Transaction' : 'Save Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}