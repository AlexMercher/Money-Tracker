import 'dart:async';

abstract class AuthController {
  Future<bool> requestAuth();
}

class FriendLogic {
  final AuthController auth;
  
  // Callbacks
  Function()? clearVisibleHistory;
  Function()? settleFriendBalance;
  
  // UI Callbacks
  Future<bool> Function({required String title, required String message})? showConfirmDialog;

  FriendLogic({required this.auth});

  Future<void> onClearHistoryPressed() async {
    final authOk = await auth.requestAuth();
    if (!authOk) return;  // DO NOTHING if auth fails

    final confirm = await showConfirmDialog?.call(
      title: 'Clear History',
      message: 'This will remove all visible transactions for this friend. Continue?',
    ) ?? false;

    if (confirm) {
      await clearVisibleHistory?.call();
    }
  }

  Future<void> onSettleBalancePressed() async {
    final authOk = await auth.requestAuth();
    if (!authOk) return;  // NO CHANGES if auth fails

    final confirm = await showConfirmDialog?.call(
      title: 'Settle Balance',
      message: 'Are you sure you want to settle this balance?',
    ) ?? false;

    if (confirm) {
      await settleFriendBalance?.call();
    }
  }
}
