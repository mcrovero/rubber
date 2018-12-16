import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rubber/animation_controller.dart';

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 5000.0;

class RubberBottomSheet extends StatefulWidget {

  const RubberBottomSheet({Key key,
    @required this.animationController,
    @required this.lowerLayer,
    @required this.upperLayer})
      : assert(animationController!=null),
        super(key: key);

  final Widget lowerLayer;
  final Widget upperLayer;
  final RubberAnimationController animationController;

  @override
  _RubberBottomSheetState createState() => _RubberBottomSheetState();

}

class _RubberBottomSheetState extends State<RubberBottomSheet> with TickerProviderStateMixin {

  RubberAnimationController get _controller => widget.animationController;

  ValueNotifier<bool> display = ValueNotifier(true);
  bool get halfState => _controller.halfBound != null;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      final Size screenSize = MediaQuery.of(context).size;
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
      animationController: _controller,
      display: display,
      child: Stack(
        children: <Widget>[
          widget.lowerLayer,
          Align(child: elem, alignment: Alignment.bottomRight)
        ],
      )
    );
  }


  void _onVerticalDragUpdate(DragUpdateDetails details) {
    var friction = 1.0;
    var diff;
    if(_controller.value > _controller.upperBound) {
      diff = _controller.value - _controller.upperBound;
    }
    else if(_controller.value < _controller.lowerBound) {
      diff =  _controller.lowerBound -_controller.value;
    }
    if(diff != null) {
      friction = 0.52 * pow(1 - diff, 2);
    }

    _controller.value -= details.primaryDelta / screenHeight * friction;

  }


  void _onVerticalDragEnd(DragEndDetails details) {
    final double flingVelocity = -details.velocity.pixelsPerSecond.dy /
        screenHeight;

    if (details.velocity.pixelsPerSecond.dy.abs() > _kCompleteFlingVelocity) {
      _controller.fling(_controller.lowerBound, _controller.upperBound,
          velocity: flingVelocity);
    } else {
      if (halfState) {
        if (details.velocity.pixelsPerSecond.dy.abs() > _kMinFlingVelocity) {
          if (_controller.value > _controller.halfBound) {
            _controller.fling(_controller.halfBound, _controller.upperBound,
                velocity: flingVelocity);
          } else {
            _controller.fling(_controller.lowerBound, _controller.halfBound,
                velocity: flingVelocity);
          }
        } else {
          if (_controller.value > (_controller.upperBound - _controller.halfBound) / 2) {
            _controller.expand();
          }
          else
          if (_controller.value > (_controller.halfBound - _controller.lowerBound) / 2) {
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
          if (_controller.value > (_controller.upperBound - _controller.lowerBound) / 2) {
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
  final RubberAnimationController animationController;

  RubberBottomSheetScope({
    Key key,
    @required this.display,
    @required this.animationController,
    @required Widget child,
  }) : super(key: key, child: child);


  static RubberBottomSheetScope of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(RubberBottomSheetScope);
  }

  @override
  bool updateShouldNotify(RubberBottomSheetScope old) => display != old.display;
}
