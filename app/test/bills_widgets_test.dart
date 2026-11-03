import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/obligations/widgets/bills_widgets.dart';

void main() {
  test(
    'every obligation kind has its own icon, unknown falls back to fixed',
    () {
      final icons = {
        for (final k in ['bill', 'card_statement', 'loan', 'fixed'])
          kindStyle(k).icon,
      };
      expect(icons.length, 4);
      expect(kindStyle('whatever').icon, kindStyle('fixed').icon);
    },
  );

  testWidgets('pill segments report taps and mark the selected one', (
    tester,
  ) async {
    var picked = 'a';
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (c, set) => PillSegments<String>(
            value: picked,
            labels: const {'a': 'One', 'b': 'Two'},
            onChanged: (v) => set(() => picked = v),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(picked, 'b');
  });
}
