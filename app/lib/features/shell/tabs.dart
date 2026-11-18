import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Tab positions, so a card on Home can send the owner to Insights or Bills.
const tabHomeIndex = 0;
const tabObligations = 2;
const tabInsights = 3;

/// The selected tab outlives the shell (it is app-wide), so it is put back on Home whenever someone signs in or out:
/// signing out from More and back in, with the same or another account, opens on Home, not on More. A token refresh
/// repeats "signed in" without a change and leaves the tab alone.
final tabControllerProvider = Provider<CupertinoTabController>((ref) {
  final c = CupertinoTabController();
  ref.listen(signedInProvider, (prev, next) {
    final was = prev?.value;
    final now = next.value;
    if (now != null && was != now) c.index = tabHomeIndex;
  });
  ref.onDispose(c.dispose);
  return c;
});
