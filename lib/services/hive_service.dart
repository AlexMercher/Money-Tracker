import 'package:hive_flutter/hive_flutter.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../models/split_item.dart';
import '../models/user.dart';
import '../models/shadow_event.dart';
import '../models/cash_ledger_entry.dart';
import '../utils/budget_logic.dart';
import '../utils/debug_utils.dart';

/// Service for managing local data storage using Hive
class HiveService {
  static const String _friendsBoxName = 'friends';
  static const String _userBoxName = 'user_profile';
  static const String _shadowBoxName = 'shadow_ledger';
  static const String _cashLedgerBoxName = 'cash_ledger';
  
  static Box<Friend>? _friendsBox;
  static Box<User>? _userBox;
  static Box<ShadowEvent>? _shadowBox;
  static Box<CashLedgerEntry>? _cashLedgerBox;

  /// Initialize Hive and open boxes
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FriendAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SplitItemAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(UserAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ShadowEventAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(CashLedgerEntryAdapter());
    }
    
    // Open boxes
    _friendsBox = await Hive.openBox<Friend>(_friendsBoxName);
    _userBox = await Hive.openBox<User>(_userBoxName);
    _shadowBox = await Hive.openBox<ShadowEvent>(_shadowBoxName);
    _cashLedgerBox = await Hive.openBox<CashLedgerEntry>(_cashLedgerBoxName);

