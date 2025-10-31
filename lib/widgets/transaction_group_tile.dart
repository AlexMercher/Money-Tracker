import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/transaction_group.dart';
import '../utils/color_utils.dart';

/// Widget that displays a transaction group with expandable details
class TransactionGroupTile extends StatefulWidget {
  final TransactionGroup group;
  final VoidCallback? onDelete;
  final bool showActions;
  final Function(Transaction)? onTransactionTap;

  const TransactionGroupTile({
    super.key,
    required this.group,
    this.onDelete,
    this.showActions = true,
    this.onTransactionTap,
  });

  @override
  State<TransactionGroupTile> createState() => _TransactionGroupTileState();
}

class _TransactionGroupTileState extends State<TransactionGroupTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.group.type == TransactionType.lent;
    final color = isPositive ? ColorUtils.positiveColor : ColorUtils.negativeColor;
    final lightColor = isPositive ? ColorUtils.positiveLightColor : ColorUtils.negativeLightColor;
    final sign = isPositive ? '+' : '-';
    final typeText = isPositive ? 'Lent' : 'Borrowed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: widget.group.isGrouped ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(widget.group.isGrouped ? 0.3 : 0.2),
            width: widget.group.isGrouped ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Main tile
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              onTap: widget.group.isGrouped 
                  ? _toggleExpanded 
                  : (widget.onTransactionTap != null 
                      ? () => widget.onTransactionTap!(widget.group.transactions.first)
                      : null),
              
              // Leading icon
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lightColor,
                  shape: BoxShape.circle,
                ),
                child: widget.group.isGrouped
                    ? Center(
                        child: Text(
                          'x${widget.group.count}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Icon(
                        isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 20,
                      ),
              ),
              
              // Transaction details
              title: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.group.note.isNotEmpty
                                ? widget.group.note
                                : 'No note',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.group.isGrouped) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'x${widget.group.count}',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Amount
                  Text(
                    '$sign₹${widget.group.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        
                        // Date or date range
                        Text(
                          _getDateText(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                        ),
                        
                        if (widget.group.isGrouped) ...[
                          const SizedBox(width: 8),
                          RotationTransition(
                            turns: _iconRotation,
                            child: Icon(
                              Icons.expand_more,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Show split items if present (for single transactions)
                    if (!widget.group.isGrouped && widget.group.transactions.first.hasSplitItems) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: _buildSplitItemsList(widget.group.transactions.first),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action buttons (only show for single transactions)
              trailing: !widget.group.isGrouped && widget.showActions
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'delete':
                            widget.onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    )
                  : null,
            ),
            
            // Expanded details for grouped transactions
            if (_isExpanded && widget.group.isGrouped)
              Container(
                decoration: BoxDecoration(
                  color: lightColor.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Individual Transactions:',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...widget.group.transactions.map((transaction) {
                            final dateFormatter = DateFormat('MMM dd, yyyy');
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: color,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dateFormatter.format(transaction.date),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                      Text(
                                        '₹${transaction.amount.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Show split items if present
                                  if (transaction.hasSplitItems) ...[
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    _buildCompactSplitItemsList(transaction),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDateText() {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    
    if (!widget.group.isGrouped) {
      return dateFormatter.format(widget.group.transactions.first.date);
    }
    
    // Show date range for grouped transactions
    final latest = widget.group.transactions.first.date;
    final oldest = widget.group.transactions.last.date;
    
    if (latest.year == oldest.year &&
        latest.month == oldest.month &&
        latest.day == oldest.day) {
      return dateFormatter.format(latest);
    }
    
    return '${DateFormat('MMM dd').format(oldest)} - ${DateFormat('MMM dd, yyyy').format(latest)}';
  }

  Widget _buildSplitItemsList(Transaction transaction) {
    final items = transaction.splitItems!;
    final displayItems = items.take(3).toList();
    final hasMore = items.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Total amount
        Row(
          children: [
            Text(
              'Total: ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
            ),
            Text(
              '₹${transaction.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        const Divider(height: 1),
        const SizedBox(height: 4),
        
        // Split items
        ...displayItems.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '₹${item.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${item.description})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        
        // Show more items indicator
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${items.length - 3} more items',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactSplitItemsList(Transaction transaction) {
    final items = transaction.splitItems!;
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹${item.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '(${item.description})',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
