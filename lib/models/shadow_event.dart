import 'package:hive/hive.dart';

part 'shadow_event.g.dart';

@HiveType(typeId: 6)
class ShadowEvent extends HiveObject {
  @HiveField(0)
  DateTime timestamp;

  @HiveField(1)
  double oldBalance;

  @HiveField(2)
  double newBalance;

  @HiveField(3)
  double deltaBudget;

  @HiveField(4)
  bool isVisible;

  @HiveField(5)
  String? friendId;

  @HiveField(6)
  String? transactionId;

  ShadowEvent({
    required this.timestamp,
    required this.oldBalance,
    required this.newBalance,
    required this.deltaBudget,
    required this.isVisible,
    this.friendId,
    this.transactionId,
  });
}

