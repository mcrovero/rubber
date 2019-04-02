import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class DefaultPage extends StatefulWidget {
  DefaultPage({Key key}) : super(key: key);

  @override
  _DefaultPageState createState() => _DefaultPageState();
}

class _DefaultPageState extends State<DefaultPage> with SingleTickerProviderStateMixin {

  RubberAnimationController _controller;

  @override
  void initState() {
    _controller = RubberAnimationController(
        vsync: this,
        halfBoundValue: AnimationControllerValue(percentage: 0.5),
        lowerBoundValue: AnimationControllerValue(pixel: 200),
        duration: Duration(milliseconds: 200)
    );
    _controller.addStatusListener(_statusListener);
    _controller.animationState.addListener(_stateListener);
    super.initState();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_statusListener);
    _controller.animationState.removeListener(_stateListener);
    super.dispose();
  }

  void _stateListener() {
    print("state changed ${_controller.animationState.value}");
  }

  void _statusListener(AnimationStatus status) {
    print("changed status ${_controller.status}");
  }

  void _expand() {
    _controller.expand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Default",style: TextStyle(color: Colors.cyan[900]),),
      ),
      body: Container(
        child: RubberBottomSheet(
          lowerLayer: _getLowerLayer(),
          upperLayer: _getUpperLayer(),
          animationController: _controller,
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton(
            heroTag: "flt1",
            onPressed: () {
              _controller.setVisibility(!_controller.visibility.value);
            },
            backgroundColor: Colors.cyan[900],
            foregroundColor: Colors.cyan[400],
            child: Icon(Icons.visibility),
          ),
          Container(
            margin: EdgeInsets.only(top: 20.0),
            child: FloatingActionButton(
              heroTag: "flt2",
              onPressed: _expand,
              backgroundColor: Colors.cyan[900],
              foregroundColor: Colors.cyan[400],
              child: Icon(Icons.vertical_align_top),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getLowerLayer() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.cyan[100]
      ),
    );
  }
  Widget _getUpperLayer() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.cyan
      ),
    );
  }
}
