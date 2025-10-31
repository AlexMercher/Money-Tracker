import 'package:hive_flutter/hive_flutter.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../models/split_item.dart';
import '../models/user.dart';

/// Service for managing local data storage using Hive
class HiveService {
  static const String _friendsBoxName = 'friends';
  static const String _userBoxName = 'user_profile';
  
  static Box<Friend>? _friendsBox;
  static Box<User>? _userBox;

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
    
    // Open boxes
    _friendsBox = await Hive.openBox<Friend>(_friendsBoxName);
    _userBox = await Hive.openBox<User>(_userBoxName);
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
    final friend = getFriend(friendId);
    if (friend != null) {
      friend.addTransaction(transaction);
      await saveFriend(friend);
    }
  }

  /// Update a transaction for a friend
  static Future<void> updateTransaction(String friendId, Transaction transaction) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      friend.updateTransaction(transaction);
      await saveFriend(friend);
    }
  }

  /// Delete a transaction from a friend
  static Future<void> deleteTransaction(String friendId, String transactionId) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      friend.removeTransaction(transactionId);
      await saveFriend(friend);
    }
  }

  /// Clear all transaction history for a friend
  static Future<void> clearFriendHistory(String friendId) async {
    final friend = getFriend(friendId);
    if (friend != null) {
      friend.clearHistory();
      await saveFriend(friend);
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
  }

  /// Clear all data (useful for testing or complete reset)
  static Future<void> clearAllData() async {
    await friendsBox.clear();
  }

  /// Delete all Hive boxes and data completely
  static Future<void> deleteAllData() async {
    await _friendsBox?.close();
    await _userBox?.close();
    await Hive.deleteBoxFromDisk(_friendsBoxName);
    await Hive.deleteBoxFromDisk(_userBoxName);
    // Reinitialize if needed
    _friendsBox = await Hive.openBox<Friend>(_friendsBoxName);
    _userBox = await Hive.openBox<User>(_userBoxName);
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
}
