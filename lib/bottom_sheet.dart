import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rubber/animation_controller.dart';

enum BSState {
  expanded,
  half_expanded,
  collapsed,
}

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 5000.0;

class RubberBottomSheet extends StatefulWidget {

  const RubberBottomSheet({Key key,
    this.animationController,
    @required this.lowerLayer,
    @required this.upperLayer,
    this.lowerBound = 0.2,
    this.halfBound,
    this.upperBound = 0.9})
      : assert(animationController != null),
        super(key: key);

  final Widget lowerLayer;
  final Widget upperLayer;
  final double lowerBound;
  final double halfBound;
  final double upperBound;
  final RubberAnimationController animationController;

  @override
  _RubberBottomSheetState createState() => _RubberBottomSheetState();

}

class _RubberBottomSheetState extends State<RubberBottomSheet> with TickerProviderStateMixin {

  ValueNotifier<BSState> currentState = ValueNotifier(BSState.half_expanded);

  RubberAnimationController _defaultController;
  RubberAnimationController get _controller => widget.animationController != null ? widget.animationController : _defaultController;

  ValueNotifier<bool> display = ValueNotifier(true);

  bool get halfState => widget.halfBound != null;

  @override
  void initState() {
    _defaultController = RubberAnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
      value: 1.0,
    );
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void expand() {
    if (currentState.value != BSState.expanded) {
      _controller.expand();
    }
  }

  void collapse() {
    if (currentState.value != BSState.collapsed) {
      _controller.collapse();
    }
  }

  void half() {
    if (currentState.value != BSState.half_expanded) {
      _controller.halfExpand();
    }
  }

  Widget _buildSlideAnimation(BuildContext context, Widget child) {
    return Container(
        alignment: AlignmentDirectional.topStart,
        height: _controller.value * screenHeight, // ToDo: change with child height to support boxed bottomsheets
        child: child
    );
  }

  double screenHeight;

  @override
  Widget build(BuildContext context) {
    var elem;
    if (display.value) {
      final Size screenSize = MediaQuery
          .of(context)
          .size;
      screenHeight = screenSize.height;
      var bottomSheet = GestureDetector(
        child: widget.upperLayer,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
      );
      elem = AnimatedBuilder(
        animation: _controller,
        builder: _buildSlideAnimation,
        child: bottomSheet,
      );
    } else {
      elem = Container();
    }
    return RubberBottomSheetScope(
        display: display,
        state: currentState,
        child: Stack(
          children: <Widget>[
            widget.lowerLayer,
            Align(child: elem, alignment: Alignment.bottomRight)
          ],
        )
    );
  }


  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_controller.value > 1 || _controller.value < 0) {
      var diff;
      if (_controller.value < 0) {
        diff = -_controller.value;
      } else {
        diff = _controller.value - 1;
      }
      var friction = 0.52 * pow(1 - diff, 2);
      _controller.value -= details.primaryDelta / screenHeight * friction;
    } else {
      _controller.value -= details.primaryDelta / screenHeight;
    }
  }


  void _onVerticalDragEnd(DragEndDetails details) {
    final double flingVelocity = -details.velocity.pixelsPerSecond.dy /
        screenHeight;
    print("${details.velocity.pixelsPerSecond.dy.abs()} $flingVelocity");

    if (details.velocity.pixelsPerSecond.dy.abs() > _kCompleteFlingVelocity) {
      _controller.fling(_controller.lowerBound, _controller.upperBound,
          velocity: flingVelocity);
    } else {
      if (halfState) {
        if (details.velocity.pixelsPerSecond.dy.abs() > _kMinFlingVelocity) {
          if (_controller.value > widget.halfBound) {
            _controller.fling(_controller.halfBound, _controller.upperBound,
                velocity: flingVelocity);
          } else {
            _controller.fling(_controller.lowerBound, _controller.halfBound,
                velocity: flingVelocity);
          }
        } else {
          if (_controller.value > (widget.upperBound - widget.halfBound) / 2) {
            _controller.expand();
          }
          else
          if (_controller.value > (widget.halfBound - widget.lowerBound) / 2) {
            _controller.halfExpand();
          } else {
            _controller.collapse();
          }
        }
      } else {
        if (details.velocity.pixelsPerSecond.dy.abs() > _kMinFlingVelocity) {
          _controller.fling(_controller.lowerBound, _controller.upperBound,
              velocity: flingVelocity);
        } else {
          if (_controller.value > (widget.upperBound - widget.lowerBound) / 2) {
            _controller.expand();
          } else {
            _controller.collapse();
          }
        }
      }
    }
  }

}

class RubberBottomSheetScope extends InheritedWidget {
  final ValueNotifier<bool> display;
  final ValueNotifier<BSState> state;

  RubberBottomSheetScope({
    Key key,
    @required this.display,
    @required this.state,
    @required Widget child,
  }) : super(key: key, child: child);


  static RubberBottomSheetScope of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(RubberBottomSheetScope);
  }

  @override
  bool updateShouldNotify(RubberBottomSheetScope old) => display != old.display;
}
