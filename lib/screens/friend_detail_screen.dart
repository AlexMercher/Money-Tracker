import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../models/transaction_group.dart';
import '../services/hive_service.dart';
import '../services/pdf_service.dart';
import '../services/auth_service.dart';
import '../logic/friend_logic.dart';
import '../widgets/transaction_group_tile.dart';
import '../widgets/transaction_tile.dart';
import '../utils/color_utils.dart';
import '../utils/page_transitions.dart';
import 'add_transaction_screen.dart';
import 'profile_screen.dart';

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
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late FriendLogic _friendLogic;

  @override
  void initState() {
    super.initState();
    _friendLogic = FriendLogic(auth: AppAuthController());
    _friendLogic.showConfirmDialog = _showConfirmDialogWrapper;
    _friendLogic.clearVisibleHistory = _performClearHistory;
    _friendLogic.settleFriendBalance = _performSettlement;

    _friend = widget.friend;
    _refreshFriend();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFriend() async {
    final updatedFriend = HiveService.getFriend(_friend.id);
    if (updatedFriend != null) {
      setState(() {
        _friend = updatedFriend;
      });
    }
  }

  Future<bool> _showConfirmDialogWrapper({required String title, required String message}) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    ) ?? false;
  }

  Future<void> _showClearHistoryDialog() async {
    if (!_friend.isSettled) return;
    await _friendLogic.onClearHistoryPressed();
  }

  Future<void> _performClearHistory() async {
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

  void _showTransactionDetails(Transaction transaction) {
    final isPositive = transaction.type == TransactionType.lent;
    final color = isPositive ? ColorUtils.positiveColor : ColorUtils.negativeColor;
    final typeText = isPositive ? 'Lend' : 'Borrow';
    final sign = isPositive ? '+' : '-';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
            ),
            const SizedBox(width: 8),
            const Text('Transaction Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$sign₹${transaction.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Type
              _buildDetailRow(
                context,
                'Type',
                typeText,
                icon: Icons.swap_horiz,
                valueColor: color,
              ),
              
              const Divider(height: 24),
              
              // Date
              _buildDetailRow(
                context,
                'Date',
                DateFormat.yMMMMd().format(transaction.date),
                icon: Icons.calendar_today,
              ),
              
              const Divider(height: 24),
              
              // Note
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Note',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.note.isNotEmpty ? transaction.note : 'No note',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a read-only view. Transactions cannot be edited.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _clearDebt() async {
    if (_friend.netBalance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Balance is already settled'),
        ),
      );
      return;
    }
    await _friendLogic.onSettleBalancePressed();
  }

  Future<void> _performSettlement() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final balance = _friend.netBalance;
      final isOwed = balance > 0;
      // Create a settling transaction with opposite amount
      final settlingAmount = balance.abs();
      final settlingType = isOwed 
          ? TransactionType.borrowed // They're paying us back
          : TransactionType.lent;     // We're paying them back

      final settlingTransaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: settlingAmount,
        type: settlingType,
        note: 'Debt settled',
        date: DateTime.now(),
      );

      await HiveService.addTransaction(_friend.id, settlingTransaction);
      await _refreshFriend();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Debt cleared successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await HiveService.deleteTransaction(_friend.id, settlingTransaction.id);
                await _refreshFriend();
              },
            ),
          ),
        );

        // Show clear history dialog after settling
        if (_friend.isSettled && _friend.transactions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showClearHistoryDialog();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing debt: $e'),
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
    // Require authentication
    final authOk = await _friendLogic.auth.requestAuth();
    if (!authOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to delete friend.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
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
      // Haptic feedback for destructive action - must await to ensure execution
      await HapticFeedback.mediumImpact();
      
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
    // Require authentication
    final authOk = await _friendLogic.auth.requestAuth();
    if (!authOk) return;
    
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
        // Store for undo
        final deletedTransaction = transaction;
        
        await HiveService.deleteTransaction(_friend.id, transaction.id);
        await _refreshFriend();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted'),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await HiveService.addTransaction(_friend.id, deletedTransaction);
                  await _refreshFriend();
                },
              ),
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

  void _addTransaction() {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(AddTransactionScreen(friend: _friend)),
    ).then((_) => _refreshFriend());
  }

  Widget _buildBalanceHeader() {
    if (_friend.id == 'self') {
      return _buildSelfOverview();
    }

    final balance = _friend.netBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use new color helper
    final balanceColor = ColorUtils.getFriendAccentColor(context, balance);
    
    String balanceText = ColorUtils.getBalanceText(balance);
    
    final formattedBalance = ColorUtils.getFormattedBalance(balance);
    final balanceIcon = ColorUtils.getBalanceIcon(balance);

    // Custom background color for dark mode
    final bgColor = isDark 
        ? const Color(0xFF1E1E22) 
        : ColorUtils.getBalanceLightColor(balance, isDark: false);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? balanceColor.withOpacity(0.5) : balanceColor.withOpacity(0.3),
          width: 1,
        ),
      ),
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
              color: isDark ? Colors.white : Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Balance information
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(balanceIcon, color: balanceColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  balanceText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: balanceColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildSelfOverview() {
    double totalSpent = 0;
    double totalGained = 0;

    for (var t in _friend.transactions) {
      if (t.type == TransactionType.lent) {
        totalSpent += t.amount;
      } else {
        totalGained += t.amount;
      }
    }

    double totalLent = 0;
    double totalBorrowed = 0;
    final allFriends = HiveService.getAllFriends();
    for (var f in allFriends) {
      if (f.id == 'self') continue;
      if (f.netBalance > 0) {
        totalLent += f.netBalance;
      } else {
        totalBorrowed += f.netBalance.abs();
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total Spent',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalSpent.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? ColorUtils.negativeColorDark : ColorUtils.negativeColor,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total Gained',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalGained.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? ColorUtils.positiveColorDark : ColorUtils.positiveColor,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Lend (Friends)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalLent.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Borrow (Friends)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalBorrowed.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_friend.transactions.isEmpty) {
      final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: secondaryColor),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 18,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort transactions by date (newest first)
    var sortedTransactions = List<Transaction>.from(_friend.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Filter transactions based on search query (case-insensitive)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      sortedTransactions = sortedTransactions.where((transaction) {
        final note = transaction.note.toLowerCase();
        final amount = transaction.amount.toString();
        return note.contains(query) || amount.contains(query);
      }).toList();
    }

    // If no results after filtering
    if (sortedTransactions.isEmpty) {
      final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: secondaryColor),
              const SizedBox(height: 16),
              Text(
                'No transactions found',
                style: TextStyle(
                  fontSize: 18,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group transactions
    if (_friend.id == 'self') {
      return _buildSelfTransactionsList(sortedTransactions);
    }

    final groups = TransactionGroup.groupTransactions(sortedTransactions);
    TransactionGroup.sortGroupsByDate(groups);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        
        // For single transaction groups, delete only (no edit)
        return TransactionGroupTile(
          group: group,
          onDelete: !group.isGrouped ? () => _deleteTransaction(group.transactions.first) : null,
          onTransactionTap: !group.isGrouped ? _showTransactionDetails : null,
          isSelf: _friend.id == 'self',
        );
      },
    );
  }

  Widget _buildSelfTransactionsList(List<Transaction> transactions) {
    // Group by month
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in transactions) {
      final monthKey = DateFormat('MMMM yyyy').format(transaction.date);
      if (!groupedTransactions.containsKey(monthKey)) {
        groupedTransactions[monthKey] = [];
      }
      groupedTransactions[monthKey]!.add(transaction);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final monthKey = groupedTransactions.keys.elementAt(index);
        final monthTransactions = groupedTransactions[monthKey]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  monthKey,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...monthTransactions.map((transaction) => TransactionTile(
                transaction: transaction,
                isSelf: true,
                onDelete: () => _deleteTransaction(transaction),
              )),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _exportToPdf() async {
    // Check if user profile is complete
    final isComplete = await HiveService.isProfileComplete();
    if (!isComplete) {
      if (!mounted) return;
      
      final setupNow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile Required'),
          content: const Text(
            'Please setup your profile first. Your name is required for PDF generation.\n\n'
            'Your name will be used in the PDF to show who owes whom.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Setup Profile'),
            ),
          ],
        ),
      );

      if (setupNow == true && mounted) {
        Navigator.of(context).push(
          PageTransitions.fadeSlide(const ProfileScreen()),
        ).then((_) => _exportToPdf()); // Retry after profile setup
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export to PDF'),
        content: Text(
          'Do you want to save the transaction history for ${_friend.name} as a PDF?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Generating PDF...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    // Generate PDF
    File? file;
    bool pdfAlreadyExists = false;
    String? existingPdfPath;
    String? errorMessage;
    
    try {
      file = await PdfService.generateTransactionPdf(_friend);
    } catch (e) {
      final errorStr = e.toString();
      print('DEBUG: Exception caught: $errorStr');
      
      // Handle "Exception: PDF_EXISTS:/path/to/file.pdf"
      if (errorStr.contains('PDF_EXISTS:')) {
        pdfAlreadyExists = true;
        // Extract path after "PDF_EXISTS:" - handle both "Exception: " prefix and without
        final marker = 'PDF_EXISTS:';
        final startIndex = errorStr.indexOf(marker) + marker.length;
        existingPdfPath = errorStr.substring(startIndex).trim();
        
        print('DEBUG: Extracted path: $existingPdfPath');
        
        // Remove any "Exception: " prefix if present in the path itself
        if (existingPdfPath.startsWith('Exception:')) {
          existingPdfPath = existingPdfPath.substring('Exception:'.length).trim();
          print('DEBUG: After removing Exception prefix: $existingPdfPath');
        }
        
        print('DEBUG: Final path to open: $existingPdfPath');
      } else {
        errorMessage = errorStr;
        print('DEBUG: Regular error: $errorMessage');
      }
    }

    if (mounted) {
      // Clear loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (pdfAlreadyExists && existingPdfPath != null && existingPdfPath.isNotEmpty) {
        // PDF exists - directly open it
        print('DEBUG: Attempting to open existing PDF: $existingPdfPath');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF already exists - Opening existing PDF'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        
        final opened = await PdfService.openPdf(existingPdfPath);
        print('DEBUG: PDF open result: $opened');
        
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open PDF. Please check if you have a PDF viewer installed.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } else if (file != null) {
        // PDF generated successfully
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Saved Successfully!'),
            content: Text(
              'Transaction history for ${_friend.name} has been exported.\n\n'
              'Location: Documents/MoneyTrack_PDFs/',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('done'),
                child: const Text('Done'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop('view'),
                child: const Text('View PDF'),
              ),
            ],
          ),
        );

        if (action == 'view') {
          final opened = await PdfService.openPdf(file.path);
          if (!opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Could not open PDF. Please check if you have a PDF viewer installed.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: ${errorMessage ?? "Unknown error"}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_friend.name),
        actions: [
          // Search button (only icon)
          if (_friend.transactions.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _searchController.clear();
                  }
                });
              },
              icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
              tooltip: _showSearchBar ? 'Hide Search' : 'Search',
            ),
          
          // PDF Export button
          if (_friend.transactions.isNotEmpty)
            IconButton(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.print),
              tooltip: 'Export to PDF',
            ),
          
          if (_friend.isSettled && _friend.transactions.isNotEmpty && _friend.id != 'self')
            TextButton.icon(
              onPressed: _showClearHistoryDialog,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          
          if (_friend.id != 'self')
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clearDebt':
                  _clearDebt();
                  break;
                case 'delete':
                  _deleteFriend();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Only show Clear Debt if balance is not zero
              if (_friend.netBalance != 0)
                PopupMenuItem(
                  value: 'clearDebt',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Clear Debt'),
                    ],
                  ),
                ),
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
                  
                  // Search bar (shown when search icon is tapped)
                  if (_showSearchBar && _friend.transactions.isNotEmpty) ...[
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by note or amount...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                  
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
}class AppAuthController implements AuthController {
  @override
  Future<bool> requestAuth() async {
    try {
      final authEnabled = await AuthService.isAuthEnabled();
      if (!authEnabled) return true;
      return await AuthService.authenticate();
    } catch (e) {
      return false;
    }
  }
}
