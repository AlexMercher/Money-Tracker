import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/models/friend.dart';
import 'package:moneytrack/models/transaction.dart';

void main() {
  group('Balance Calculation Tests', () {
    test('should calculate net balance correctly for lent transactions', () {
      final friend = Friend(id: '1', name: 'John');
      
      // Add lent transactions (positive balance)
      friend.addTransaction(Transaction(
        id: '1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Lunch money',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '2',
        amount: 50.0,
        type: TransactionType.lent,
        note: 'Coffee',
        date: DateTime.now(),
      ));
      
      expect(friend.netBalance, equals(150.0));
      expect(friend.isSettled, isFalse);
    });

    test('should calculate net balance correctly for borrowed transactions', () {
      final friend = Friend(id: '1', name: 'Jane');
      
      // Add borrowed transactions (negative balance)
      friend.addTransaction(Transaction(
        id: '1',
        amount: 75.0,
        type: TransactionType.borrowed,
        note: 'Movie tickets',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '2',
        amount: 25.0,
        type: TransactionType.borrowed,
        note: 'Snacks',
        date: DateTime.now(),
      ));
      
      expect(friend.netBalance, equals(-100.0));
      expect(friend.isSettled, isFalse);
    });

    test('should calculate net balance correctly for mixed transactions', () {
      final friend = Friend(id: '1', name: 'Mike');
      
      // Add mixed transactions
      friend.addTransaction(Transaction(
        id: '1',
        amount: 200.0,
        type: TransactionType.lent,
        note: 'Dinner bill',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '2',
        amount: 80.0,
        type: TransactionType.borrowed,
        note: 'Taxi fare',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '3',
        amount: 120.0,
        type: TransactionType.borrowed,
        note: 'Shopping',
        date: DateTime.now(),
      ));
      
      // Net: 200 - 80 - 120 = 0
      expect(friend.netBalance, equals(0.0));
      expect(friend.isSettled, isTrue);
    });

    test('should handle zero balance correctly', () {
      final friend = Friend(id: '1', name: 'Sarah');
      
      expect(friend.netBalance, equals(0.0));
      expect(friend.isSettled, isTrue);
    });

    test('should handle single transaction correctly', () {
      final friend = Friend(id: '1', name: 'Tom');
      
      friend.addTransaction(Transaction(
        id: '1',
        amount: 42.50,
        type: TransactionType.lent,
        note: 'Shared lunch',
        date: DateTime.now(),
      ));
      
      expect(friend.netBalance, equals(42.50));
      expect(friend.isSettled, isFalse);
    });

    test('should calculate signed amounts correctly', () {
      final lentTransaction = Transaction(
        id: '1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Test',
        date: DateTime.now(),
      );
      
      final borrowedTransaction = Transaction(
        id: '2',
        amount: 100.0,
        type: TransactionType.borrowed,
        note: 'Test',
        date: DateTime.now(),
      );
      
      expect(lentTransaction.signedAmount, equals(100.0));
      expect(borrowedTransaction.signedAmount, equals(-100.0));
    });

    test('should handle decimal amounts correctly', () {
      final friend = Friend(id: '1', name: 'Alex');
      
      friend.addTransaction(Transaction(
        id: '1',
        amount: 123.45,
        type: TransactionType.lent,
        note: 'Test',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '2',
        amount: 23.45,
        type: TransactionType.borrowed,
        note: 'Test',
        date: DateTime.now(),
      ));
      
      expect(friend.netBalance, equals(100.0));
    });

    test('should update balance when transaction is removed', () {
      final friend = Friend(id: '1', name: 'Lisa');
      
      friend.addTransaction(Transaction(
        id: '1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Test',
        date: DateTime.now(),
      ));
      
      friend.addTransaction(Transaction(
        id: '2',
        amount: 50.0,
        type: TransactionType.borrowed,
        note: 'Test',
        date: DateTime.now(),
      ));
      
      expect(friend.netBalance, equals(50.0));
      
      friend.removeTransaction('1');
      expect(friend.netBalance, equals(-50.0));
      
      friend.removeTransaction('2');
      expect(friend.netBalance, equals(0.0));
      expect(friend.isSettled, isTrue);
    });

    test('should update balance when transaction is modified', () {
      final friend = Friend(id: '1', name: 'Bob');
      
      final transaction = Transaction(
        id: '1',
        amount: 100.0,
        type: TransactionType.lent,
        note: 'Test',
        date: DateTime.now(),
      );
      
      friend.addTransaction(transaction);
      expect(friend.netBalance, equals(100.0));
      
      // Update transaction
      final updatedTransaction = transaction.copyWith(
        amount: 150.0,
        type: TransactionType.borrowed,
      );
      
      friend.updateTransaction(updatedTransaction);
      expect(friend.netBalance, equals(-150.0));
    });
  });
}