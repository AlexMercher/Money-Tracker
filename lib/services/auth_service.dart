import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling biometric and PIN authentication
class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _authEnabledKey = 'auth_enabled';
  static const String _requireInitialAuthKey = 'require_initial_auth';
  
  /// Check if authentication is enabled in app settings
  static Future<bool> isAuthEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_authEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Enable or disable authentication
  static Future<void> setAuthEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authEnabledKey, enabled);
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if initial authentication on app open is required
  static Future<bool> requiresInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // If auth is not enabled at all, don't require initial auth
      final authEnabled = prefs.getBool(_authEnabledKey) ?? false;
      if (!authEnabled) return false;
      
      // Default to true if not set (require initial auth by default)
      return prefs.getBool(_requireInitialAuthKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Set whether initial authentication on app open is required
  static Future<void> setRequireInitialAuth(bool required) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireInitialAuthKey, required);
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if biometric authentication is available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get list of available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate user using biometrics or device credentials
  static Future<bool> authenticate({String localizedReason = 'Please authenticate to access MoneyTrack'}) async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/password as fallback
          stickyAuth: true, // Keep auth state during app lifecycle
          useErrorDialogs: true, // Show system error dialogs
          sensitiveTransaction: false, // Not a sensitive transaction
        ),
      );
      return isAuthenticated;
    } on PlatformException catch (e) {
      print('Authentication PlatformException: ${e.code} - ${e.message}');
      // Handle specific platform exceptions
      switch (e.code) {
        case 'NotAvailable':
          // Biometric authentication is not available
          return false;
        case 'NotEnrolled':
          // User has not enrolled biometrics
          return false;
        case 'LockedOut':
          // Too many failed attempts
          return false;
        case 'PermanentlyLockedOut':
          // Device is permanently locked out
          return false;
        case 'UserCancel':
          // User cancelled authentication
          return false;
        case 'PasscodeNotSet':
          // Device has no PIN/password set
          return false;
        default:
          return false;
      }
    } catch (e) {
      print('Authentication general error: $e');
      return false;
    }
  }

  /// Get authentication error message for display
  static String getAuthErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device.';
      case 'NotEnrolled':
        return 'No biometrics enrolled. Please set up biometric authentication in device settings.';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked. Please use device passcode.';
      case 'UserCancel':
        return 'Authentication was cancelled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Check if device has any authentication method (PIN, password, biometric)
  static Future<bool> hasAnyAuthMethod() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
}