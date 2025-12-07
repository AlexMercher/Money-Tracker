import 'package:hive/hive.dart';

part 'user.g.dart';

/// Represents the app user's profile information
@HiveType(typeId: 5)
class User extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String phoneNumber;

  @HiveField(2)
  String upiId;

  @HiveField(3, defaultValue: 0.0)
  double monthlyBudget;

  @HiveField(4, defaultValue: false)
  bool carryBudgetToNextMonth;

  User({
    required this.name,
    required this.phoneNumber,
    required this.upiId,
    this.monthlyBudget = 0.0,
    this.carryBudgetToNextMonth = false,
  });

  /// Creates a copy of this user with given fields replaced
  User copyWith({
    String? name,
    String? phoneNumber,
    String? upiId,
    double? monthlyBudget,
    bool? carryBudgetToNextMonth,
  }) {
    return User(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      carryBudgetToNextMonth: carryBudgetToNextMonth ?? this.carryBudgetToNextMonth,
    );
  }

  @override
  String toString() {
    return 'User(name: $name, phoneNumber: $phoneNumber, upiId: $upiId, budget: $monthlyBudget, carryOver: $carryBudgetToNextMonth)';
  }
}
