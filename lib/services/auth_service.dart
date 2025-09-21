import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Service for handling biometric and PIN authentication
class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

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
  static Future<bool> authenticate() async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access MoneyTrack',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/password as fallback
          stickyAuth: true, // Keep auth state during app lifecycle
        ),
      );
      return isAuthenticated;
    } on PlatformException catch (e) {
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
        default:
          return false;
      }
    } catch (e) {
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