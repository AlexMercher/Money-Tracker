import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/models/shadow_event.dart';
import 'package:moneytrack/utils/budget_logic.dart';
import 'package:moneytrack/services/hive_service.dart';

void main() {
  group('Budget Consistency Tests', () {
    
    test('Sequence 1: Lend 300 then Repay 300 -> Net Used 0', () {
      // Step 1: Lend 300
      double oldBalance1 = 0;
      double newBalance1 = 300;
      double delta1 = computeFriendBudgetDelta(oldBalance1, newBalance1, false);
      
      expect(delta1, 300); // Spent 300
      
      final event1 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance1,
        newBalance: newBalance1,
        deltaBudget: delta1,
        isVisible: true,
      );

      // Step 2: Repay 300
      double oldBalance2 = 300;
      double newBalance2 = 0;
      double delta2 = computeFriendBudgetDelta(oldBalance2, newBalance2, false);
      
      expect(delta2, -300); // Budget freed 300
      
      final event2 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance2,
        newBalance: newBalance2,
        deltaBudget: delta2,
        isVisible: true,
      );

      // Aggregation
      final events = [event1, event2];
      final netUsed = HiveService.getNetUsedThisMonth(events);
      final grossSpent = HiveService.getGrossSpentThisMonth(events);
      
      expect(netUsed, 0);
      expect(grossSpent, 300); // We did spend 300, even if we got it back
    });

    test('Sequence 2: Borrow 200 then Repay 200 -> Net Used 200', () {
      // Step 1: Borrow 200 (They pay for me)
      double oldBalance1 = 0;
      double newBalance1 = -200;
      double delta1 = computeFriendBudgetDelta(oldBalance1, newBalance1, false);
      
      expect(delta1, 200); // Spent 200 (liability created)
      
      final event1 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance1,
        newBalance: newBalance1,
        deltaBudget: delta1,
        isVisible: true,
      );

      // Step 2: Repay 200 (I pay them back)
      double oldBalance2 = -200;
      double newBalance2 = 0;
      double delta2 = computeFriendBudgetDelta(oldBalance2, newBalance2, false);
      
      expect(delta2, 0); // Repayment does not free budget
      
      final event2 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance2,
        newBalance: newBalance2,
        deltaBudget: delta2,
        isVisible: true,
      );

      // Aggregation
      final events = [event1, event2];
      final netUsed = HiveService.getNetUsedThisMonth(events);
      
      expect(netUsed, 200); // Still spent 200 overall
    });

    test('Sequence 3: Lend 100 then Sign Flip to -50 -> Net Used 50', () {
      // Step 1: Lend 100
      double oldBalance1 = 0;
      double newBalance1 = 100;
      double delta1 = computeFriendBudgetDelta(oldBalance1, newBalance1, false);
      
      expect(delta1, 100);
      
      final event1 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance1,
        newBalance: newBalance1,
        deltaBudget: delta1,
        isVisible: true,
      );

      // Step 2: Sign Flip to -50 (They repay 100 AND pay 50 for me)
      double oldBalance2 = 100;
      double newBalance2 = -50;
      double delta2 = computeFriendBudgetDelta(oldBalance2, newBalance2, false);
      
      // Expected: -100 (freed) + 50 (new spend) = -50
      expect(delta2, -50);
      
      final event2 = ShadowEvent(
        timestamp: DateTime.now(),
        oldBalance: oldBalance2,
        newBalance: newBalance2,
        deltaBudget: delta2,
        isVisible: true,
      );

      // Aggregation
      final events = [event1, event2];
      final netUsed = HiveService.getNetUsedThisMonth(events);
      
      expect(netUsed, 50); // 100 - 50 = 50. Correct.
    });
  });
}
