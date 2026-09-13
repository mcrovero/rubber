import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubber/src/animation_controller.dart';

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 5000.0;

class RubberBottomSheet extends StatefulWidget {
  const RubberBottomSheet({
    super.key,
    required this.animationController,
    required this.lowerLayer,
    required this.upperLayer,
    this.menuLayer,
    this.scrollController,
    this.header,
    this.headerHeight = 50.0,
    this.dragFriction = 0.52,
    this.draggable = true,
    this.minFlingVelocity = _kMinFlingVelocity,
    this.completeFlingVelocity = _kCompleteFlingVelocity,
    this.snapThreshold = 0.5,
    this.scrimColor,
    this.onScrimTap,
    this.onDragStart,
    this.onDragEnd,
    this.onTap,
  }) : assert(dragFriction >= 0),
       assert(minFlingVelocity >= 0),
       assert(completeFlingVelocity >= minFlingVelocity),
       assert(snapThreshold >= 0 && snapThreshold <= 1);

  final ScrollController? scrollController;
  final Widget lowerLayer;
  final Widget upperLayer;
  final Widget? menuLayer;

  /// Friction to apply when the sheet reaches its bounds.
  /// The higher the number, the more friction is applied.
  /// Defaults to 0.52.
  ///
  /// Warning: If `dragFriction < 0`, your bottom sheet will accelerate off the screen.
  final double dragFriction;
  final Function? onTap;

  /// Whether drag gestures can move the sheet.
  final bool draggable;

  /// Minimum vertical velocity that selects the next snap point.
  final double minFlingVelocity;

  /// Vertical velocity that skips an intermediate snap point.
  final double completeFlingVelocity;

  /// Position within each interval at which a slow drag snaps upward.
  ///
  /// Must be between 0 and 1. The default of 0.5 uses the midpoint.
  final double snapThreshold;

  /// Optional color drawn over [lowerLayer] as the sheet expands.
  ///
  /// The configured alpha is reached at the upper bound.
  final Color? scrimColor;

  /// Called when the optional scrim is tapped.
  ///
  /// When null, pointer events pass through the scrim.
  final VoidCallback? onScrimTap;

  /// Called when the user stops scrolling, if this function returns a false the bottomsheet
  /// won't complete the next onDragEnd instructions
  final Function()? onDragEnd;

  /// Called when the user stops scrolling, if this function returns a false the bottomsheet
  /// won't complete the next onDragEnd instructions
  final Function()? onDragStart;

  /// The widget on top of the rest of the bottom sheet.
  /// Usually used to make a non-scrollable area
  final Widget? header;
  // Parameter to change the header height, it's the only way to set the header height
  final double headerHeight;

  /// Instance of [RubberAnimationController] that controls the bottom sheet
  /// animation state
  final RubberAnimationController animationController;

  static RubberBottomSheetState? of(
    BuildContext context, {
    bool nullOk = false,
  }) {
    final RubberBottomSheetState? result = context
        .findAncestorStateOfType<RubberBottomSheetState>();
    if (nullOk || result != null) return result;
    throw FlutterError(
      'RubberBottomSheet.of() called with a context that does not contain a RubberBottomSheet.\n'
      'No RubberBottomSheet ancestor could be found starting from the context that was passed to RubberBottomSheet.of(). '
      '  $context',
    );
  }

  @override
  RubberBottomSheetState createState() => RubberBottomSheetState();
}

class RubberBottomSheetState extends State<RubberBottomSheet> {
  late double _screenHeight;

  final GlobalKey _keyPeak = GlobalKey();
  double? _reportedHeight;
  bool _heightUpdateScheduled = false;

  RubberAnimationController get controller => widget.animationController;

  bool get halfState => controller.halfBound != null;

  bool get _shouldScroll =>
      _scrollController != null &&
      _scrollController!.hasClients &&
      controller.value >= controller.upperBound!;
  bool _scrolling = false;

  bool get _hasHeader => widget.header != null;

  /// Adding [substituteScrollController] a value the bottomsheet will change the default one
  ScrollController? substituteScrollController;
  ScrollController? get _scrollController =>
      substituteScrollController ?? widget.scrollController;

  /// If set true the drag won't move the bottomsheet but the scrolling will be always active
  bool _forceScrolling = false;
  void forceScroll(bool force) {
    _forceScrolling = force;
    _setScrolling(force);
  }

  void updateScroll(bool scroll) {
    _setScrolling(scroll);
  }

  bool? _enabledOverride;
  bool get _enabled => _enabledOverride ?? widget.draggable;

  /// Enables or disables dragging at runtime.
  ///
  /// Prefer the declarative [RubberBottomSheet.draggable] property when
  /// possible.
  set enable(bool value) {
    _enabledOverride = value;
  }

