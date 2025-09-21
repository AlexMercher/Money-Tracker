import 'package:hive/hive.dart';

part 'transaction.g.dart';

/// Represents a transaction between user and a friend
@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  TransactionType type;

  @HiveField(3)
  String note;

  @HiveField(4)
  DateTime date;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
  });

  /// Returns the amount as positive for lent, negative for borrowed
  double get signedAmount {
    return type == TransactionType.lent ? amount : -amount;
  }

  /// Creates a copy of this transaction with given fields replaced
  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? note,
    DateTime? date,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, amount: $amount, type: $type, note: $note, date: $date)';
  }
}

/// Enum representing transaction type
@HiveType(typeId: 1)
enum TransactionType {
  @HiveField(0)
  lent, // User lent money (positive)
  
  @HiveField(1)
  borrowed, // User borrowed money (negative)
}