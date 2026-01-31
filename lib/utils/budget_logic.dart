/// Computes the budget impact of a balance change
double computeFriendBudgetDelta(
  double oldBalance,
  double newBalance,
  bool isPureCashTransfer,
) {
  if (isPureCashTransfer) return 0;

  if (oldBalance == 0 && newBalance != 0) {
    return newBalance.abs();
  }

  if (newBalance == 0) {
    if (oldBalance > 0) return -oldBalance.abs();
    return 0;
  }

  final oldAbs = oldBalance.abs();
  final newAbs = newBalance.abs();

  // POSITIVE ZONE (they owe me)
  if (oldBalance > 0 && newBalance > 0) {
    if (newAbs > oldAbs) return newAbs - oldAbs;
    if (newAbs < oldAbs) return -(oldAbs - newAbs);
    return 0;
  }

  // NEGATIVE ZONE (I owe them)
  if (oldBalance < 0 && newBalance < 0) {
    if (newAbs > oldAbs) return newAbs - oldAbs;
    return 0;
  }

  // SIGN FLIP
  if (oldBalance.sign != newBalance.sign) {
    final repayPart = oldAbs;
    final newExposure = newAbs;

    if (oldBalance > 0 && newBalance < 0) {
      return -repayPart + newExposure;
    } else if (oldBalance < 0 && newBalance > 0) {
      return newExposure;
    }
  }

  return 0;
}

/// Overload for backward compatibility or simple calls where isPureCashTransfer is false
double computeFriendBudgetDelta2(double oldBalance, double newBalance) {
  return computeFriendBudgetDelta(oldBalance, newBalance, false);
}

void debugBudgetDeltaChecks() {
  final tests = [
    // [old, new]
    [100.0,  200.0],
    [100.0,   50.0],
    [-100.0, -200.0],
    [-100.0,  -50.0],
    [-100.0,   0.0],
    [-100.0, 150.0],
    [200.0,  -50.0],
    [0.0,   -250.0],
    [0.0,    300.0],
    [300.0,  500.0],
    [-400.0, -250.0],

    // NEW repayment rule checks:
    [200.0,    0.0], // friend repays full
    [150.0,    0.0], // friend repays full
    [300.0,  100.0], // partial toward zero (expect 0)
    [100.0,  -50.0], // sign flip, friend repays + new owe
  ];

  for (final t in tests) {
    final oldB = t[0];
    final newB = t[1];

    final d = computeFriendBudgetDelta(oldB, newB, false);
    print("old: $oldB  → new: $newB   | deltaBudget = $d");
  }
}