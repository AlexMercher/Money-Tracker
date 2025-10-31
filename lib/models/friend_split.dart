/// Represents a friend's share in a split transaction
class FriendSplit {
  String friendName;
  double amount;
  String note;
  bool isExistingFriend;

  FriendSplit({
    required this.friendName,
    required this.amount,
    this.note = '',
    this.isExistingFriend = false,
  });

  FriendSplit copyWith({
    String? friendName,
    double? amount,
    String? note,
    bool? isExistingFriend,
  }) {
    return FriendSplit(
      friendName: friendName ?? this.friendName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isExistingFriend: isExistingFriend ?? this.isExistingFriend,
    );
  }
}
