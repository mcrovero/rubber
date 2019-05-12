import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class MenuPage extends StatefulWidget {
  MenuPage({Key key}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with SingleTickerProviderStateMixin {

  RubberAnimationController _controller;

  @override
  void initState() {
    _controller = RubberAnimationController(
        vsync: this,
        dismissable: true,
        lowerBoundValue: AnimationControllerValue(pixel: 100),
        upperBoundValue: AnimationControllerValue(pixel: 400),
        duration: Duration(milliseconds: 200)
    );
    super.initState();
  }

  void _expand() {
    print("expand");
    _controller.launchTo(_controller.value,_controller.upperBound,velocity: 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu",style: TextStyle(color: Colors.cyan[900]),),
      ),
      body: Container(
        child: RubberBottomSheet(
          lowerLayer: _getLowerLayer(),
          upperLayer: _getUpperLayer(),
          menuLayer: _getMenuLayer(),
          animationController: _controller,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "flt3",
        onPressed: _expand,
        backgroundColor: Colors.cyan[900],
        foregroundColor: Colors.cyan[400],
        child: Icon(Icons.vertical_align_top),
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
  Widget _getMenuLayer() {
    return Container(
      height: 100,
      child: Center(
        child: Text("MENU"),
      ),
      decoration: BoxDecoration(
        color: Colors.red
      ),
    );
  }

}
