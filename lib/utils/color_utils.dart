import 'package:flutter/material.dart';

/// Utility class for handling money-related color logic
class ColorUtils {
  // App color scheme - Light mode
  static const Color positiveColor = Color(0xFF4CAF50); // Green - user gets money
  static const Color negativeColor = Color(0xFFF44336); // Red - user owes money
  static const Color neutralColor = Color(0xFF9E9E9E); // Grey - settled/zero balance
  
  // Light versions for backgrounds - Light mode
  static const Color positiveLightColor = Color(0xFFE8F5E8);
  static const Color negativeLightColor = Color(0xFFFFEBEE);
  static const Color neutralLightColor = Color(0xFFF5F5F5);

  // Dark mode colors
  static const Color positiveColorDark = Color(0xFF66BB6A); // Lighter green for dark mode
  static const Color negativeColorDark = Color(0xFFEF5350); // Lighter red for dark mode
  static const Color neutralColorDark = Color(0xFFBDBDBD); // Lighter grey for dark mode
  
  // Dark versions for backgrounds
  static const Color positiveLightColorDark = Color(0xFF1B5E20);
  static const Color negativeLightColorDark = Color(0xFFB71C1C);
  static const Color neutralLightColorDark = Color(0xFF424242);

  /// Get friend accent color based on balance and theme
  static Color getFriendAccentColor(BuildContext context, double balance) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!isDark) {
      if (balance > 0) return positiveColor;
      if (balance < 0) return negativeColor;
      return theme.colorScheme.onSurface.withOpacity(0.6);
    }

    // Dark mode
    if (balance > 0) {
      return const Color(0xFF7AD9A3); // they owe me
    } else if (balance < 0) {
      return const Color(0xFFFF8FA3); // I owe
    } else {
      return theme.colorScheme.onSurface.withOpacity(0.6);
    }
  }

  /// Get color based on balance amount with theme context
  static Color getBalanceColor(double balance, {bool isDark = false}) {
    if (balance > 0) {
      return isDark ? positiveColorDark : positiveColor;
    } else if (balance < 0) {
      return isDark ? negativeColorDark : negativeColor;
    } else {
      return isDark ? neutralColorDark : neutralColor;
    }
  }

  /// Get light background color based on balance amount with theme context
  static Color getBalanceLightColor(double balance, {bool isDark = false}) {
    if (balance > 0) {
      return isDark ? positiveLightColorDark : positiveLightColor;
    } else if (balance < 0) {
      return isDark ? negativeLightColorDark : negativeLightColor;
    } else {
      return isDark ? neutralLightColorDark : neutralLightColor;
    }
  }

  /// Get text description for balance
  static String getBalanceText(double balance) {
    if (balance > 0) {
      return 'You Get';
    } else if (balance < 0) {
      return 'You Owe';
    } else {
      return 'Settled';
    }
  }

  /// Get formatted balance text with currency symbol
  static String getFormattedBalance(double balance) {
    if (balance == 0) {
      return '₹0';
    }
    return '₹${balance.abs().toStringAsFixed(2)}';
  }

  /// Get balance text with sign and description
  static String getBalanceWithDescription(double balance) {
    final text = getBalanceText(balance);
    final amount = getFormattedBalance(balance);
    
    if (balance == 0) {
      return '$text - $amount';
    }
    
    return '$text $amount';
  }

  /// Get icon based on balance
  static IconData getBalanceIcon(double balance) {
    if (balance > 0) {
      return Icons.arrow_downward; // Money coming to user
    } else if (balance < 0) {
      return Icons.arrow_upward; // Money going from user
    } else {
      return Icons.check_circle; // Settled
    }
  }

  /// Create a colored container with balance information
  static Container createBalanceContainer({
    required double balance,
    required Widget child,
    double borderRadius = 8.0,
    EdgeInsets? padding,
    bool isDark = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: getBalanceLightColor(balance, isDark: isDark),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: getBalanceColor(balance, isDark: isDark).withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}