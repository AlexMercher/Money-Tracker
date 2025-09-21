import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/screens/home_screen.dart';
import 'package:moneytrack/services/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

void main() {
  group('Screen Widget Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      // Setup test environment
      tempDir = await Directory.systemTemp.createTemp('widget_test');
      await Hive.initFlutter(tempDir.path);
      await HiveService.init();
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      // Clear data before each test
      final friends = HiveService.getAllFriends();
      for (final friend in friends) {
        await HiveService.deleteFriend(friend.id);
      }
    });

    testWidgets('HomeScreen should display empty state when no friends', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Should show empty state
      expect(find.text('No friends added yet'), findsOneWidget);
      expect(find.text('Start tracking money by adding your first transaction'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      
      // Should have add transaction button
      expect(find.text('Add Transaction'), findsWidgets);
    });

    testWidgets('HomeScreen should display app bar correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Check app bar
      expect(find.text('MoneyTrack'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('HomeScreen should show floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Check floating action button
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('HomeScreen refresh button should work', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Should still show empty state after refresh
      expect(find.text('No friends added yet'), findsOneWidget);
    });

    testWidgets('HomeScreen should handle loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Initially might show loading indicator briefly
      await tester.pump(Duration.zero);
      
      // Then should show content
      await tester.pumpAndSettle();
      
      // Should eventually show empty state or content
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}