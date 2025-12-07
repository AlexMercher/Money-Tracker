import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/utils/budget_logic.dart';

void main() {
  group('computeFriendBudgetDelta – movement & sign rules', () {

    // zero → non-zero (away from zero)
    test('0 → +100 (lend) = +100', () {
      expect(computeFriendBudgetDelta(0, 100, false), 100);
    });

    test('0 → -200 (they paid for me) = +200', () {
      expect(computeFriendBudgetDelta(0, -200, false), 200);
    });

    // movement TO zero
    test('+300 → 0 (they repaid fully) = -300', () {
      expect(computeFriendBudgetDelta(300, 0, false), -300);
    });

    test('-150 → 0 (I repaid fully) = 0', () {
      expect(computeFriendBudgetDelta(-150, 0, false), 0);
    });

    // same-sign away from zero
    test('+100 → +250 (lend more) = +150', () {
      expect(computeFriendBudgetDelta(100, 250, false), 150);
    });

    test('-100 → -250 (I owe more) = +150', () {
      expect(computeFriendBudgetDelta(-100, -250, false), 150);
    });

    // same-sign toward zero
    test('+200 → +100 (partial repay to me) = 0', () {
      expect(computeFriendBudgetDelta(200, 100, false), 0);
    });

    test('-200 → -100 (partial repay by me) = 0', () {
      expect(computeFriendBudgetDelta(-200, -100, false), 0);
    });

    // sign flip +X → -Y (they repaid + extra coverage)
    test('+100 → -50 (friend repays 100, then pays extra 50 for me) = -50', () {
      // -100 (freed) + 50 (new exposure) = -50 net (budget freed by 50)
      expect(computeFriendBudgetDelta(100, -50, false), -50);
    });

    // sign flip -X → +Y (I repaid fully, then lent new money)
    test('-100 → +50 (I repay debt, then lend 50) = +50', () {
      expect(computeFriendBudgetDelta(-100, 50, false), 50);
    });

    // pure cash transfer
    test('Pure cash transfer always = 0', () {
      expect(computeFriendBudgetDelta(0, 100, true), 0);
      expect(computeFriendBudgetDelta(-100, 0, true), 0);
      expect(computeFriendBudgetDelta(50, -20, true), 0);
    });
  });
}
