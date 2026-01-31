import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
import '../services/category_service.dart';
import '../models/shadow_event.dart';

class SelfExpenseCharts extends StatefulWidget {
  final List<Transaction> transactions;

  const SelfExpenseCharts({super.key, required this.transactions});

  @override
  State<SelfExpenseCharts> createState() => _SelfExpenseChartsState();
}

class _SelfExpenseChartsState extends State<SelfExpenseCharts> {
  Map<String, String?> _noteToCategory = {};
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final mapping = await CategoryService.getNoteToDisplayLabelMap();
    if (mounted) {
      setState(() {
        _noteToCategory = mapping;
        _categoriesLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildPieChartCard(widget.transactions),
        const SizedBox(height: 16),
        _buildLineChartCard(widget.transactions),
      ],
    );
  }

  Widget _buildPieChartCard(List<Transaction> transactions) {
    // Aggregate by display label (Class B category or independent Class A note)
    final Map<String, double> displayTotals = {};
    final Map<String, List<Transaction>> transactionsByLabel = {};
    
    for (var t in transactions) {
      // Exclude Gains (Borrowed type for Self means Money In)
      if (t.type == TransactionType.borrowed) continue;

      // Clean the note
      var note = t.note.trim();
      note = note.replaceAll(RegExp(r'\s*\(my\s*share\)', caseSensitive: false), '');
      note = note.replaceAll(RegExp(r'\s*\(myshare\)', caseSensitive: false), '');
      note = note.trim();
      
      final normalizedNote = note.toLowerCase();
      
      // Determine display label:
      // - If note is assigned to a Class B category, use category name
      // - Otherwise, use the note itself (independent Class A)
      String displayLabel;
      if (_noteToCategory.containsKey(normalizedNote) && _noteToCategory[normalizedNote] != null) {
        displayLabel = _noteToCategory[normalizedNote]!.toLowerCase();
      } else {
        displayLabel = normalizedNote.isEmpty ? 'others' : normalizedNote;
      }
      
      displayTotals[displayLabel] = (displayTotals[displayLabel] ?? 0) + t.amount;
      transactionsByLabel.putIfAbsent(displayLabel, () => []).add(t);
    }

    final sortedEntries = displayTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Monthly Expenses by Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                        final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < sortedEntries.length) {
                          final label = sortedEntries[index].key;
                          final txns = transactionsByLabel[label] ?? [];
                          _showCategoryTransactions(context, label, txns);
                        }
                      }
                    },
                  ),
                  sections: sortedEntries.asMap().entries.map((entry) {
                    final data = entry.value;
                    final color = _getColorForCategory(data.key);
                    return PieChartSectionData(
                      color: color.withOpacity(0.8),
                      value: data.value,
                      title: '',
                      radius: 60,
                      showTitle: false,
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 150),
                swapAnimationCurve: Curves.linear,
              ),
            ),
            const SizedBox(height: 24),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: sortedEntries.asMap().entries.map((entry) {
                final data = entry.value;
                final color = _getColorForCategory(data.key);
                return GestureDetector(
                  onTap: () {
                    final txns = transactionsByLabel[data.key] ?? [];
                    _showCategoryTransactions(context, data.key, txns);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${toBeginningOfSentenceCase(data.key)} – ₹${data.value.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryTransactions(BuildContext context, String label, List<Transaction> transactions) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    toBeginningOfSentenceCase(label) ?? label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${transactions.length} expense(s) – ₹${transactions.fold<double>(0, (sum, t) => sum + t.amount).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.receipt_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: Text(t.note.isEmpty ? 'No note' : t.note),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(t.date)),
                    trailing: Text(
                      '₹${t.amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForCategory(String category) {
    // Deterministic color generation based on category name
    final int hash = category.toLowerCase().codeUnits.fold(0, (prev, element) => prev + element);
    
    final double hue = hash % 360.0;
    
    // Saturation 40-60%
    final double saturation = 0.4 + ((hash % 20) / 100.0);
    
    // Lightness 55-65%
    final double lightness = 0.55 + ((hash % 10) / 100.0);
    
    // Adjust for dark mode if needed (maybe slightly lighter or less saturated?)
    // But prompt says "Use theme-safe versions".
    // 55-65% lightness is generally safe for both.
    
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Widget _buildLineChartCard(List<Transaction> transactions) {
    // Use Shadow Ledger for Line Chart
    // Derive the target month from the transactions, not DateTime.now()
    // This ensures past months show their own stored graph data
    final DateTime targetMonth;
    if (transactions.isNotEmpty) {
      targetMonth = transactions.first.date;
    } else {
      targetMonth = DateTime.now();
    }
    final shadowEvents = HiveService.getShadowEventsForMonth(targetMonth);

    // Group by week
    // Week 1: Days 1-7, Week 2: 8-14, etc.
    final Map<int, double> weeklyTotals = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    for (var event in shadowEvents) {
      // Only include movement away from zero (money out / liability creation)
      if (event.deltaBudget <= 0) continue;

      final day = event.timestamp.day;
      int week = ((day - 1) / 7).floor() + 1;
      if (week > 5) week = 5; // Handle 29-31 as week 5
      weeklyTotals[week] = (weeklyTotals[week] ?? 0) + event.deltaBudget;
    }

    final spots = weeklyTotals.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final maxY = weeklyTotals.values.reduce((a, b) => a > b ? a : b);
    // Add some buffer to maxY
    final targetMaxY = maxY == 0 ? 100.0 : maxY * 1.2;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Weekly Spending',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: targetMaxY / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value < 1 || value > 5) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'W${value.toInt()}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: targetMaxY > 0 ? targetMaxY / 4 : 10,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '₹${value.toInt()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: 5,
                  minY: 0,
                  maxY: targetMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).scaffoldBackgroundColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (touchedSpot) => Theme.of(context).cardColor,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipBorder: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            'Week ${spot.x.toInt()}\nSpent: ₹${spot.y.toStringAsFixed(0)}',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 150),
                curve: Curves.linear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