    // Migration: If shadow box is empty but friends exist, populate it.
    if (_shadowBox!.isEmpty && _friendsBox!.isNotEmpty) {
      await _migrateToShadowLedger();
    }
  }

  /// Get the friends box
  static Box<Friend> get friendsBox {
    if (_friendsBox == null) {
      throw Exception('HiveService not initialized. Call HiveService.init() first.');
    }
    return _friendsBox!;
  }

  /// Get the user box
  static Box<User> get userBox {
    if (_userBox == null) {
      throw Exception('HiveService not initialized. Call HiveService.init() first.');
    }
    return _userBox!;
  }

  /// Get the shadow ledger box
  static Box<ShadowEvent> get shadowBox {
    if (_shadowBox == null) {
      throw Exception('HiveService not initialized. Call HiveService.init() first.');
    }
    return _shadowBox!;
  }

  /// Get the cash ledger box
  static Box<CashLedgerEntry> get cashLedgerBox {
    if (_cashLedgerBox == null) {
      throw Exception('HiveService not initialized. Call HiveService.init() first.');
    }
    return _cashLedgerBox!;
  }

  /// Get all friends
  static List<Friend> getAllFriends() {
    return friendsBox.values.toList();
  }

  /// Get a friend by ID
  static Friend? getFriend(String id) {
    return friendsBox.get(id);
  }

  /// Add or update a friend
  static Future<void> saveFriend(Friend friend) async {
    await friendsBox.put(friend.id, friend);
  }

  /// Delete a friend and all their transactions
  static Future<void> deleteFriend(String id) async {
    await friendsBox.delete(id);
  }

  /// Add a transaction to a friend
  static Future<void> addTransaction(String friendId, Transaction transaction) async {
    debugBudget("A. Creating Transaction: type=${transaction.type}, amount=${transaction.amount}, visibleDate=${transaction.date}, ledgerDate=${transaction.ledgerDate}");

    final friend = getFriend(friendId);
    if (friend != null) {
      final oldBalance = friend.netBalance;
      
      // Pseudo-backdate logic:
      // If friend transaction (not self), ensure ledgerDate is set to NOW if not provided
      // This ensures budget impact happens NOW regardless of visible date
      if (friendId != 'self' && transaction.ledgerDate == null) {
        debugBudget("G. Pseudo-backdate applied: visibleDate=${transaction.date}, using NOW for ledgerDate. Reason: New transaction affecting current budget.");
        transaction.ledgerDate = DateTime.now();
      }

      friend.addTransaction(transaction);
      await saveFriend(friend);
      
      final newBalance = friend.netBalance;
      
      debugBudget("B. Balance Update: friendId=$friendId, oldBalance=$oldBalance, newBalance=$newBalance");

      // Calculate budget delta
      // We assume isPureCashTransfer is false for now as we want settlements to affect budget
      debugBudget("C. Computing Delta: old=$oldBalance, new=$newBalance");
      final delta = computeFriendBudgetDelta(oldBalance, newBalance, false);
      debugBudget("D. Delta Computed: deltaBudget=$delta");
      
      if (delta != 0) {
        final shadowEvent = ShadowEvent(
          timestamp: transaction.ledgerDate ?? transaction.date, // Use ledgerDate if available
          oldBalance: oldBalance,
          newBalance: newBalance,
          deltaBudget: delta,
          isVisible: true,
          friendId: friendId,
          transactionId: transaction.id,
        );
        await addShadowEvent(shadowEvent);
      }
    }
  }

  /// Update a transaction for a friend
  static Future<void> updateTransaction(String friendId, Transaction transaction) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      final oldBalance = friend.netBalance;
      
      friend.updateTransaction(transaction);
      await saveFriend(friend);
      
      final newBalance = friend.netBalance;
      
      debugBudget("B. Balance Update (Update): friendId=$friendId, oldBalance=$oldBalance, newBalance=$newBalance");
      debugBudget("C. Computing Delta (Update): old=$oldBalance, new=$newBalance");
      final delta = computeFriendBudgetDelta(oldBalance, newBalance, false);
      debugBudget("D. Delta Computed (Update): deltaBudget=$delta");
      
      // Find existing shadow event for this transaction
      final existingEventKey = shadowBox.keys.firstWhere(
        (k) {
          final e = shadowBox.get(k);
          return e?.transactionId == transaction.id;
        },
        orElse: () => null,
      );

      if (existingEventKey != null) {
        if (delta != 0) {
          // Update existing
          final event = shadowBox.get(existingEventKey)!;
          event.oldBalance = oldBalance;
          event.newBalance = newBalance;
          event.deltaBudget = delta;
          event.timestamp = transaction.ledgerDate ?? transaction.date;
          event.save();
        } else {
          // Delta became 0, delete event
          await shadowBox.delete(existingEventKey);
        }
      } else if (delta != 0) {
        // Create new
        final shadowEvent = ShadowEvent(
          timestamp: transaction.ledgerDate ?? transaction.date,
          oldBalance: oldBalance,
          newBalance: newBalance,
          deltaBudget: delta,
          isVisible: true,
          friendId: friendId,
          transactionId: transaction.id,
        );
        await addShadowEvent(shadowEvent);
      }
    }
  }

  /// Delete a transaction from a friend
  static Future<void> deleteTransaction(String friendId, String transactionId) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      // Remove associated shadow events
      final keysToDelete = <dynamic>[];
      for (var i = 0; i < shadowBox.length; i++) {
        final event = shadowBox.getAt(i);
        if (event != null && event.transactionId == transactionId) {
          debugBudget("F. Deleting Shadow Event: eventId=${shadowBox.keyAt(i)}, transactionId=$transactionId");
          keysToDelete.add(shadowBox.keyAt(i));
        }
      }
      await shadowBox.deleteAll(keysToDelete);
      
      // Check for orphans
      bool orphansFound = false;
      for (var i = 0; i < shadowBox.length; i++) {
        final event = shadowBox.getAt(i);
        if (event != null && event.transactionId == transactionId) {
          orphansFound = true;
          break;
        }
      }
      debugBudget("F. Orphan Check: orphansRemaining=$orphansFound");

      friend.removeTransaction(transactionId);
      await saveFriend(friend);
    }
  }

  /// Clear all transaction history for a friend
  static Future<void> clearFriendHistory(String friendId) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      final oldBalance = friend.netBalance;
      
      friend.clearHistory();
      await saveFriend(friend);
      
      final newBalance = friend.netBalance; // Should be 0
      
      final delta = computeFriendBudgetDelta(oldBalance, newBalance, false);
      
      if (delta != 0) {
        final shadowEvent = ShadowEvent(
          timestamp: DateTime.now(),
          oldBalance: oldBalance,
          newBalance: newBalance,
          deltaBudget: delta,
          isVisible: true,
        );
        await addShadowEvent(shadowEvent);
      }
    }
  }

  /// Check if a friend name already exists (case-insensitive)
  static bool friendNameExists(String name, {String? excludeId}) {
    return getAllFriends().any((friend) => 
        friend.name.toLowerCase() == name.toLowerCase() && 
        friend.id != excludeId);
  }

  /// Get friends with non-zero balances
  static List<Friend> getFriendsWithBalance() {
    return getAllFriends().where((friend) => !friend.isSettled).toList();
  }

  /// Close all boxes (call when app is disposed)
  static Future<void> close() async {
    await _friendsBox?.close();
    await _userBox?.close();
    await _shadowBox?.close();
    await _cashLedgerBox?.close();
  }

  /// Clear all data (useful for testing or complete reset)
  static Future<void> clearAllData() async {
    await friendsBox.clear();
    await shadowBox.clear();
    await cashLedgerBox.clear();
  }

  /// Delete all Hive boxes and data completely
  static Future<void> deleteAllData() async {
    await _friendsBox?.close();
    await _userBox?.close();
    await _shadowBox?.close();
    await _cashLedgerBox?.close();
    await Hive.deleteBoxFromDisk(_friendsBoxName);
    await Hive.deleteBoxFromDisk(_userBoxName);
    await Hive.deleteBoxFromDisk(_shadowBoxName);
    await Hive.deleteBoxFromDisk(_cashLedgerBoxName);
    // Reinitialize if needed
    _friendsBox = await Hive.openBox<Friend>(_friendsBoxName);
    _userBox = await Hive.openBox<User>(_userBoxName);
    _shadowBox = await Hive.openBox<ShadowEvent>(_shadowBoxName);
    _cashLedgerBox = await Hive.openBox<CashLedgerEntry>(_cashLedgerBoxName);
  }

  // ==================== User Profile Methods ====================

  /// Get user profile
  static Future<User?> getUserProfile() async {
    if (userBox.isEmpty) {
      return null;
    }
    return userBox.get('profile');
  }

  /// Save user profile
  static Future<void> saveUserProfile(User user) async {
    await userBox.put('profile', user);
  }

  /// Check if user profile exists
  static bool hasUserProfile() {
    return userBox.isNotEmpty && userBox.get('profile') != null;
  }

  /// Check if user has completed profile setup (name is required)
  static Future<bool> isProfileComplete() async {
    final user = await getUserProfile();
    return user != null && user.name.trim().isNotEmpty;
  }

  /// Check if adding a transaction at [newDate] would exceed 12 months history
  static bool shouldCleanupHistory(DateTime newDate) {
    final allTransactions = <Transaction>[];
    for (final friend in getAllFriends()) {
      allTransactions.addAll(friend.transactions);
    }
    
    if (allTransactions.isEmpty) return false;
    
    // Add the new date to consideration
    final dates = allTransactions.map((t) => t.date).toList()..add(newDate);
    dates.sort();
    
    final minDate = dates.first;
    final maxDate = dates.last;
    
    // Calculate months difference
    final monthsDiff = (maxDate.year - minDate.year) * 12 + maxDate.month - minDate.month;
    
    return monthsDiff >= 12; // 13th month means diff is 12 (e.g. Jan 2023 to Jan 2024)
  }

  /// Delete transactions older than 12 months from the newest transaction
  static Future<void> cleanupOldHistory() async {
    final allTransactions = <Transaction>[];
    for (final friend in getAllFriends()) {
      allTransactions.addAll(friend.transactions);
    }
    
    if (allTransactions.isEmpty) return;
    
    allTransactions.sort((a, b) => a.date.compareTo(b.date));
    final maxDate = allTransactions.last.date;
    
    // Cutoff is 12 months before maxDate
    final cutoffDate = DateTime(maxDate.year - 1, maxDate.month, maxDate.day);
    
    for (final friend in getAllFriends()) {
      final toDelete = friend.transactions.where((t) => t.date.isBefore(cutoffDate)).toList();
      for (final t in toDelete) {
        friend.removeTransaction(t.id);
      }
      if (toDelete.isNotEmpty) {
        await saveFriend(friend);
      }
    }
    
    // Also prune shadow events
    await pruneShadowEvents();
  }

  // ==================== Shadow Ledger Methods ====================

  /// Add a shadow event
  static Future<void> addShadowEvent(ShadowEvent event) async {
    debugBudget("E. Writing Shadow Event: timestamp=${event.timestamp}, delta=${event.deltaBudget}, old=${event.oldBalance}, new=${event.newBalance}");
    await shadowBox.add(event);
  }

  /// Get shadow events for a specific month
  static List<ShadowEvent> getShadowEventsForMonth(DateTime month) {
    return shadowBox.values.where((event) {
      return event.timestamp.year == month.year && 
             event.timestamp.month == month.month;
    }).toList();
  }

  /// Prune shadow events older than 12 months
  static Future<void> pruneShadowEvents() async {
    final now = DateTime.now();
    final cutoffDate = DateTime(now.year - 1, now.month, now.day);
    
    final keysToDelete = <dynamic>[];
    
    for (var i = 0; i < shadowBox.length; i++) {
      final event = shadowBox.getAt(i);
      if (event != null && event.timestamp.isBefore(cutoffDate)) {
        keysToDelete.add(shadowBox.keyAt(i));
      }
    }
    
    await shadowBox.deleteAll(keysToDelete);
  }

  /// Migrate existing transactions to shadow ledger
  static Future<void> _migrateToShadowLedger() async {
    final allFriends = getAllFriends();
    for (final friend in allFriends) {
      if (friend.id == 'self') continue;
      
      final sortedTransactions = List<Transaction>.from(friend.transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
        
      double runningBalance = 0;
      
      for (final transaction in sortedTransactions) {
         final oldBalance = runningBalance;
         double amountChange = transaction.type == TransactionType.lent 
             ? transaction.amount 
             : -transaction.amount;
         final newBalance = oldBalance + amountChange;
         runningBalance = newBalance;
         
         final delta = computeFriendBudgetDelta(oldBalance, newBalance, false);
         
         if (delta != 0) {
           final shadowEvent = ShadowEvent(
             timestamp: transaction.date,
             oldBalance: oldBalance,
             newBalance: newBalance,
             deltaBudget: delta,
             isVisible: true,
             friendId: friend.id,
             transactionId: transaction.id,
           );
           await addShadowEvent(shadowEvent);
         }
      }
    }
  }

  /// Delete a shadow event
  static Future<void> deleteShadowEvent(ShadowEvent event) async {
    // If visible and linked to transaction, delete transaction too
    if (event.isVisible && event.friendId != null && event.transactionId != null) {
      final friend = getFriend(event.friendId!);
      if (friend != null) {
        friend.removeTransaction(event.transactionId!);
        await saveFriend(friend);
      }
    }
    
    // Delete from shadow box
    await event.delete();
  }

  /// Get total spent this month based on shadow ledger (Gross - only positives)
  static double getSpentThisMonth(DateTime month) {
    return getGrossSpentThisMonth(getShadowEventsForMonth(month));
  }

  /// Get gross spent (sum of positive deltas only)
  static double getGrossSpentThisMonth(List<ShadowEvent> events) {
    final total = events
      .where((e) => e.deltaBudget > 0)
      .fold(0.0, (sum, e) => sum + e.deltaBudget);
    return total;
  }

  /// Get net used (sum of all deltas, including negatives)
  static double getNetUsedThisMonth(List<ShadowEvent> events) {
    final total = events.fold(0.0, (sum, e) => sum + e.deltaBudget);
    return total;
  }
}
