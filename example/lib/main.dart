import 'package:flutter/material.dart';

import 'package:rubber/animation_controller.dart';
import 'package:rubber/bottom_sheet.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
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
        duration: Duration(milliseconds: 1000)
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
    _controller.expand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: RubberBottomSheet(
        lowerLayer: _getLowerLayer(),
        upperLayer: _getUpperLayer(),
        animationController: _controller,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _expand,
        tooltip: 'Expand',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget _getLowerLayer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal
      ),
    );
  }
  Widget _getUpperLayer() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.black45
      ),
    );
  }
}
