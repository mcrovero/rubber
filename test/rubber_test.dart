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

  testWidgets('status listeners report forward, reverse, and bounds', (
    tester,
  ) async {
    late RubberAnimationController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(onControllerCreated: (value) => controller = value),
        ),
      ),
    );
    await tester.pump();

    final statuses = <AnimationStatus>[];
    controller.addStatusListener(statuses.add);
    expect(controller.status, AnimationStatus.dismissed);

    controller.expand();
    expect(controller.status, AnimationStatus.forward);
    await tester.pumpAndSettle();
    expect(controller.status, AnimationStatus.completed);

    controller.collapse();
    expect(controller.status, AnimationStatus.reverse);
    await tester.pumpAndSettle();
    expect(controller.status, AnimationStatus.dismissed);
    expect(
      statuses,
      containsAllInOrder(<AnimationStatus>[
        AnimationStatus.forward,
        AnimationStatus.completed,
        AnimationStatus.reverse,
        AnimationStatus.dismissed,
      ]),
    );
  });

  testWidgets('launchTo clamps targets to the configured bounds', (
    tester,
  ) async {
    final controller = RubberAnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);

    controller.launchTo(controller.value, 2);
    await tester.pumpAndSettle();

    expect(controller.value, closeTo(controller.upperBound!, 0.0001));
    expect(controller.status, AnimationStatus.completed);
  });

  test('strict bounds prevent upper overscroll', () {
    final elastic = RubberAnimationController(vsync: const TestVSync());
    final strict = RubberAnimationController(
      vsync: const TestVSync(),
      boundsBehavior: RubberAnimationBoundsBehavior.strict,
    );
    addTearDown(elastic.dispose);
    addTearDown(strict.dispose);

    elastic.value = 0.95;
    strict.value = 0.95;

    expect(elastic.value, 0.95);
    expect(strict.value, strict.upperBound);
  });

  testWidgets('pixel bounds are recalculated when the layout height changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late RubberAnimationController controller;
    final key = GlobalKey<_ResizableSheetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ResizableSheet(
            key: key,
            onControllerCreated: (value) => controller = value,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.lowerBound, closeTo(0.25, 0.0001));
    expect(controller.value, closeTo(0.25, 0.0001));

    key.currentState!.setHeight(400);
    await tester.pump();
    await tester.pump();

    expect(controller.lowerBound, closeTo(0.5, 0.0001));
    expect(controller.value, closeTo(0.5, 0.0001));
  });

  testWidgets('upper layer fills the sheet below the header', (tester) async {
    const upperKey = ValueKey('upper-layer');
    late RubberAnimationController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            initialValue: 0.9,
            header: const ColoredBox(color: Colors.yellow),
            headerHeight: 50,
            upperLayer: const ColoredBox(key: upperKey, color: Colors.cyan),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.value, 0.9);
    expect(tester.getSize(find.byKey(upperKey)).height, closeTo(490, 0.1));
  });

  testWidgets('scrim fades with the sheet and handles optional taps', (
    tester,
  ) async {
    var taps = 0;
    late RubberAnimationController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            scrimColor: Colors.black54,
            onScrimTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    controller.expand();
    await tester.pumpAndSettle();
    final scrim = find.byKey(const ValueKey('rubber_bottom_sheet_scrim'));
    final coloredBox = tester.widget<ColoredBox>(
      find.descendant(of: scrim, matching: find.byType(ColoredBox)),
    );
    expect(coloredBox.color.a, closeTo(Colors.black54.a, 0.001));

    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
  });

  testWidgets('draggable false leaves the controller unchanged', (
    tester,
  ) async {
    late RubberAnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            draggable: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(const Offset(400, 570), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(controller.value, closeTo(controller.lowerBound!, 0.0001));
  });

  testWidgets('custom snap threshold controls the slow-drag destination', (
    tester,
  ) async {
    late RubberAnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            initialValue: 0.65,
            snapThreshold: 0.75,
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(400, 500));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.value, closeTo(controller.lowerBound!, 0.0001));
  });

  testWidgets('first downward scroll delta moves an expanded sheet', (
    tester,
  ) async {
    late RubberAnimationController controller;
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            initialValue: 0.9,
            scrollController: scrollController,
            upperLayer: ListView.builder(
              controller: scrollController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 20,
              itemBuilder: (context, index) => Text('Item $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(400, 500));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();

    expect(controller.value, lessThan(controller.upperBound!));
    await gesture.cancel();
  });

  testWidgets('scrolling can begin while a fast expansion is settling', (
    tester,
  ) async {
    late RubberAnimationController controller;
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSheet(
            onControllerCreated: (value) => controller = value,
            scrollController: scrollController,
            upperLayer: ListView.builder(
              controller: scrollController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 20,
              itemBuilder: (context, index) =>
                  SizedBox(height: 80, child: Text('Item $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.isAnimating, isTrue);

    final gesture = await tester.startGesture(const Offset(400, 500));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(controller.value, controller.upperBound);
    expect(scrollController.offset, greaterThan(0));
    await gesture.cancel();
  });
}

class _TestSheet extends StatefulWidget {
  const _TestSheet({
    required this.onControllerCreated,
    this.initialValue,
    this.draggable = true,
    this.snapThreshold = 0.5,
    this.scrimColor,
    this.onScrimTap,
    this.scrollController,
    this.header,
    this.headerHeight = 50,
    this.upperLayer = const ColoredBox(color: Colors.cyan),
  });

  final ValueChanged<RubberAnimationController> onControllerCreated;
  final double? initialValue;
  final bool draggable;
  final double snapThreshold;
  final Color? scrimColor;
  final VoidCallback? onScrimTap;
  final ScrollController? scrollController;
  final Widget? header;
  final double headerHeight;
  final Widget upperLayer;

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
      initialValue: widget.initialValue,
    );
    widget.onControllerCreated(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return RubberBottomSheet(
      animationController: _controller,
      lowerLayer: const ColoredBox(color: Colors.white),
      upperLayer: widget.upperLayer,
      draggable: widget.draggable,
      snapThreshold: widget.snapThreshold,
      scrimColor: widget.scrimColor,
      onScrimTap: widget.onScrimTap,
      scrollController: widget.scrollController,
      header: widget.header,
      headerHeight: widget.headerHeight,
    );
  }
}

class _ResizableSheet extends StatefulWidget {
  const _ResizableSheet({super.key, required this.onControllerCreated});

  final ValueChanged<RubberAnimationController> onControllerCreated;

  @override
  State<_ResizableSheet> createState() => _ResizableSheetState();
}

class _ResizableSheetState extends State<_ResizableSheet>
    with SingleTickerProviderStateMixin {
  late final RubberAnimationController _controller;
  double height = 800;

  @override
  void initState() {
    super.initState();
    _controller = RubberAnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBoundValue: AnimationControllerValue(pixel: 200),
    );
    widget.onControllerCreated(_controller);
  }

  void setHeight(double value) {
    setState(() => height = value);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        child: RubberBottomSheet(
          animationController: _controller,
          lowerLayer: const ColoredBox(color: Colors.white),
          upperLayer: const ColoredBox(color: Colors.cyan),
        ),
      ),
    );
  }
}
