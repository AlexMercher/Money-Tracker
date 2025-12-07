import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      
      // Mock path_provider
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          return tempDir.path;
        },
      );

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Check app bar
      expect(find.text('MoneyTrack'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('HomeScreen should show floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check floating action button
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
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