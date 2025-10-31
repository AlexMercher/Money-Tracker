import 'package:hive/hive.dart';

part 'split_item.g.dart';

/// Represents an individual item in a split transaction
@HiveType(typeId: 3)
class SplitItem extends HiveObject {
  @HiveField(0)
  double amount;

  @HiveField(1)
  String description;
  
  @HiveField(2, defaultValue: false)
  bool isNegative; // Track if this was a subtracted item

  SplitItem({
    required this.amount,
    required this.description,
    this.isNegative = false,
  });

  SplitItem copyWith({
    double? amount,
    String? description,
    bool? isNegative,
  }) {
    return SplitItem(
      amount: amount ?? this.amount,
      description: description ?? this.description,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  String toString() {
    return 'SplitItem(amount: $amount, description: $description, isNegative: $isNegative)';
  }
}
