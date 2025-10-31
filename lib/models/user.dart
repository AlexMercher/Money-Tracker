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

  User({
    required this.name,
    required this.phoneNumber,
    required this.upiId,
  });

  /// Creates a copy of this user with given fields replaced
  User copyWith({
    String? name,
    String? phoneNumber,
    String? upiId,
  }) {
    return User(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
    );
  }

  @override
  String toString() {
    return 'User(name: $name, phoneNumber: $phoneNumber, upiId: $upiId)';
  }
}
