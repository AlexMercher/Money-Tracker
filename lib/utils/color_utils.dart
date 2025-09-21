import 'package:flutter/material.dart';

/// Utility class for handling money-related color logic
class ColorUtils {
  // App color scheme
  static const Color positiveColor = Color(0xFF4CAF50); // Green - user gets money
  static const Color negativeColor = Color(0xFFF44336); // Red - user owes money
  static const Color neutralColor = Color(0xFF9E9E9E); // Grey - settled/zero balance
  
  // Light versions for backgrounds
  static const Color positiveLightColor = Color(0xFFE8F5E8);
  static const Color negativeLightColor = Color(0xFFFFEBEE);
  static const Color neutralLightColor = Color(0xFFF5F5F5);

  /// Get color based on balance amount
  /// Positive balance = green (friend owes user)
  /// Negative balance = red (user owes friend)
  /// Zero balance = neutral grey
  static Color getBalanceColor(double balance) {
    if (balance > 0) {
      return positiveColor;
    } else if (balance < 0) {
      return negativeColor;
    } else {
      return neutralColor;
    }
  }

  /// Get light background color based on balance amount
  static Color getBalanceLightColor(double balance) {
    if (balance > 0) {
      return positiveLightColor;
    } else if (balance < 0) {
      return negativeLightColor;
    } else {
      return neutralLightColor;
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
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: getBalanceLightColor(balance),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: getBalanceColor(balance).withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}