  @override
  void initState() {
    super.initState();
    controller.visibility.addListener(_visibilityListener);
  }

  @override
  void didUpdateWidget(RubberBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationController != widget.animationController) {
      oldWidget.animationController.visibility.removeListener(
        _visibilityListener,
      );
      controller.visibility.addListener(_visibilityListener);
      _reportedHeight = null;
    }
  }

  @override
  void dispose() {
    controller.visibility.removeListener(_visibilityListener);
    controller.dispose();
    super.dispose();
  }

  bool _display = true;
  void _visibilityListener() {
    if (!mounted) return;
    setState(() {
      _display = controller.visibility.value;
    });
  }

  Widget _buildSlideAnimation(BuildContext context, Widget? child) {
    Widget layout;
    if (widget.menuLayer != null) {
      layout = Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.bottomLeft,
            child: _buildAnimatedBottomsheetWidget(context, child),
          ),
          Align(alignment: Alignment.bottomLeft, child: widget.menuLayer),
        ],
      );
    } else {
      layout = _buildAnimatedBottomsheetWidget(context, child);
    }
    return GestureDetector(
      onTap: widget.onTap as void Function()?,
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragDown: _onVerticalDragDown,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onVerticalDragCancel: _handleDragCancel,
      onVerticalDragStart: _handleDragStart,
      child: layout,
    );
  }

  Widget _buildAnimatedBottomsheetWidget(BuildContext context, Widget? child) {
    return FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: widget.animationController.value,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        _screenHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaHeight;
        _scheduleHeightUpdate(_screenHeight);

        final headerOffset = _hasHeader ? widget.headerHeight : 0.0;
        final bottomSheet = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(top: headerOffset, child: widget.upperLayer),
            if (_hasHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: widget.headerHeight,
                child: SizedBox(key: _keyPeak, child: widget.header),
              ),
          ],
        );
        final sheet = _display
            ? AnimatedBuilder(
                animation: controller,
                builder: _buildSlideAnimation,
                child: bottomSheet,
              )
            : const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.lowerLayer,
            if (_display && widget.scrimColor != null)
              AnimatedBuilder(animation: controller, builder: _buildScrim),
            Align(alignment: Alignment.bottomRight, child: sheet),
          ],
        );
      },
    );
  }

  Widget _buildScrim(BuildContext context, Widget? child) {
    final lower = controller.lowerBound ?? 0;
    final upper = controller.upperBound ?? 1;
    final range = upper - lower;
    final progress = range == 0
        ? 1.0
        : ((controller.value - lower) / range).clamp(0.0, 1.0);
    final color = widget.scrimColor!.withValues(
      alpha: widget.scrimColor!.a * progress,
    );
    return IgnorePointer(
      ignoring: widget.onScrimTap == null || progress == 0,
      child: GestureDetector(
        key: const ValueKey('rubber_bottom_sheet_scrim'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onScrimTap,
        child: ColoredBox(color: color),
      ),
    );
  }

  void _scheduleHeightUpdate(double height) {
    if (height <= 0 || height == _reportedHeight || _heightUpdateScheduled) {
      return;
    }
    _heightUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightUpdateScheduled = false;
      if (!mounted || height == _reportedHeight) return;
      _reportedHeight = height;
      controller.height = height;
    });
  }

  // Touch gestures
  Drag? _drag;
  ScrollHoldController? _hold;

  void _onVerticalDragDown(DragDownDetails details) {
    if (_enabled) {
      final shouldDragSheet =
          _hasHeader && _draggingPeak(details.globalPosition);
      final finishExpansion =
          !shouldDragSheet &&
          _scrollController != null &&
          _scrollController!.hasClients &&
          controller.isAnimating &&
          controller.status == AnimationStatus.forward;
      controller.stop();
      if (finishExpansion) {
        controller.value = controller.upperBound!;
      }
      _setScrolling(!shouldDragSheet && _shouldScroll);
      if (_scrolling) {
        assert(_hold == null);
        if (_scrollController != null && _scrollController!.hasClients) {
          _hold = _scrollController!.position.hold(_disposeHold);
        }
      }
    }
  }

  Offset? _lastPosition;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_enabled) {
      _lastPosition = details.globalPosition;
      if (_scrolling && _shouldScroll) {
        // _drag might be null if the drag activity ended and called _disposeDrag.
        assert(_hold == null || _drag == null);
        _drag?.update(details);
        if (_scrollController!.position.pixels <= 0 &&
            details.primaryDelta! > 0 &&
            !_forceScrolling) {
          _setScrolling(false);
          _handleDragCancel();
          if (_scrollController!.position.pixels != 0.0) {
            _scrollController!.position.setPixels(0.0);
          }
          _updateSheet(details);
        }
      } else {
        _updateSheet(details);
      }
    }
  }

  void _updateSheet(DragUpdateDetails details) {
    var friction = 1.0;
    double? diff;
    if (controller.value > controller.upperBound!) {
      diff = controller.value - controller.upperBound!;
    } else if (controller.value < controller.lowerBound!) {
      diff = controller.lowerBound! - controller.value;
    }
    if (controller.value < controller.upperBound! &&
        controller.dismissable &&
        controller.animationState.value == AnimationState.expanded) {
      diff = controller.upperBound! - controller.value;
    }
    if (diff != null) {
      friction = 1 + (widget.dragFriction * pow(1 - diff, 2));
    }

    controller.value -= details.primaryDelta! / _screenHeight / friction;
    if (_shouldScroll &&
        controller.value >= controller.upperBound! &&
        !_draggingPeak(_lastPosition)) {
      controller.value = controller.upperBound!;
      _setScrolling(true);
      final startDetails = DragStartDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        globalPosition: details.globalPosition,
      );
      _hold = _scrollController!.position.hold(_disposeHold);
      _drag = _scrollController!.position.drag(startDetails, _disposeDrag);
    } else {
      _handleDragCancel();
    }
  }

  void _setScrolling(bool scroll) {
    if (!scroll) {
      _scrolling = false;
    } else if (_shouldScroll) {
      _scrolling = scroll;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (_enabled) {
      if (widget.onDragStart != null) widget.onDragStart!();
      if (_scrolling && _shouldScroll) {
        // It's possible for _hold to become null between _handleDragDown and
        // _handleDragStart, for example if some user code calls jumpTo or otherwise
        // triggers a new activity to begin.
        assert(_drag == null);
        _drag = _scrollController!.position.drag(details, _disposeDrag);
        assert(_drag != null);
        assert(_hold == null);
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_enabled) {
      // If onDragEnd returns a false value the method interrupts
      if (widget.onDragEnd != null) {
        var res = widget.onDragEnd!();
        if (res != null && !res) {
          _handleDragCancel();
          return;
        }
      }

      final double flingVelocity =
          -details.velocity.pixelsPerSecond.dy / _screenHeight;
      if (_scrolling) {
        assert(_hold == null || _drag == null);
        _drag?.end(details);
        assert(_drag == null);
      } else {
        if (details.velocity.pixelsPerSecond.dy.abs() >
            widget.completeFlingVelocity) {
          controller.fling(
            controller.lowerBound,
            controller.upperBound,
            velocity: flingVelocity,
          );
        } else {
          if (halfState) {
            if (details.velocity.pixelsPerSecond.dy.abs() >
                widget.minFlingVelocity) {
              if (controller.value > controller.halfBound!) {
                controller.fling(
                  controller.halfBound,
                  controller.upperBound,
                  velocity: flingVelocity,
                );
              } else {
                controller.fling(
                  controller.lowerBound,
                  controller.halfBound,
                  velocity: flingVelocity,
                );
              }
            } else {
              if (controller.value >
                  _snapPoint(controller.halfBound!, controller.upperBound!)) {
                controller.expand();
              } else if (controller.value >
                  _snapPoint(controller.lowerBound!, controller.halfBound!)) {
                controller.halfExpand();
              } else {
                controller.collapse();
              }
            }
          } else {
            if (details.velocity.pixelsPerSecond.dy.abs() >
                widget.minFlingVelocity) {
              controller.fling(
                controller.lowerBound,
                controller.upperBound,
                velocity: flingVelocity,
              );
            } else {
              if (controller.value >
                  _snapPoint(controller.lowerBound!, controller.upperBound!)) {
                controller.expand();
              } else {
                controller.collapse();
              }
            }
          }
        }
      }
    }
  }

  double _snapPoint(double lower, double upper) {
    return lower + (upper - lower) * widget.snapThreshold;
  }

  void _handleDragCancel() {
    // _hold might be null if the drag started.
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _hold?.cancel();
    _drag?.cancel();
    assert(_hold == null);
    assert(_drag == null);
  }

  void _disposeHold() {
    _hold = null;
  }

  void _disposeDrag() {
    _drag = null;
  }

  bool _draggingPeak(Offset? globalPosition) {
    if (!_hasHeader) return false;
    final RenderBox renderBoxRed =
        _keyPeak.currentContext!.findRenderObject() as RenderBox;
    final positionPeak = renderBoxRed.localToGlobal(Offset.zero);
    final sizePeak = renderBoxRed.size;
    final top = (sizePeak.height + positionPeak.dy);
    return (globalPosition!.dy < top);
  }
}
