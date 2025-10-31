import '../models/transaction.dart';

/// Represents a group of transactions with the same name and amount
class TransactionGroup {
  final String note;
  final double amount;
  final TransactionType type;
  final List<Transaction> transactions;

  TransactionGroup({
    required this.note,
    required this.amount,
    required this.type,
    required this.transactions,
  });

  int get count => transactions.length;
  
  double get totalAmount => amount * count;
  
  bool get isGrouped => count > 1;

  /// Creates transaction groups from a list of transactions
  static List<TransactionGroup> groupTransactions(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    
    for (var transaction in transactions) {
      // Create a key combining note, amount, and type (lent/borrowed)
      // This ensures borrowed and lent transactions are NOT grouped together
      final key = '${transaction.note.toLowerCase()}_${transaction.amount.toStringAsFixed(2)}_${transaction.type.name}';
      
      if (grouped.containsKey(key)) {
        grouped[key]!.add(transaction);
      } else {
        grouped[key] = [transaction];
      }
    }
    
    // Convert to TransactionGroup objects
    return grouped.values.map((transactionList) {
      transactionList.sort((a, b) => b.date.compareTo(a.date)); // Sort by date, newest first
      
      return TransactionGroup(
        note: transactionList.first.note,
        amount: transactionList.first.amount,
        type: transactionList.first.type,
        transactions: transactionList,
      );
    }).toList();
  }

  /// Sort groups by most recent transaction date
  static void sortGroupsByDate(List<TransactionGroup> groups) {
    groups.sort((a, b) {
      final aLatest = a.transactions.first.date;
      final bLatest = b.transactions.first.date;
      return bLatest.compareTo(aLatest);
    });
  }
}
