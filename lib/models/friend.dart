import 'package:hive/hive.dart';
import 'transaction.dart';

part 'friend.g.dart';

/// Represents a friend and their transaction history
@HiveType(typeId: 2)
class Friend extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<Transaction> transactions;

  Friend({
    required this.id,
    required this.name,
    List<Transaction>? transactions,
  }) : transactions = transactions ?? [];

  /// Calculates the net balance for this friend
  /// Positive = friend owes user, Negative = user owes friend
  double get netBalance {
    return transactions.fold(0.0, (sum, transaction) => sum + transaction.signedAmount);
  }

  /// Returns true if the balance is settled (zero)
  bool get isSettled => netBalance == 0.0;

  /// Adds a transaction to this friend's history
  void addTransaction(Transaction transaction) {
    transactions.add(transaction);
    if (isInBox) {
      save(); // Save to Hive automatically only if in box
    }
  }

  /// Removes a transaction from this friend's history
  void removeTransaction(String transactionId) {
    transactions.removeWhere((t) => t.id == transactionId);
    if (isInBox) {
      save(); // Save to Hive automatically only if in box
    }
  }

  /// Updates a transaction in this friend's history
  void updateTransaction(Transaction updatedTransaction) {
    final index = transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      transactions[index] = updatedTransaction;
      if (isInBox) {
        save(); // Save to Hive automatically only if in box
      }
    }
  }

  /// Clears all transaction history
  void clearHistory() {
    transactions.clear();
    if (isInBox) {
      save(); // Save to Hive automatically only if in box
    }
  }

  /// Creates a copy of this friend with given fields replaced
  Friend copyWith({
    String? id,
    String? name,
    List<Transaction>? transactions,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      transactions: transactions ?? List.from(this.transactions),
    );
  }

  @override
  String toString() {
    return 'Friend(id: $id, name: $name, balance: $netBalance, transactions: ${transactions.length})';
  }
}