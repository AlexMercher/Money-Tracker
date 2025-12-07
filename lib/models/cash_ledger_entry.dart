import 'package:hive/hive.dart';

part 'cash_ledger_entry.g.dart';

@HiveType(typeId: 7)
class CashLedgerEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String friendId;

  @HiveField(3)
  bool isBorrow; // true = borrowed cash, false = returned cash

  @HiveField(4)
  DateTime timestamp;

  CashLedgerEntry({
    required this.id,
    required this.amount,
    required this.friendId,
    required this.isBorrow,
    required this.timestamp,
  });
}

