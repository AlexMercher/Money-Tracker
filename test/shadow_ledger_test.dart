import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:moneytrack/models/shadow_event.dart';
import 'package:moneytrack/models/transaction.dart';
import 'package:moneytrack/services/hive_service.dart';

void main() {
  group('Shadow Ledger Tests', () {
    setUp(() async {
      await setUpTestHive();
      // Register adapters if needed, but HiveService.init() usually does it.
      // Since we can't easily mock HiveService.init() without Flutter binding,
      // we might need to manually register adapters or mock the box.
      // For unit tests of models, we can just test the model logic if any.
      // But ShadowEvent is a data class.
      // The logic is in HiveService.
      
      // We will mock the behavior or assume HiveService logic is tested via integration-like tests
      // or we can try to use HiveService with test hive.
      
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ShadowEventAdapter());
      }
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TransactionAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(TransactionTypeAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('ShadowEvent properties are correctly stored', () {
      final now = DateTime.now();
      final event = ShadowEvent(
        timestamp: now,
        oldBalance: 100,
        newBalance: 200,
        deltaBudget: 100,
        isVisible: true,
        friendId: 'f1',
        transactionId: 't1',
      );

      expect(event.timestamp, now);
      expect(event.oldBalance, 100);
      expect(event.newBalance, 200);
      expect(event.deltaBudget, 100);
      expect(event.isVisible, true);
      expect(event.friendId, 'f1');
      expect(event.transactionId, 't1');
    });

    test('Pseudo-backdating logic: Transaction ledgerDate vs date', () {
      // This tests the concept, not the HiveService implementation directly 
      // as we can't easily spin up the full service here without more mocking.
      
      final visibleDate = DateTime(2023, 1, 1);
      final ledgerDate = DateTime.now();
      
      final transaction = Transaction(
        id: 't1',
        amount: 100,
        type: TransactionType.lent,
        note: 'Backdated',
        date: visibleDate,
        ledgerDate: ledgerDate,
      );
      
      expect(transaction.date, visibleDate);
      expect(transaction.ledgerDate, ledgerDate);
      
      // Logic check: Shadow Event should use ledgerDate
      final shadowEvent = ShadowEvent(
        timestamp: transaction.ledgerDate ?? transaction.date,
        oldBalance: 0,
        newBalance: 100,
        deltaBudget: 100,
        isVisible: true,
      );
      
      expect(shadowEvent.timestamp, ledgerDate);
      expect(shadowEvent.timestamp, isNot(visibleDate));
    });
  });
}
