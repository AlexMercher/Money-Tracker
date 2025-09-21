import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moneytrack/models/friend.dart';
import 'package:moneytrack/models/transaction.dart';
import 'package:moneytrack/services/hive_service.dart';
import 'dart:io';

void main() {
  group('HiveService CRUD Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test database
      tempDir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(tempDir.path);
      
      // Register adapters
      Hive.registerAdapter(FriendAdapter());
      Hive.registerAdapter(TransactionAdapter());
      Hive.registerAdapter(TransactionTypeAdapter());
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      // Clear all data before each test
      final box = await Hive.openBox<Friend>('friends');
      await box.clear();
      await box.close();
    });

    test('should initialize HiveService correctly', () async {
      // This test is implicit in the setup
      expect(Hive.isAdapterRegistered(2), isTrue); // Friend adapter
      expect(Hive.isAdapterRegistered(0), isTrue); // Transaction adapter
      expect(Hive.isAdapterRegistered(1), isTrue); // TransactionType adapter
    });

    test('should save and retrieve friends', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend = Friend(id: '1', name: 'John Doe');
      await box.put(friend.id, friend);
      
      final retrieved = box.get('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('John Doe'));
      expect(retrieved.id, equals('1'));
      
      await box.close();
    });

    test('should handle friend with transactions', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend = Friend(id: '1', name: 'Jane Smith');
      friend.addTransaction(Transaction(
        id: 't1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Lunch money',
        date: DateTime.now(),
      ));
      
      await box.put(friend.id, friend);
      
      final retrieved = box.get('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.transactions.length, equals(1));
      expect(retrieved.transactions.first.amount, equals(100.0));
      expect(retrieved.transactions.first.type, equals(TransactionType.lent));
      expect(retrieved.netBalance, equals(100.0));
      
      await box.close();
    });

    test('should update friend data', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend = Friend(id: '1', name: 'Original Name');
      await box.put(friend.id, friend);
      
      // Update friend name
      final updated = friend.copyWith(name: 'Updated Name');
      await box.put(updated.id, updated);
      
      final retrieved = box.get('1');
      expect(retrieved!.name, equals('Updated Name'));
      
      await box.close();
    });

    test('should delete friends', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend = Friend(id: '1', name: 'To Delete');
      await box.put(friend.id, friend);
      
      expect(box.get('1'), isNotNull);
      
      await box.delete('1');
      expect(box.get('1'), isNull);
      
      await box.close();
    });

    test('should handle multiple friends', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend1 = Friend(id: '1', name: 'Friend One');
      final friend2 = Friend(id: '2', name: 'Friend Two');
      final friend3 = Friend(id: '3', name: 'Friend Three');
      
      await box.put(friend1.id, friend1);
      await box.put(friend2.id, friend2);
      await box.put(friend3.id, friend3);
      
      expect(box.length, equals(3));
      
      final allFriends = box.values.toList();
      final names = allFriends.map((f) => f.name).toSet();
      expect(names, contains('Friend One'));
      expect(names, contains('Friend Two'));
      expect(names, contains('Friend Three'));
      
      await box.close();
    });

    test('should persist data across box closures', () async {
      // Save data
      var box = await Hive.openBox<Friend>('friends');
      final friend = Friend(id: '1', name: 'Persistent Friend');
      friend.addTransaction(Transaction(
        id: 't1',
        amount: 250.0,
        type: TransactionType.borrowed,
        note: 'Test transaction',
        date: DateTime.now(),
      ));
      
      await box.put(friend.id, friend);
      await box.close();
      
      // Reopen and verify data persists
      box = await Hive.openBox<Friend>('friends');
      final retrieved = box.get('1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Persistent Friend'));
      expect(retrieved.transactions.length, equals(1));
      expect(retrieved.netBalance, equals(-250.0));
      
      await box.close();
    });

    test('should handle transaction updates correctly', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      final friend = Friend(id: '1', name: 'Transaction Test');
      final transaction = Transaction(
        id: 't1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Original',
        date: DateTime.now(),
      );
      
      friend.addTransaction(transaction);
      await box.put(friend.id, friend);
      
      // Update transaction
      final updatedTransaction = transaction.copyWith(
        amount: 200.0,
        note: 'Updated',
      );
      
      friend.updateTransaction(updatedTransaction);
      await box.put(friend.id, friend);
      
      final retrieved = box.get('1');
      expect(retrieved!.transactions.first.amount, equals(200.0));
      expect(retrieved.transactions.first.note, equals('Updated'));
      
      await box.close();
    });

    test('should handle empty database', () async {
      final box = await Hive.openBox<Friend>('friends');
      
      expect(box.isEmpty, isTrue);
      expect(box.length, equals(0));
      expect(box.values.toList(), isEmpty);
      
      await box.close();
    });
  });
}