import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'app.dart';

/// Main entry point of the MoneyTrack application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive storage
  await HiveService.init();
  
  runApp(const MoneyTrackApp());
}
