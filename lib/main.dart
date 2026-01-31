import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/hive_service.dart';
import 'services/theme_service.dart';
import 'services/category_service.dart';
import 'app.dart';

/// Main entry point of the MoneyTrack application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations (portrait only for better UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Optimize system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize Hive storage
  await HiveService.init();
  
  // Migrate existing transactions to category Trie vocabulary (runs once)
  // Learns from ALL transaction notes (self + friends) for suggestions
  await CategoryService.migrateExistingTransactions(() {
    final List<Map<String, dynamic>> allNotes = [];
    
    // Collect notes from ALL friends (including self)
    for (final friend in HiveService.getAllFriends()) {
      for (final tx in friend.transactions) {
        allNotes.add({'note': tx.note});
      }
    }
    
    return allNotes;
  });
  
  // Initialize theme service
  final themeService = ThemeService();
  await themeService.init();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeService,
      child: const MoneyTrackApp(),
    ),
  );
}
