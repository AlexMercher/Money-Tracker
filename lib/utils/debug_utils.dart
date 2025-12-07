import 'package:flutter/foundation.dart';

void debugBudget(String message) {
  // Only active in debug builds.
  if (kDebugMode) {
    print("🔍 [BUDGET DEBUG] $message");
  }
}
