import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shadow_event.dart';
import '../../services/hive_service.dart';

class ShadowLedgerDebugScreen extends StatelessWidget {
  const ShadowLedgerDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = HiveService.shadowBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shadow Ledger Debug'),
      ),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(event.timestamp),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Delta: ${event.deltaBudget.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: event.deltaBudget > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Old Balance: ${event.oldBalance.toStringAsFixed(2)}'),
                  Text('New Balance: ${event.newBalance.toStringAsFixed(2)}'),
                  Text('Friend ID: ${event.friendId ?? "N/A"}'),
                  Text('Transaction ID: ${event.transactionId ?? "N/A"}'),
                  Text('Visible: ${event.isVisible}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
