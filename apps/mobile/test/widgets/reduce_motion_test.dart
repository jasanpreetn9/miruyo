import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/features/shell/drag_to_close.dart';
import 'package:miruyo/widgets/motion.dart';

/// Under Reduce Motion (iOS's setting, Flutter's disableAnimations).
Widget reduced(Widget child) => ProviderScope(
  child: MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true, size: Size(400, 800)),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('Reduce Motion: content is there at once, without the fade and lift', (tester) async {
    await tester.pumpWidget(reduced(const Appear(child: Text('Hello'))));
    // the first frame, no settling
    expect(find.descendant(of: find.byType(Appear), matching: find.byType(FadeTransition)), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Reduce Motion: dragging a page down moves it without shrinking it', (tester) async {
    await tester.pumpWidget(
      reduced(
        DragToClose(
          onClose: () {},
          builder: (_, physics) => ListView(
            physics: physics,
            children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('Row $i'))],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    final scales = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getMaxScaleOnAxis())
        .toList();
    expect(scales.every((s) => s == 1), isTrue);
    expect(tester.getTopLeft(find.text('Row 0')).dy, greaterThan(40));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
