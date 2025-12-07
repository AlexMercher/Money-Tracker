import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/hive_service.dart';
import '../services/auth_service.dart';
import '../utils/color_utils.dart';
import '../widgets/self_expense_charts.dart';
import '../utils/page_transitions.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import 'friend_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'split_transaction_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'cash_borrowing_ledger_screen.dart';
import 'month_history_screen.dart';

/// Home screen showing balance overview and transaction management

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Friend> friends = [];
  User? _currentUser;
  bool isLoading = true;
  bool _showSelfTransactions = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
    
    _loadFriends();
    _checkBudgetRollover();
  }

  Future<void> _checkBudgetRollover() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    final lastCheckedMonth = prefs.getString('last_budget_check_month');
    
    if (lastCheckedMonth != currentMonthKey) {
      // New month detected (or first run)
      final user = await HiveService.getUserProfile();
      if (user != null) {
        if (user.carryBudgetToNextMonth) {
          // Keep budget, just update check
          await prefs.setString('last_budget_check_month', currentMonthKey);
        } else {
          // Prompt user
          if (mounted) {
            // Delay to let UI build
            Future.delayed(const Duration(seconds: 1), () {
              _showBudgetPrompt(user, prefs, currentMonthKey);
            });
          }
        }
      } else {
        // No user yet, just mark checked
        await prefs.setString('last_budget_check_month', currentMonthKey);
      }
    }
  }

  Future<void> _showBudgetPrompt(User user, SharedPreferences prefs, String currentMonthKey) async {
    final controller = TextEditingController(text: user.monthlyBudget > 0 ? user.monthlyBudget.toStringAsFixed(0) : '');
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New Month Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please set your budget for this month.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly Budget',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Treat as 0
              final updatedUser = user.copyWith(monthlyBudget: 0);
              await HiveService.saveUserProfile(updatedUser);
              await prefs.setString('last_budget_check_month', currentMonthKey);
              _loadUser();
              Navigator.pop(context);
            },
            child: const Text('Skip (Set to 0)'),
          ),
          ElevatedButton(
            onPressed: () async {
              final budget = double.tryParse(controller.text) ?? 0.0;
              final updatedUser = user.copyWith(monthlyBudget: budget);
              await HiveService.saveUserProfile(updatedUser);
              await prefs.setString('last_budget_check_month', currentMonthKey);
              _loadUser();
              Navigator.pop(context);
            },
            child: const Text('Set Budget'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(const ProfileScreen()),
    ).then((_) => _loadFriends());
  }

  Future<void> _loadFriends() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedFriends = HiveService.getAllFriends();
      await _loadUser();
      setState(() {
        friends = loadedFriends;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadUser() async {
    final user = await HiveService.getUserProfile();
    setState(() {
      _currentUser = user;
    });
  }

  void _navigateToFriendDetail(Friend friend) {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(FriendDetailScreen(friend: friend)),
    ).then((_) => _loadFriends()); // Refresh when returning
  }

  void _navigateToAddTransaction() {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(const AddTransactionScreen()),
    ).then((_) => _loadFriends()); // Refresh when returning
  }
  
  void _navigateToSplitTransaction() {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(const SplitTransactionScreen()),
    ).then((_) => _loadFriends()); // Refresh when returning
  }
  
  void _showAddTransactionOptions() {
    // Trigger scale animation
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });
    
    // Show bottom sheet with delay to make animation visible
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Single Transaction'),
                subtitle: const Text('Add transaction with one friend'),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToAddTransaction();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.orange,
                  ),
                ),
                title: const Text('Split Transaction'),
                subtitle: const Text('Split bill among multiple friends'),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToSplitTransaction();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main icon with bounce only - key ensures animation restarts
            TweenAnimationBuilder<double>(
              key: ValueKey(DateTime.now().millisecondsSinceEpoch),
              duration: const Duration(milliseconds: 2000),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, scale, iconChild) {
                return Transform.scale(
                  scale: scale,
                  child: iconChild,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.white.withOpacity(0.4)
                          : Theme.of(context).primaryColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: isDark 
                          ? Colors.white.withOpacity(0.2)
                          : Theme.of(context).primaryColor.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 120,
                  color: isDark 
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'No friends added yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Start tracking money by adding your first transaction',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    // Filter friends based on view mode
    final displayFriends = _showSelfTransactions
        ? friends.where((f) => f.id == 'self').toList()
        : friends.where((f) => f.id != 'self').toList();

    // Separate friends with and without balance
    final friendsWithBalance = displayFriends.where((f) => !f.isSettled).toList();
    final settledFriends = displayFriends.where((f) => f.isSettled).toList();
    
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title for Self Transactions
          if (_showSelfTransactions) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Self Expenditure',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Summary section
          if (friendsWithBalance.isNotEmpty || _showSelfTransactions) ...[
            _buildSummaryCard(friendsWithBalance),
            const SizedBox(height: 24),
          ],
          
          // Active Balances / Transactions
          if (_showSelfTransactions) ...[
            Text(
              'History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSelfHistoryList(),
            
            const SizedBox(height: 24),
            // Current Month Charts (Collapsible)
            ExpansionTile(
              title: Text(
                'Current Month Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: SelfExpenseCharts(
                    transactions: friends
                        .firstWhere((f) => f.id == 'self',
                            orElse: () => Friend(id: 'self', name: 'Self'))
                        .transactions
                        .where((t) {
                          final now = DateTime.now();
                          return t.date.year == now.year && t.date.month == now.month;
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            const SizedBox(height: 24),
          ] else if (friendsWithBalance.isNotEmpty) ...[
            Text(
              'Active Balances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...friendsWithBalance.map((friend) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BalanceCard(
                  friend: friend,
                  onTap: () => _navigateToFriendDetail(friend),
                ),
              );
            }),
            
            const SizedBox(height: 24),
          ],
          
          // Settled friends section
          if (!_showSelfTransactions && settledFriends.isNotEmpty) ...[
            ExpansionTile(
              title: Text(
                'Settled Friends (${settledFriends.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: settledFriends.map((friend) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: BalanceCard(
                    friend: friend,
                    onTap: () => _navigateToFriendDetail(friend),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<Friend> friendsWithBalance) {
    double totalOwe = 0;
    double totalGet = 0;
    
    // For Self View
    double selfSpent = 0;
    double selfGained = 0;
    double friendsOweMe = 0;
    double iOweFriends = 0;

    if (_showSelfTransactions) {
      // Calculate Self Stats
      final selfFriend = friends.firstWhere((f) => f.id == 'self', orElse: () => Friend(id: 'self', name: 'Self'));
      for (var t in selfFriend.transactions) {
        if (t.type == TransactionType.lent) {
          selfSpent += t.amount;
        } else {
          selfGained += t.amount;
        }
      }

      // Calculate Friends Stats
      for (final friend in friends) {
        if (friend.id == 'self') continue;
        final balance = friend.netBalance;
        if (balance > 0) {
          friendsOweMe += balance;
        } else {
          iOweFriends += balance.abs();
        }
      }
    } else {
      // Normal View Stats
      for (final friend in friendsWithBalance) {
        final balance = friend.netBalance;
        if (balance > 0) {
          totalGet += balance;
        } else {
          totalOwe += balance.abs();
        }
      }
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + (0.15 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(isDark ? 0.15 : 0.1),
              Theme.of(context).primaryColor.withOpacity(isDark ? 0.08 : 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showSelfTransactions ? 'Overview' : 'Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_showSelfTransactions)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          'Total Spent',
                          selfSpent,
                          isDark ? ColorUtils.negativeColorDark : ColorUtils.negativeColor,
                          Icons.arrow_upward,
                        ),
                      ),
                      Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                      Expanded(
                        child: _buildSummaryItem(
                          'Total Gained',
                          selfGained,
                          isDark ? ColorUtils.positiveColorDark : ColorUtils.positiveColor,
                          Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          'Lend',
                          friendsOweMe,
                          Colors.orange,
                          Icons.outbond,
                        ),
                      ),
                      Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                      Expanded(
                        child: _buildSummaryItem(
                          'Borrow',
                          iOweFriends,
                          Colors.purple,
                          Icons.call_received,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'You Get',
                      totalGet,
                      isDark ? ColorUtils.positiveColorDark : ColorUtils.positiveColor,
                      Icons.arrow_downward,
                    ),
                  ),
                  
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  
                  Expanded(
                    child: _buildSummaryItem(
                      'You Owe',
                      totalOwe,
                      isDark ? ColorUtils.negativeColorDark : ColorUtils.negativeColor,
                      Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildDrawer() {
    // Calculate Budget Info
    double budgetLeft = 0;
    int daysRemaining = 0;
    double monthlyBudget = _currentUser?.monthlyBudget ?? 0;
    double currentMonthUsage = 0;
    
    if (monthlyBudget > 0) {
      final now = DateTime.now();
      final lastDay = DateTime(now.year, now.month + 1, 0);
      daysRemaining = lastDay.day - now.day;
      
      // Shadow Ledger Integration - Source of Truth
      final events = HiveService.getShadowEventsForMonth(now);
      currentMonthUsage = HiveService.getGrossSpentThisMonth(events);
      final netUsed = HiveService.getNetUsedThisMonth(events);
      budgetLeft = monthlyBudget - netUsed;
    }

    // Get recent transactions
    final allTransactions = <Transaction>[];
    for (final friend in friends) {
      for (final transaction in friend.transactions) {
        allTransactions.add(transaction);
      }
    }
    allTransactions.sort((a, b) => b.date.compareTo(a.date));
    final recentTransactions = allTransactions.take(3).toList();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      child: Column(
        children: [
          // Header with profile info
          _buildDrawerHeader(),
          
          // Budget Info Section
          if (monthlyBudget > 0)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Monthly Budget Summary'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBudgetRow('Monthly Budget', monthlyBudget, Theme.of(context).colorScheme.primary),
                        const Divider(),
                        _buildBudgetRow('Spent This Month', currentMonthUsage, Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        _buildBudgetRow('Remaining', budgetLeft, 
                          budgetLeft >= 0 ? Colors.green : Colors.red, isBold: true),
                        const SizedBox(height: 8),
                        Text(
                          'Based on Shadow Ledger history.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Budget Left',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${budgetLeft.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: budgetLeft < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Days Left',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${daysRemaining}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (monthlyBudget - budgetLeft) / monthlyBudget,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        budgetLeft < 0 ? Colors.red : Theme.of(context).primaryColor,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),

          // Navigation Toggle
          ListTile(
            leading: Icon(
              _showSelfTransactions ? Icons.people : Icons.person,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              _showSelfTransactions ? 'Go to Friends Transactions' : 'Go to Self Transactions',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _showSelfTransactions ? 'View lent/borrowed with friends' : 'View personal expenses',
            ),
            onTap: () {
              setState(() {
                _showSelfTransactions = !_showSelfTransactions;
              });
              Navigator.pop(context);
            },
          ),
          
          const Divider(),

          // Recent Transactions Section
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (recentTransactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...recentTransactions.map((transaction) {
                    // Find which friend this transaction belongs to
                    final friend = friends.firstWhere(
                      (f) => f.transactions.contains(transaction),
                      orElse: () => Friend(
                        id: '',
                        name: 'Unknown',
                        transactions: [],
                      ),
                    );
                    
                    final isPositive = transaction.type == TransactionType.lent;
                    final color = isPositive 
                        ? (isDark ? ColorUtils.positiveColorDark : ColorUtils.positiveColor)
                        : (isDark ? ColorUtils.negativeColorDark : ColorUtils.negativeColor);
                    final sign = isPositive ? '+' : '-';
                    
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 700),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(-30 * (1 - value), 0),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.05), // Subtle tint
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          // No leading icon as requested
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  friend.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$sign₹${transaction.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            _navigateToFriendDetail(friend);
                          },
                        ),
                      ),
                    );
                  }),
                  
                  // Cash Borrowing Ledger Button (Only in Lent/Borrowed mode)
                  if (!_showSelfTransactions) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransitions.fadeSlide(const CashBorrowingLedgerScreen()),
                          );
                        },
                        icon: const Icon(Icons.account_balance),
                        label: const Text('Cash Borrowing Ledger'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
          ),
          
          // Footer
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'MoneyTrack v1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            PageTransitions.fadeSlide(const ProfileScreen()),
          ).then((_) => _loadUser());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 30,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MoneyTrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your money',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_currentUser != null && _currentUser!.name.isNotEmpty) ...[
              const Spacer(),
              Text(
                'Hello, ${_currentUser!.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  _navigateToProfile();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'My Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyTrack'),
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                PageTransitions.fadeSlide(const SettingsScreen()),
              ).then((_) {
                _loadFriends();
                _loadUser(); // Reload user profile to update budget info
              });
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      
      drawer: _buildDrawer(),
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : friends.isEmpty
                ? _buildEmptyState()
                : _buildFriendsList(),
      ),
      
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _showAddTransactionOptions,
          icon: const Icon(Icons.add),
          label: const Text('Add Transaction'),
        ),
      ),
    );
  }

  Future<void> _deleteSelfTransaction(Transaction transaction) async {
    // Require authentication
    final authenticated = await AuthService.authenticate();
    if (!authenticated) return;

    setState(() => isLoading = true);

    // Store for undo
    final deletedTransaction = transaction;

    try {
      await HiveService.deleteTransaction('self', transaction.id);
      await _loadFriends(); // Reloads everything including self

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await HiveService.addTransaction('self', deletedTransaction);
                await _loadFriends();
              },
            ),
          ),
        );
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
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSelfHistoryList() {
    final selfFriend = friends.firstWhere(
      (f) => f.id == 'self',
      orElse: () => Friend(id: 'self', name: 'Self', transactions: []),
    );

    if (selfFriend.transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No transactions yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort transactions by date descending
    final sortedTransactions = List<Transaction>.from(selfFriend.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group by month
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in sortedTransactions) {
      final monthKey = DateFormat('MMMM yyyy').format(transaction.date);
      if (!groupedTransactions.containsKey(monthKey)) {
        groupedTransactions[monthKey] = [];
      }
      groupedTransactions[monthKey]!.add(transaction);
    }

    final currentMonthKey = DateFormat('MMMM yyyy').format(DateTime.now());

    return Column(
      children: [
        ...groupedTransactions.entries.map((entry) {
          final monthTransactions = entry.value;
          final isCurrentMonth = entry.key == currentMonthKey;
          
          // Calculate monthly summary
          double totalSpent = 0;
          double totalGained = 0;
          for (var t in monthTransactions) {
            if (t.type == TransactionType.lent) {
              totalSpent += t.amount;
            } else {
              totalGained += t.amount;
            }
          }
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Spent: ₹${totalSpent.toStringAsFixed(0)} • Gained: ₹${totalGained.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                // Monthly Summary Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniSummaryItem('Spent', totalSpent, Colors.red),
                      _buildMiniSummaryItem('Gained', totalGained, Colors.green),
                      _buildMiniSummaryItem('Txns', monthTransactions.length.toDouble(), Colors.blue),
                    ],
                  ),
                ),
                
                // Monthly Charts - Hide for current month as it's shown above
                if (!isCurrentMonth)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SelfExpenseCharts(transactions: monthTransactions),
                  ),
                
                const Divider(),
                
                // Transaction List
                ...monthTransactions.map((transaction) => TransactionTile(
                  transaction: transaction,
                  isSelf: true,
                  showActions: true,
                  onDelete: () => _deleteSelfTransaction(transaction),
                )),
                const SizedBox(height: 16),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMiniSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label == 'Txns' ? value.toInt().toString() : '₹${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}