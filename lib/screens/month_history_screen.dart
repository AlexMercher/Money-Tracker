import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shadow_event.dart';
import '../services/hive_service.dart';
import '../services/auth_service.dart';

class MonthHistoryScreen extends StatefulWidget {
  const MonthHistoryScreen({super.key});

  @override
  State<MonthHistoryScreen> createState() => _MonthHistoryScreenState();
}

class _MonthHistoryScreenState extends State<MonthHistoryScreen> {
  List<ShadowEvent> _events = [];
  final DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });
    
    final events = HiveService.getShadowEventsForMonth(_currentMonth);
    // Sort by timestamp descending (newest first)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  Future<void> _deleteEvent(ShadowEvent event) async {
    // Auth check
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate to delete history entry',
    );
    
    if (!authenticated) return;

    // Confirm dialog
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          event.isVisible 
              ? 'This will also delete the visible transaction from your ledger.' 
              : 'This is an internal event. Deleting it will affect your budget history.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.deleteShadowEvent(event);
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Month History'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This month\'s internal transaction history. These entries power your budget and summaries.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              monthName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('No history for this month'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final isPositive = event.deltaBudget > 0;
                          
                          return ListTile(
                            title: Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(event.timestamp),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'old: ${event.oldBalance.toStringAsFixed(2)} → new: ${event.newBalance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                Text(
                                  'deltaBudget: ${event.deltaBudget.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPositive ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: event.isVisible 
                                        ? Colors.blue.withOpacity(0.1) 
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: event.isVisible 
                                          ? Colors.blue.withOpacity(0.3) 
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    event.isVisible ? 'Visible' : 'Internal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: event.isVisible ? Colors.blue : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _deleteEvent(event),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
