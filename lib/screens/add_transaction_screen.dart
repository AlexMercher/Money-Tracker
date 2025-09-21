import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';

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
  final _friendNameController = TextEditingController();
  
  TransactionType? _selectedType;
  DateTime _selectedDate = DateTime.now();
  Friend? _selectedFriend;
  List<Friend> _allFriends = [];
  bool _isLoading = false;
  bool _isNewFriend = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _initializeForm();
  }

  void _loadFriends() {
    _allFriends = HiveService.getAllFriends();
  }

  void _initializeForm() {
    if (widget.friend != null) {
      _selectedFriend = widget.friend;
      _friendNameController.text = widget.friend!.name;
    }

    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _noteController.text = widget.transaction!.note;
      _selectedType = widget.transaction!.type;
      _selectedDate = widget.transaction!.date;
    }
  }

  bool get _isFormValid {
    return _amountController.text.isNotEmpty &&
           _selectedType != null &&
           (_selectedFriend != null || _friendNameController.text.isNotEmpty);
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

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();
      
      // Handle friend selection or creation
      Friend targetFriend;
      
      if (_selectedFriend != null && !_isNewFriend) {
        targetFriend = _selectedFriend!;
      } else {
        // Create new friend or find existing one
        final friendName = _friendNameController.text.trim();
        
        if (HiveService.friendNameExists(friendName, excludeId: _selectedFriend?.id)) {
          throw Exception('Friend with this name already exists');
        }
        
        targetFriend = Friend(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: friendName,
        );
        
        await HiveService.saveFriend(targetFriend);
      }

      // Create or update transaction
      final transaction = Transaction(
        id: widget.transaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: _selectedType!,
        note: note,
        date: _selectedDate,
      );

      if (widget.transaction != null) {
        // Update existing transaction
        await HiveService.updateTransaction(targetFriend.id, transaction);
      } else {
        // Add new transaction
        await HiveService.addTransaction(targetFriend.id, transaction);
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
          padding: const EdgeInsets.all(16),
          children: [
            // Friend selection
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
                    
                    if (_allFriends.isNotEmpty && widget.friend == null) ...[
                      DropdownButtonFormField<Friend>(
                        value: _selectedFriend,
                        decoration: const InputDecoration(
                          labelText: 'Select existing friend',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Friend>(
                            value: null,
                            child: Text('Add new friend'),
                          ),
                          ..._allFriends.map((friend) => DropdownMenuItem<Friend>(
                            value: friend,
                            child: Text(friend.name),
                          )),
                        ],
                        onChanged: (friend) {
                          setState(() {
                            _selectedFriend = friend;
                            _isNewFriend = friend == null;
                            if (friend != null) {
                              _friendNameController.text = friend.name;
                            } else {
                              _friendNameController.clear();
                            }
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                    ],
                    
                    if (_selectedFriend == null || _isNewFriend || widget.friend != null)
                      TextFormField(
                        controller: _friendNameController,
                        decoration: const InputDecoration(
                          labelText: 'Friend name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: widget.friend == null,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
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
                    
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Transaction type
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
                            title: const Text('Lent'),
                            subtitle: const Text('I gave money'),
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
                            title: const Text('Borrowed'),
                            subtitle: const Text('I received money'),
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
                    
                    const SizedBox(height: 16),
                    
                    // Note
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Add a note about this transaction',
                      ),
                      maxLines: 3,
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

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _friendNameController.dispose();
    super.dispose();
  }
}