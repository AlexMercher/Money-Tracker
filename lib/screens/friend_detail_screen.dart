import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
import '../widgets/transaction_tile.dart';
import '../utils/color_utils.dart';
import 'add_transaction_screen.dart';

/// Screen showing detailed transaction history for a friend
class FriendDetailScreen extends StatefulWidget {
  final Friend friend;

  const FriendDetailScreen({
    super.key,
    required this.friend,
  });

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  late Friend _friend;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _friend = widget.friend;
    _refreshFriend();
  }

  Future<void> _refreshFriend() async {
    final updatedFriend = HiveService.getFriend(_friend.id);
    if (updatedFriend != null) {
      setState(() {
        _friend = updatedFriend;
      });
    }
  }

  Future<void> _showClearHistoryDialog() async {
    if (!_friend.isSettled) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Balance is settled. Do you want to clear the transaction history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep History'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _clearHistory();
    }
  }

  Future<void> _clearHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await HiveService.clearFriendHistory(_friend.id);
      await _refreshFriend();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction history cleared'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: $e'),
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

  Future<void> _deleteFriend() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Friend'),
        content: Text(
          'Are you sure you want to delete ${_friend.name}? All transaction data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await HiveService.deleteFriend(_friend.id);
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_friend.name} deleted'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting friend: $e'),
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
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await HiveService.deleteTransaction(_friend.id, transaction.id);
        await _refreshFriend();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted'),
            ),
          );

          // Check if balance is now settled
          if (_friend.isSettled && _friend.transactions.isNotEmpty) {
            _showClearHistoryDialog();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting transaction: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _editTransaction(Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          friend: _friend,
          transaction: transaction,
        ),
      ),
    ).then((_) {
      _refreshFriend();
      
      // Check if balance is now settled
      if (_friend.isSettled && _friend.transactions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showClearHistoryDialog();
        });
      }
    });
  }

  void _addTransaction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(friend: _friend),
      ),
    ).then((_) => _refreshFriend());
  }

  Widget _buildBalanceHeader() {
    final balance = _friend.netBalance;
    final balanceColor = ColorUtils.getBalanceColor(balance);
    final balanceText = ColorUtils.getBalanceText(balance);
    final formattedBalance = ColorUtils.getFormattedBalance(balance);
    final balanceIcon = ColorUtils.getBalanceIcon(balance);

    return ColorUtils.createBalanceContainer(
      balance: balance,
      child: Column(
        children: [
          // Friend avatar and name
          CircleAvatar(
            radius: 40,
            backgroundColor: balanceColor.withOpacity(0.2),
            child: Text(
              _friend.name.isNotEmpty ? _friend.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _friend.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Balance information
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(balanceIcon, color: balanceColor, size: 20),
              const SizedBox(width: 8),
              Text(
                balanceText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          Text(
            formattedBalance,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: balanceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '${_friend.transactions.length} transaction${_friend.transactions.length != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_friend.transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort transactions by date (newest first)
    final sortedTransactions = List<Transaction>.from(_friend.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedTransactions.length,
      itemBuilder: (context, index) {
        final transaction = sortedTransactions[index];
        return TransactionTile(
          transaction: transaction,
          onEdit: () => _editTransaction(transaction),
          onDelete: () => _deleteTransaction(transaction),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_friend.name),
        actions: [
          if (_friend.isSettled && _friend.transactions.isNotEmpty)
            TextButton.icon(
              onPressed: _showClearHistoryDialog,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _deleteFriend();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Text('Delete Friend'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshFriend,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceHeader(),
                  
                  const SizedBox(height: 24),
                  
                  if (_friend.transactions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction History',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        if (_friend.isSettled && _friend.transactions.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ColorUtils.neutralColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Settled',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: ColorUtils.neutralColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                  ],
                  
                  _buildTransactionsList(),
                ],
              ),
            ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}