import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
import '../utils/color_utils.dart';
import '../utils/page_transitions.dart';
import '../widgets/balance_card.dart';
import 'friend_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'split_transaction_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

/// Home screen showing balance overview and transaction management
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Friend> friends = [];
  bool isLoading = true;
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
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
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
    // Separate friends with and without balance
    final friendsWithBalance = friends.where((f) => !f.isSettled).toList();
    final settledFriends = friends.where((f) => f.isSettled).toList();
    
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary section
          if (friendsWithBalance.isNotEmpty) ...[
            _buildSummaryCard(friendsWithBalance),
            const SizedBox(height: 24),
          ],
          
          // Active balances section
          if (friendsWithBalance.isNotEmpty) ...[
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
          if (settledFriends.isNotEmpty) ...[
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
    
    for (final friend in friendsWithBalance) {
      final balance = friend.netBalance;
      if (balance > 0) {
        totalGet += balance;
      } else {
        totalOwe += balance.abs();
      }
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700), // Increased from 300ms
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + (0.15 * value), // Changed from 0.9 for more visible effect
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
              'Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
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
    // Get recent 5 transactions from all friends
    final allTransactions = <Transaction>[];
    for (final friend in friends) {
      for (final transaction in friend.transactions) {
        allTransactions.add(transaction);
      }
    }
    
    // Sort by date (most recent first) and take top 5
    allTransactions.sort((a, b) => b.date.compareTo(a.date));
    final recentTransactions = allTransactions.take(5).toList();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      child: Column(
        children: [
          // Header with profile info
          _buildDrawerHeader(),
          
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
                        color: Theme.of(context).primaryColor,
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
                      duration: const Duration(milliseconds: 700), // Increased from 400ms
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(-30 * (1 - value), 0), // Increased from -20 for more visible slide
                            child: child,
                          ),
                        );
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Text(
                            friend.name.isNotEmpty 
                                ? friend.name[0].toUpperCase() 
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
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
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close drawer
                          _navigateToFriendDetail(friend);
                        },
                      ),
                    );
                  }),
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
              ).then((_) => _loadFriends());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      
      drawer: _buildDrawer(),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
              ? _buildEmptyState()
              : _buildFriendsList(),
      
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
}