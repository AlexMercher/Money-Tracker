import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../services/hive_service.dart';
import '../widgets/balance_card.dart';
import 'friend_detail_screen.dart';
import 'add_transaction_screen.dart';

/// Home screen showing balance overview and transaction management
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Friend> friends = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
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
      MaterialPageRoute(
        builder: (context) => FriendDetailScreen(friend: friend),
      ),
    ).then((_) => _loadFriends()); // Refresh when returning
  }

  void _navigateToAddTransaction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    ).then((_) => _loadFriends()); // Refresh when returning
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'No friends added yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Start tracking money by adding your first transaction',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: _navigateToAddTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
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
            
            ...friendsWithBalance.map((friend) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BalanceCard(
                friend: friend,
                onTap: () => _navigateToFriendDetail(friend),
              ),
            )),
            
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
              children: settledFriends.map((friend) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: BalanceCard(
                  friend: friend,
                  onTap: () => _navigateToFriendDetail(friend),
                ),
              )).toList(),
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
    
    return Card(
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
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.05),
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
                color: Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'You Get',
                    totalGet,
                    Colors.green,
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
                    Colors.red,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyTrack'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriends,
            tooltip: 'Refresh',
          ),
        ],
      ),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
              ? _buildEmptyState()
              : _buildFriendsList(),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }
}