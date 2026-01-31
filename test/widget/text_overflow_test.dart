// Text Overflow Test Suite
// ==========================
// This test verifies that the app handles text overflow gracefully
// across various screen sizes and font scales.
//
// MANUAL TESTING CHECKLIST:
// -------------------------
// [ ] Small phone width (≤ 360dp)
// [ ] Large phone width (≥ 420dp)
// [ ] Font scale 1.3x
// [ ] Long friend names (20+ characters)
// [ ] Long transaction notes (50+ characters)
// [ ] Large currency values (₹10,00,000+)
// [ ] Mixed icon + text rows
//
// WIDGET TEST EXPECTATIONS:
// -------------------------
// - No RenderFlex overflow errors
// - No clipped text
// - No multi-line wrapping where not intended

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/widgets/balance_card.dart';
import 'package:moneytrack/widgets/transaction_tile.dart';
import 'package:moneytrack/models/friend.dart';
import 'package:moneytrack/models/transaction.dart';

void main() {
  group('Text Overflow Tests', () {
    // Test helper to wrap widget in MaterialApp for theme access
    Widget wrapWithMaterial(Widget child, {double textScaleFactor = 1.0}) {
      return MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaleFactor: textScaleFactor,
              size: const Size(320, 640), // Small phone width
            ),
            child: child,
          ),
        ),
      );
    }

    testWidgets('BalanceCard handles long friend names without overflow',
        (WidgetTester tester) async {
      final friend = Friend(
        id: 'test-long-name',
        name: 'VeryVeryLongFriendNameThatShouldBeTruncated',
        transactions: [
          Transaction(
            id: '1',
            amount: 1000000.50,
            type: TransactionType.lent,
            note: 'Test note',
            date: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(wrapWithMaterial(
        SizedBox(
          width: 320,
          child: BalanceCard(friend: friend),
        ),
      ));

      // Should not throw RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('BalanceCard handles high font scale without overflow',
        (WidgetTester tester) async {
      final friend = Friend(
        id: 'test-high-scale',
        name: 'TestFriend',
        transactions: [
          Transaction(
            id: '1',
            amount: 50000.00,
            type: TransactionType.borrowed,
            note: 'High font scale test',
            date: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(wrapWithMaterial(
        SizedBox(
          width: 320,
          child: BalanceCard(friend: friend),
        ),
        textScaleFactor: 1.5, // High accessibility font scale
      ));

      // Should not throw RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('TransactionTile handles long notes without overflow',
        (WidgetTester tester) async {
      final transaction = Transaction(
        id: 'test-long-note',
        amount: 500.00,
        type: TransactionType.lent,
        note: 'This is a very long transaction note that should be truncated properly without causing any overflow issues',
        date: DateTime.now(),
      );

      await tester.pumpWidget(wrapWithMaterial(
        SizedBox(
          width: 320,
          child: TransactionTile(transaction: transaction),
        ),
      ));

      // Should not throw RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('TransactionTile handles large amounts without overflow',
        (WidgetTester tester) async {
      final transaction = Transaction(
        id: 'test-large-amount',
        amount: 9999999.99,
        type: TransactionType.lent,
        note: 'Large amount',
        date: DateTime.now(),
      );

      await tester.pumpWidget(wrapWithMaterial(
        SizedBox(
          width: 320,
          child: TransactionTile(transaction: transaction),
        ),
      ));

      // Should not throw RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Text widgets have proper overflow properties set',
        (WidgetTester tester) async {
      final transaction = Transaction(
        id: 'test-overflow-props',
        amount: 100.00,
        type: TransactionType.lent,
        note: 'Test note',
        date: DateTime.now(),
      );

      await tester.pumpWidget(wrapWithMaterial(
        SizedBox(
          width: 320,
          child: TransactionTile(transaction: transaction),
        ),
      ));

      // Find Text widgets and verify overflow handling
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      
      // At least some text widgets should have overflow handling
      bool hasOverflowHandling = textWidgets.any((text) =>
          text.overflow == TextOverflow.ellipsis ||
          text.overflow == TextOverflow.fade ||
          text.maxLines != null);

      expect(hasOverflowHandling, isTrue,
          reason: 'At least some Text widgets should have overflow handling');
    });
  });
}
