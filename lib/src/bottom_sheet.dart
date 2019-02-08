import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubber/src/animation_controller.dart';

import 'package:after_layout/after_layout.dart';

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 5000.0;

class RubberBottomSheet extends StatefulWidget {

  const RubberBottomSheet({Key key,
    @required this.animationController,
    @required this.lowerLayer,
    @required this.upperLayer,
    this.menuLayer,
    this.scrollController, this.header})
      : assert(animationController!=null),
        super(key: key);

  final ScrollController scrollController;
  final Widget lowerLayer;
  final Widget upperLayer;
  final Widget menuLayer;

  /// The widget on top of the rest of the bottom sheet.
  /// Usually used to make a non-scrollable area
  final Widget header;

  /// Instance of [RubberAnimationController] that controls the bottom sheet
  /// animation state
  final RubberAnimationController animationController;

  @override
  _RubberBottomSheetState createState() => _RubberBottomSheetState();

}

class _RubberBottomSheetState extends State<RubberBottomSheet> with TickerProviderStateMixin, AfterLayoutMixin<RubberBottomSheet> {

  double screenHeight;

  final GlobalKey _keyPeak = GlobalKey();
  final GlobalKey _keyWidget = GlobalKey(debugLabel: 'bottomsheet menu key');

  double get _bottomSheetHeight {
    final RenderBox renderBox = _keyWidget.currentContext.findRenderObject();
    return renderBox.size.height;
  }

  RubberAnimationController get _controller => widget.animationController;

  bool get halfState => _controller.halfBound != null;

  bool get _shouldScroll => _scrollController != null;
  bool _scrolling = false;

  ScrollController get _scrollController => widget.scrollController;

  @override
  void initState() {
    super.initState();
    _controller.visibility.addListener(_visibilityListener);
  }

  @override
  void dispose() {
    _controller.visibility.removeListener(_visibilityListener);
    _controller.dispose();
    super.dispose();
  }

  bool _display = true;
  void _visibilityListener() {
    setState((){
      _display = _controller.visibility.value;
    });
  }

  Widget _buildSlideAnimation(BuildContext context, Widget child) {
    var layout;
    if(widget.menuLayer != null) {
      layout = Stack(
        children: <Widget>[
          _buildAnimatedBottomsheetWidget(context,child),
          Align(
            alignment: Alignment.bottomLeft,
            child: widget.menuLayer
          ),
        ],
      );
    } else {
      layout = _buildAnimatedBottomsheetWidget(context,child);
    }
    return GestureDetector(
      onVerticalDragDown: _onVerticalDragDown,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onVerticalDragCancel: _handleDragCancel,
      onVerticalDragStart: _handleDragStart,
      child: layout,
    );
  }
  Widget _buildAnimatedBottomsheetWidget(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: FractionallySizedBox(
        heightFactor: widget.animationController.value >= 0 ? widget.animationController.value : 0,
        child: child
      )
    );
  }


  @override
  Widget build(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;
    screenHeight = screenSize.height;
    var peak = Container(
      key: _keyPeak,
      child: widget.header,
    );
    var bottomSheet = Column(children: <Widget>[peak,Expanded(child: widget.upperLayer)]);
    var elem;
    if(_display) {
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
      child: Stack(
        key: _keyWidget,
        children: <Widget>[
          widget.lowerLayer,
          Align(
            child: elem,
            alignment: Alignment.bottomRight
          ),
        ],
      )
    );
  }

  // Touch gestures
  Drag _drag;
  ScrollHoldController _hold;

  void _onVerticalDragDown(DragDownDetails details) {
    if(_shouldScroll) {
      assert(_drag == null);
      assert(_hold == null);
      _hold = _scrollController.position.hold(_disposeHold);
    }
  }

  Offset _lastPosition;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _lastPosition = details.globalPosition;
    if(_scrolling) {
      // _drag might be null if the drag activity ended and called _disposeDrag.
      assert(_hold == null || _drag == null);
      _drag?.update(details);
      if(_scrollController.position.pixels <= 0 && details.primaryDelta>0) {
        _setScrolling(false);
        _handleDragCancel();
        if(_scrollController.position.pixels != 0.0) {
          _scrollController.position.setPixels(0.0);
        }
      }
    } else {
      var friction = 1.0;
      var diff;
      if (_controller.value > _controller.upperBound) {
        diff = _controller.value - _controller.upperBound;
      }
      else if (_controller.value < _controller.lowerBound) {
        diff = _controller.lowerBound - _controller.value;
      }
      if (diff != null) {
        friction = 0.52 * pow(1 - diff, 2);
      }

      _controller.value -= details.primaryDelta / screenHeight * friction;

      if(_controller.value >= _controller.upperBound && !_draggingPeak(_lastPosition)) {
        _controller.value = _controller.upperBound;
        if(_shouldScroll) {
          _setScrolling(true);
          var startDetails = DragStartDetails(sourceTimeStamp: details.sourceTimeStamp, globalPosition: details.globalPosition);
          _hold = _scrollController.position.hold(_disposeHold);
          _drag = _scrollController.position.drag(startDetails, _disposeDrag);
        }
      } else {
        _handleDragCancel();
      }
    }
  }

  _setScrolling(bool scroll) {
    if(_shouldScroll) {
      _scrolling = scroll;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if(_shouldScroll) {
      // It's possible for _hold to become null between _handleDragDown and
      // _handleDragStart, for example if some user code calls jumpTo or otherwise
      // triggers a new activity to begin.
      assert(_drag == null);
      _drag = _scrollController.position.drag(details, _disposeDrag);
      assert(_drag != null);
      assert(_hold == null);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double flingVelocity = -details.velocity.pixelsPerSecond.dy / screenHeight;
    if(_scrolling) {
      assert(_hold == null || _drag == null);
      _drag?.end(details);
      assert(_drag == null);
    } else {
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
            if (_controller.value >
                (_controller.upperBound + _controller.halfBound) / 2) {
              _controller.expand();
            }
            else if (_controller.value >
                (_controller.halfBound + _controller.lowerBound) / 2) {
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
            if (_controller.value >
                (_controller.upperBound - _controller.lowerBound) / 2) {
              _controller.expand();
            } else {
              _controller.collapse();
            }
          }
        }
      }
    }
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

  @override
  void afterFirstLayout(BuildContext context) {
    _controller.height = _bottomSheetHeight;
  }

  bool _draggingPeak(Offset globalPosition) {
    final RenderBox renderBoxRed = _keyPeak.currentContext.findRenderObject();
    final positionPeak = renderBoxRed.localToGlobal(Offset.zero);
    final sizePeak = renderBoxRed.size;
    final top = (sizePeak.height + positionPeak.dy);
    return (globalPosition.dy < top);
  }
}

class RubberBottomSheetScope extends InheritedWidget {
  final RubberAnimationController animationController;

  RubberBottomSheetScope({
    Key key,
    @required this.animationController,
    @required Widget child,
  }) : super(key: key, child: child);


  static RubberBottomSheetScope of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(RubberBottomSheetScope);
  }

  @override
  bool updateShouldNotify(RubberBottomSheetScope old) => true;
}
