import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../utils/color_utils.dart';

/// Widget that displays friend balance information with color coding
class BalanceCard extends StatefulWidget {
  final Friend friend;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.friend,
    this.onTap,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300), // Increased from 100ms
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate( // Changed from 0.95 for more visible effect
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.friend.netBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Dark Mode Colors Fix
    final balanceColor = ColorUtils.getFriendAccentColor(context, balance);

    final cardBackgroundColor = isDark 
        ? const Color(0xFF1E1E22) // Dark mode card background
        : ColorUtils.getBalanceLightColor(balance, isDark: false);
        
    final balanceText = ColorUtils.getBalanceText(balance);
    final formattedBalance = ColorUtils.getFormattedBalance(balance);
    final balanceIcon = ColorUtils.getBalanceIcon(balance);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: InkWell(
        onTap: null, // Handled by GestureDetector
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? balanceColor.withOpacity(0.5) : balanceColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Friend avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? balanceColor.withOpacity(0.2) : Theme.of(context).colorScheme.surface,
                child: Text(
                  widget.friend.name.isNotEmpty 
                      ? widget.friend.name[0].toUpperCase() 
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
                      widget.friend.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Theme.of(context).colorScheme.onSurface : Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${widget.friend.transactions.length} transaction${widget.friend.transactions.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
      ),
    ),
    );
  }
}