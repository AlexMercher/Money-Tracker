
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/utils/expression_parser.dart';

void main() {
  group('ExpressionParser', () {
    test('evaluates simple multiplication and division chain', () {
      expect(ExpressionParser.evaluateExpression('54*2/3'), equals(36.0));
    });

    test('evaluates simple division and multiplication chain', () {
      expect(ExpressionParser.evaluateExpression('54/2*3'), equals(81.0));
    });

    test('evaluates mixed operators', () {
      expect(ExpressionParser.evaluateExpression('2+3*4'), equals(14.0));
      expect(ExpressionParser.evaluateExpression('2*3+4'), equals(10.0));
    });
    
    test('evaluates complex expression', () {
       expect(ExpressionParser.evaluateExpression('10+5*2-4/2'), equals(18.0)); // 10 + 10 - 2 = 18
    });

    test('evaluates expression with special characters', () {
      expect(ExpressionParser.evaluateExpression('54×2÷3'), equals(36.0));
    });
  });
}
