import '../models/split_item.dart';

/// Utility class for parsing mathematical expressions and mapping them to descriptions
class ExpressionParser {
  /// Parse an expression like "20+30+90" and evaluate it
  static double? evaluateExpression(String expression) {
    try {
      expression = expression.replaceAll(' ', '');
      if (expression.isEmpty) return null;
      
      // If it's just a number, return it
      final simpleNumber = double.tryParse(expression);
      if (simpleNumber != null) return simpleNumber;
      
      // Parse and evaluate the expression
      final result = _evaluateTokens(_tokenize(expression));
      return result;
    } catch (e) {
      return null;
    }
  }
  
  /// Extract individual amounts from an expression with their signs
  /// Returns a list of amounts with proper signs (positive or negative)
  /// For multiplication/division, evaluates them first, then treats result as one amount
  static List<double> extractAmounts(String expression) {
    try {
      expression = expression.replaceAll(' ', '');
      if (expression.isEmpty) return [];
      
      final amounts = <double>[];
      final tokens = _tokenize(expression);
      
      double currentSign = 1.0; // Start with positive for first number
      int i = 0;
      
      while (i < tokens.length) {
        final token = tokens[i];
        
        if (token == '+') {
          currentSign = 1.0;
          i++;
        } else if (token == '-') {
          currentSign = -1.0;
          i++;
        } else {
          // Found a number
          double currentAmount = double.tryParse(token) ?? 0;
          
          // Check if next is multiplication or division
          while (i + 1 < tokens.length && (tokens[i + 1] == '*' || tokens[i + 1] == '/')) {
            final operator = tokens[i + 1];
            if (i + 2 < tokens.length) {
              final nextNumber = double.tryParse(tokens[i + 2]) ?? 1;
              if (operator == '*') {
                currentAmount *= nextNumber;
              } else if (operator == '/') {
                currentAmount /= nextNumber;
              }
              i += 2; // Skip operator and number
            } else {
              break;
            }
          }
          
          if (currentAmount > 0) {
            amounts.add(currentAmount * currentSign);
          }
          i++;
        }
      }
      
      return amounts;
    } catch (e) {
      return [];
    }
  }
  
  /// Parse expression and map amounts to descriptions
  /// Example: expression="20+30", descriptions="corn coke" 
  /// Result: 20->Corn, 30->Coke (exact match, use descriptions)
  /// Example: expression="55-30", descriptions="cake pepsi"
  /// Result: 55->Cake, -30->Pepsi (preserves signs)
  /// Example: expression="20+30", descriptions="corn coke cake"
  /// Result: 20->Item 1, 30->Item 2 (mismatch, use Item N and keep full note visible)
  /// Example: expression="20+30+50", descriptions="corn coke"
  /// Result: 20->Item 1, 30->Item 2, 50->Item 3 (mismatch, use Item N)
  /// Returns list of SplitItem objects with capitalized descriptions and proper signs
  static List<SplitItem> parseWithDescriptions(String expression, String descriptions) {
    try {
      final amounts = extractAmounts(expression); // Now includes signs
      if (amounts.isEmpty) return [];
      
      // Trim and split descriptions by space or comma
      final descList = descriptions
          .trim()
          .split(RegExp(r'[,\s]+')) // Split by comma or space
          .where((d) => d.isNotEmpty)
          .toList();
      
      final splitItems = <SplitItem>[];
      
      // Only use descriptions if count matches exactly with amounts
      final useDescriptions = descList.length == amounts.length;
      
      for (int i = 0; i < amounts.length; i++) {
        final description = useDescriptions
            ? _capitalizeFirst(descList[i])  // Use provided description (capitalize)
            : 'Item ${i + 1}';  // Use Item N if mismatch
        
        splitItems.add(SplitItem(
          amount: amounts[i].abs(), // Store absolute value
          description: description,
          isNegative: amounts[i] < 0, // Track if it was subtracted
        ));
      }
      
      return splitItems;
    } catch (e) {
      return [];
    }
  }
  
  /// Capitalize first letter of a string
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Tokenize the expression into numbers and operators
  static List<String> _tokenize(String expression) {
    final tokens = <String>[];
    String currentNumber = '';
    
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      
      if (char == '+' || char == '-' || char == '*' || char == '/') {
        if (currentNumber.isNotEmpty) {
          tokens.add(currentNumber);
          currentNumber = '';
        }
        tokens.add(char);
      } else if (char == '.' || (char.codeUnitAt(0) >= '0'.codeUnitAt(0) && 
                                  char.codeUnitAt(0) <= '9'.codeUnitAt(0))) {
        currentNumber += char;
      }
    }
    
    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber);
    }
    
    return tokens;
  }
  
  /// Evaluate tokens following order of operations
  static double _evaluateTokens(List<String> tokens) {
    if (tokens.isEmpty) return 0;
    
    // First pass: handle multiplication and division
    final firstPass = <String>[];
    int i = 0;
    while (i < tokens.length) {
      if (i + 2 < tokens.length && (tokens[i + 1] == '*' || tokens[i + 1] == '/')) {
        // Found pattern: number operator number
        final left = double.parse(tokens[i]);
        final operator = tokens[i + 1];
        final right = double.parse(tokens[i + 2]);
        
        final result = operator == '*' ? left * right : left / right;
        firstPass.add(result.toString());
        i += 3; // Skip all three tokens
      } else {
        firstPass.add(tokens[i]);
        i++;
      }
    }
    
    // Second pass: handle addition and subtraction
    if (firstPass.isEmpty) return 0;
    
    double result = double.parse(firstPass[0]);
    for (int i = 1; i < firstPass.length; i += 2) {
      if (i + 1 >= firstPass.length) break;
      
      final operator = firstPass[i];
      final operand = double.parse(firstPass[i + 1]);
      
      if (operator == '+') {
        result += operand;
      } else if (operator == '-') {
        result -= operand;
      }
    }
    
    return result;
  }
  
  /// Check if a string contains valid mathematical expression
  static bool isValidExpression(String expression) {
    if (expression.trim().isEmpty) return false;
    
    // Check if it's a simple number
    if (double.tryParse(expression.trim()) != null) return true;
    
    // Check if it contains operators
    final hasOperators = expression.contains(RegExp(r'[+\-*/]'));
    if (!hasOperators) return false;
    
    // Try to evaluate
    final result = evaluateExpression(expression);
    return result != null && result > 0;
  }
}
