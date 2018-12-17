import 'package:flutter/material.dart';

import 'package:rubber/rubber.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Colors.cyan,
      ),
      home: MyHomePage(title: 'Rubber BottomSheet Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {

  RubberAnimationController _controller;

  @override
  void initState() {
    _controller = RubberAnimationController(
      vsync: this,
      lowerBound: 0.15,
      halfBound: 0.5,
      upperBound: 0.9,
      duration: Duration(milliseconds: 200)
    );
    _controller.addStatusListener(_statusListener);

    super.initState();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_statusListener);
    super.dispose();
  }

  void _statusListener(AnimationStatus status) {
    print("changed State ${_controller.animationState}");
  }

  void _expand() {
    _controller.launchTo(AnimationState.expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,style: TextStyle(color: Colors.cyan[900]),),
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
            onPressed: () {
              _controller.visibility = !_controller.visibility;
            },
            backgroundColor: Colors.cyan[900],
            foregroundColor: Colors.cyan[400],
            child: Icon(Icons.visibility),
          ),
          Container(
            margin: EdgeInsets.only(top: 20.0),
            child: FloatingActionButton(
              onPressed: _expand,
              backgroundColor: Colors.cyan[900],
              foregroundColor: Colors.cyan[400],
              child: Icon(Icons.vertical_align_top),
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
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
