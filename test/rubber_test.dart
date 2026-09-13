import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubber/rubber.dart';

void main() {
  test('animation padding clamps values to its configured range', () {
    final padding = AnimationPadding.fromPercentages(bottom: 0.1, top: 0.2);

    expect(padding.apply(-1), 0.1);
    expect(padding.apply(0.5), 0.5);
    expect(padding.apply(2), 0.8);
  });

  testWidgets('bottom sheet renders and expands', (tester) async {
    late RubberAnimationController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(onControllerCreated: (value) => controller = value),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RubberBottomSheet), findsOneWidget);
    expect(controller.value, closeTo(0.1, 0.001));

    controller.expand();
    await tester.pumpAndSettle();

    expect(controller.value, closeTo(0.9, 0.001));
  });
}

class _TestSheet extends StatefulWidget {
  const _TestSheet({required this.onControllerCreated});

  final ValueChanged<RubberAnimationController> onControllerCreated;

  @override
  State<_TestSheet> createState() => _TestSheetState();
}

class _TestSheetState extends State<_TestSheet>
    with SingleTickerProviderStateMixin {
  late final RubberAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RubberAnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    widget.onControllerCreated(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return RubberBottomSheet(
      animationController: _controller,
      lowerLayer: const ColoredBox(color: Colors.white),
      upperLayer: const ColoredBox(color: Colors.cyan),
    );
  }
}
