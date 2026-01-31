import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/cash_ledger_entry.dart';
import '../services/hive_service.dart';
import '../services/auth_service.dart';

class CashBorrowingLedgerScreen extends StatefulWidget {
  const CashBorrowingLedgerScreen({super.key});

  @override
  State<CashBorrowingLedgerScreen> createState() => _CashBorrowingLedgerScreenState();
}

class _CashBorrowingLedgerScreenState extends State<CashBorrowingLedgerScreen> {
  
  double get _totalOutstanding {
    final entries = HiveService.cashLedgerBox.values;
    double total = 0;
    for (var entry in entries) {
      if (entry.isBorrow) {
        total += entry.amount;
      } else {
        total -= entry.amount;
      }
    }
    return total;
  }

  Map<String, List<CashLedgerEntry>> _groupEntriesByFriend(List<CashLedgerEntry> entries) {
    final map = <String, List<CashLedgerEntry>>{};
    for (var entry in entries) {
      if (!map.containsKey(entry.friendId)) {
        map[entry.friendId] = [];
      }
      map[entry.friendId]!.add(entry);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Ledger'),
        actions: [
          ValueListenableBuilder(
            valueListenable: HiveService.cashLedgerBox.listenable(),
            builder: (context, Box<CashLedgerEntry> box, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Text(
                    'Outstanding: ₹${_totalOutstanding.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveService.cashLedgerBox.listenable(),
        builder: (context, Box<CashLedgerEntry> box, _) {
          final entries = box.values.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No cash records yet.\nUse the buttons below to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            );
          }

          final grouped = _groupEntriesByFriend(entries);
          final friendIds = grouped.keys.toList();

          return ListView.builder(
            itemCount: friendIds.length,
            itemBuilder: (context, index) {
              final friendId = friendIds[index];
              final friend = HiveService.getFriend(friendId);
              final friendName = friend?.name ?? 'Unknown Friend';
              final friendEntries = grouped[friendId]!;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    friendName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: friendEntries.map((entry) {
                    return Dismissible(
                      key: Key(entry.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Entry?'),
                            content: const Text('This will remove this record permanently.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        entry.delete();
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: entry.isBorrow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          child: Icon(
                            entry.isBorrow ? Icons.arrow_downward : Icons.arrow_upward,
                            color: entry.isBorrow ? Colors.red : Colors.green,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          entry.isBorrow ? 'Borrow' : 'Returned',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, y • h:mm a').format(entry.timestamp),
                        ),
                        trailing: Text(
                          '₹${entry.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: entry.isBorrow ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'borrow',
            onPressed: () => _showTransactionDialog(context, isBorrow: true),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: const Text('Borrow'),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'return',
            onPressed: () => _showTransactionDialog(context, isBorrow: false),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            label: const Text('Return'),
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionDialog(BuildContext context, {required bool isBorrow}) async {
    if (!isBorrow) {
      // Require auth for returning cash (paying back)
      final authenticated = await AuthService.authenticate();
      if (!authenticated) return;
    }

    final friends = HiveService.getAllFriends().where((f) => f.id != 'self').toList();
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add friends first!')),
      );
      return;
    }

    String? selectedFriendId;
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isBorrow ? 'Borrow Cash' : 'Return Cash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Friend'),
                items: friends.map((f) => DropdownMenuItem(
                  value: f.id,
                  child: Text(f.name),
                )).toList(),
                onChanged: (val) => setState(() => selectedFriendId = val),
                value: selectedFriendId,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (selectedFriendId != null && amount != null && amount > 0) {
                  final entry = CashLedgerEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    amount: amount,
                    friendId: selectedFriendId!,
                    isBorrow: isBorrow,
                    timestamp: DateTime.now(),
                  );
                  HiveService.cashLedgerBox.add(entry);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
