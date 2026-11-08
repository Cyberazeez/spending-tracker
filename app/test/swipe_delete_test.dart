import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/ui/swipe_action.dart';

Widget host(Widget child, {TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: CupertinoApp(
    home: Directionality(
      textDirection: dir,
      child: Center(child: SizedBox(width: 300, height: 60, child: child)),
    ),
  ),
);

void main() {
  testWidgets('swiping toward the leading side shows the button, tapping it runs the action', (
    tester,
  ) async {
    var runs = 0;
    var rowTaps = 0;
    await tester.pumpWidget(
      host(
        SwipeAction(
          label: 'Delete',
          onAction: () async => runs++,
          child: GestureDetector(
            onTap: () => rowTaps++,
            child: const SizedBox(width: 300, height: 60, child: Text('Row')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Row'));
    expect(rowTaps, 1); // closed: the row is tappable as before

    await tester.drag(find.text('Row'), const Offset(-120, 0)); // right to left
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    final openX = tester.getTopLeft(find.text('Row')).dx;
    await tester.tap(find.text('Row'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(rowTaps, 1, reason: 'a tap on an open row only closes it');
    expect(
      tester.getTopLeft(find.text('Row')).dx,
      greaterThan(openX + 80),
      reason: 'and the row slides back',
    );

    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(runs, 1);
  });

  testWidgets('in Arabic (right to left) the swipe goes the other way', (
    tester,
  ) async {
    var runs = 0;
    await tester.pumpWidget(
      host(
        SwipeAction(
          label: 'حذف',
          onAction: () async => runs++,
          child: const SizedBox(width: 300, height: 60, child: Text('Row')),
        ),
        dir: TextDirection.rtl,
      ),
    );
    await tester.drag(find.text('Row'), const Offset(120, 0)); // left to right
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(runs, 1);
  });

  testWidgets('a short drag snaps back and never runs the action', (tester) async {
    var runs = 0;
    await tester.pumpWidget(
      host(
        SwipeAction(
          label: 'Delete',
          onAction: () async => runs++,
          child: const SizedBox(width: 300, height: 60, child: Text('Row')),
        ),
      ),
    );
    await tester.drag(find.text('Row'), const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(runs, 0);
    expect(tester.getTopLeft(find.text('Row')).dx, closeTo(250, 1)); // back where it started
  });
}
