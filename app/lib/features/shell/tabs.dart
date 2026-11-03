import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab positions, so a card on Home can send the owner to Insights or Bills.
const tabHomeIndex = 0;
const tabObligations = 2;
const tabInsights = 3;

final tabControllerProvider = Provider<CupertinoTabController>((ref) {
  final c = CupertinoTabController();
  ref.onDispose(c.dispose);
  return c;
});
