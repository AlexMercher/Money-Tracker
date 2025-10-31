import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../utils/color_utils.dart';

/// Widget that displays a single transaction in a list
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  String _getDisplayNote() {
    if (!transaction.hasSplitItems) {
      return transaction.note.isNotEmpty ? transaction.note : 'No note';
    }
    
    // Has split items
    final items = transaction.splitItems!;
    
    if (items.length <= 3) {
      // Show individual items with descriptions and proper signs
      final itemDescriptions = items.map((item) => 
        '${item.isNegative ? "-" : ""}${item.amount.toStringAsFixed(0)} ${item.description}'
      ).join('\n');
      return itemDescriptions;
    } else {
      // More than 3 items: show as (20+30-50) "note"
      final amounts = items.map((item) => 
        '${item.isNegative ? "-" : ""}${item.amount.toStringAsFixed(0)}'
      ).join('+').replaceAll('+-', '-'); // Clean up +- to just -
      
      // Extract base note (before any split info or just use first item description)
      String baseNote = transaction.note;
      if (baseNote.contains('\n')) {
        baseNote = baseNote.split('\n').first;
      }
      if (baseNote.isEmpty) {
        baseNote = 'Multiple items';
      }
      
      return '($amounts) "$baseNote"';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = transaction.type == TransactionType.lent;
    final color = isPositive 
        ? (isDark ? ColorUtils.positiveColorDark : ColorUtils.positiveColor)
        : (isDark ? ColorUtils.negativeColorDark : ColorUtils.negativeColor);
    final lightColor = isPositive 
        ? (isDark ? ColorUtils.positiveLightColorDark : ColorUtils.positiveLightColor)
        : (isDark ? ColorUtils.negativeLightColorDark : ColorUtils.negativeLightColor);
    final sign = isPositive ? '+' : '-';
    final typeText = isPositive ? 'Lent' : 'Borrowed';
    final formattedDate = DateFormat('MMM dd, yyyy').format(transaction.date);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          
          // Leading icon with colored background
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: lightColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          
          // Transaction details
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _getDisplayNote(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Amount with sign
              Text(
                '$sign₹${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              
              Row(
                children: [
                  // Transaction type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Date
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  
                  // Split indicator
                  if (transaction.hasSplitItems) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ],
              ),
              
              // Show split items if present
              if (transaction.hasSplitItems) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...transaction.splitItems!.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${item.isNegative ? "-" : ""}₹${item.amount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: item.isNegative ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (transaction.splitItems!.length > 3)
                        Text(
                          '+${transaction.splitItems!.length - 3} more items',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          // Action buttons
          trailing: showActions ? PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Text('Delete'),
                  ],
                ),
              ),
            ],
            child: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ) : null,
        ),
      ),
    );
  }
}