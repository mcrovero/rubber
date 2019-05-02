import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class ScrollPage extends StatefulWidget {

  ScrollPage({Key key}) : super(key: key);

  @override
  _ScrollPageState createState() => _ScrollPageState();

}

class _ScrollPageState extends State<ScrollPage> with SingleTickerProviderStateMixin {

  RubberAnimationController _controller;

  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    _controller = RubberAnimationController(
        vsync: this,
        halfBoundValue: AnimationControllerValue(percentage: 0.5),
        duration: Duration(milliseconds: 200)
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scrolling",style: TextStyle(color: Colors.cyan[900]),),
      ),
      body: Container(
        child: RubberBottomSheet(
          scrollController: _scrollController,
          lowerLayer: _getLowerLayer(),
          header: Container(
            color: Colors.yellow,
          ),
          headerHeight: 60,
          upperLayer: _getUpperLayer(),
          animationController: _controller,
        ),
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
      child: ListView.builder(
        physics: NeverScrollableScrollPhysics(),
        controller: _scrollController,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(title: Text("Item $index"));
        },
        itemCount: 100
      ),
    );
  }

}
