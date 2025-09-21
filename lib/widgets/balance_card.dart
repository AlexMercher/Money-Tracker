import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../utils/color_utils.dart';

/// Widget that displays friend balance information with color coding
class BalanceCard extends StatelessWidget {
  final Friend friend;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.friend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balance = friend.netBalance;
    final balanceColor = ColorUtils.getBalanceColor(balance);
    final balanceLightColor = ColorUtils.getBalanceLightColor(balance);
    final balanceText = ColorUtils.getBalanceText(balance);
    final formattedBalance = ColorUtils.getFormattedBalance(balance);
    final balanceIcon = ColorUtils.getBalanceIcon(balance);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: balanceColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Friend avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: balanceLightColor,
                child: Text(
                  friend.name.isNotEmpty 
                      ? friend.name[0].toUpperCase() 
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: balanceColor,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Friend name and transaction count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${friend.transactions.length} transaction${friend.transactions.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Balance information
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Balance amount
                  Text(
                    formattedBalance,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Balance description with icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        balanceIcon,
                        size: 16,
                        color: balanceColor,
                      ),
                      
                      const SizedBox(width: 4),
                      
                      Text(
                        balanceText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: balanceColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(width: 8),
              
              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}