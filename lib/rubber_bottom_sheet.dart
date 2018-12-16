import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rubber/rubber_animation_controller.dart';

enum BSState {
  expanded,
  half_expanded,
  collapsed,
}

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 6000.0;
const double _kExpandProgressThreshold = 0.75;
const double _kHalfExpandProgressThreshold = 0.5;
const double _kCollapseProgressThreshold = 0.25;


class RubberBottomSheet extends StatefulWidget {

  const RubberBottomSheet({Key key,
    @required this.stateController,
    @required this.lowerLayer,
    @required this.upperLayer})
      : assert(stateController != null),
        super(key: key);

  final Widget lowerLayer;
  final Widget upperLayer;
  final RubberAnimationController stateController;

  @override
  _RubberBottomSheetState createState() => _RubberBottomSheetState();

}

class _RubberBottomSheetState extends State<RubberBottomSheet> with TickerProviderStateMixin {

  //final GlobalKey _ujibooBottomSheetKey = GlobalKey(debugLabel: 'Ujiboo bottom sheet');

  BSState currentState = BSState.half_expanded;
  RubberAnimationController get _controller => widget.stateController;

  ValueNotifier<bool> display = ValueNotifier(true);

  @override
  void initState() {
    //widget.display.addListener(_onDisplayChanged);
    super.initState();
  }

  void _onDisplayChanged() {
    print("display changed");
    setState(() {
      //
    });
  }


  @override
  void dispose() {
    //widget.display.removeListener(_onDisplayChanged);
    _controller.dispose();
    super.dispose();
  }

  void expand() {
    if (currentState != BSState.expanded) {
      _controller.expand();
    }
  }
  void collapse() {
    if (currentState != BSState.collapsed) {
      _controller.collapse();
    }
  }
  void half() {
    if(currentState != BSState.half_expanded) {
      _controller.halfExpand();
    }
  }

  Widget _buildSlideAnimation(BuildContext context, Widget child) {
    return Container(
        alignment: AlignmentDirectional.topStart,
        height: 100 + _controller.value * (screenHeight - 250),
        child: child
    );
  }

  double screenHeight;
  @override
  Widget build(BuildContext context) {
    var elem;
    if(display.value) {
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
    if(_controller.value > 1 || _controller.value < 0) {
      var diff;
      if(_controller.value < 0) {
        diff = -_controller.value;
      } else {
        diff = _controller.value - 1;
      }
      var friction =  0.52 * pow(1 - diff, 2);
      _controller.value -= details.primaryDelta / screenHeight * friction;
    } else {
      _controller.value -= details.primaryDelta / screenHeight;
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double flingVelocity = -details.velocity.pixelsPerSecond.dy / screenHeight;
    print("${details.velocity.pixelsPerSecond.dy.abs()} $flingVelocity");
    if(details.velocity.pixelsPerSecond.dy.abs() > _kCompleteFlingVelocity) {
      _controller.fling(_controller.lowerBound,_controller.upperBound,velocity: flingVelocity);
    }
    else if (details.velocity.pixelsPerSecond.dy.abs() > _kMinFlingVelocity) {
      if(_controller.value > _kHalfExpandProgressThreshold) {
        _controller.fling(_controller.halfBound,_controller.upperBound,velocity: flingVelocity);
      } else {
        _controller.fling(_controller.lowerBound,_controller.halfBound,velocity: flingVelocity);
      }
    } else {
      if (_controller.value > _kExpandProgressThreshold) {
        _controller.expand();
      }
      else if (_controller.value > _kCollapseProgressThreshold) {
        _controller.halfExpand();
      } else {
        _controller.collapse();
      }
    }
  }

}

class RubberBottomSheetScope extends InheritedWidget {
  final ValueNotifier<bool> display;

  RubberBottomSheetScope({
    Key key,
    @required this.display,
    @required Widget child,
  }) : super(key: key, child: child);


  static RubberBottomSheetScope of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(RubberBottomSheetScope);
  }

  @override
  bool updateShouldNotify(RubberBottomSheetScope old) => display != old.display;
}
