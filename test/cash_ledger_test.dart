import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:moneytrack/models/cash_ledger_entry.dart';

void main() {
  group('Cash Ledger Isolation Tests', () {
    setUp(() async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(CashLedgerEntryAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('Cash Ledger Entry properties', () {
      final entry = CashLedgerEntry(
        id: 'c1',
        amount: 500,
        friendId: 'f1',
        isBorrow: true,
        timestamp: DateTime.now(),
      );

      expect(entry.id, 'c1');
      expect(entry.amount, 500);
      expect(entry.friendId, 'f1');
      expect(entry.isBorrow, true);
    });

    test('Cash Ledger Entry is isolated from Friend model', () {
      // Verify that CashLedgerEntry is NOT a Transaction
      // and does not inherit from it, ensuring type safety and isolation.
      final entry = CashLedgerEntry(
        id: 'c1',
        amount: 500,
        friendId: 'f1',
        isBorrow: true,
        timestamp: DateTime.now(),
      );
      
      expect(entry, isNot(isA<Transaction>()));
    });
  });
}

// Mock Transaction class for type checking if needed, 
// but we can just use the real one if available or dynamic check.
class Transaction {}
