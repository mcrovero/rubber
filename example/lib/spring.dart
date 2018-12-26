import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class SpringPage extends StatefulWidget {
  SpringPage({Key key}) : super(key: key);

  @override
  _SpringPageState createState() => _SpringPageState();
}

class _SpringPageState extends State<SpringPage> with SingleTickerProviderStateMixin {

  RubberAnimationController _controller;

  double _dampingValue = DampingRatio.HIGH_BOUNCY;
  double _stiffnessValue = Stiffness.HIGH;

  @override
  void initState() {
    _controller = RubberAnimationController(
        vsync: this,
        lowerBoundValue: AnimationControllerValue(pixel: 100),
        upperBoundValue: AnimationControllerValue(percentage: 0.9),
        springDescription: SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: _stiffnessValue,
            ratio: _dampingValue
        ),
        duration: Duration(milliseconds: 300)
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Spring",style: TextStyle(color: Colors.cyan[900]),),
      ),
      body: Column(
        children: <Widget>[
          Text("Daming ratio",style: _heading()),
          new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new Radio(
                value: DampingRatio.HIGH_BOUNCY,
                groupValue: _dampingValue,
                onChanged: _handleDampingValueChange,
              ),
              new Text('High'),
              new Radio(
                value: DampingRatio.MEDIUM_BOUNCY,
                groupValue: _dampingValue,
                onChanged: _handleDampingValueChange,
              ),
              new Text('Medium'),
              new Radio(
                value: DampingRatio.LOW_BOUNCY,
                groupValue: _dampingValue,
                onChanged: _handleDampingValueChange,
              ),
              new Text('Low'),
              new Radio(
                value: DampingRatio.NO_BOUNCY,
                groupValue: _dampingValue,
                onChanged: _handleDampingValueChange,
              ),
              new Text('No'),
            ],
          ),
          Text("Stiffness",style: _heading(),),
          new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new Radio(
                value: Stiffness.HIGH,
                groupValue: _stiffnessValue,
                onChanged: _handleStiffnessValueChange,
              ),
              new Text('High'),
              new Radio(
                value: Stiffness.MEDIUM,
                groupValue: _stiffnessValue,
                onChanged: _handleStiffnessValueChange,
              ),
              new Text('Medium'),
              new Radio(
                value: Stiffness.LOW,
                groupValue: _stiffnessValue,
                onChanged: _handleStiffnessValueChange,
              ),
              new Text('Low'),
              new Radio(
                value: Stiffness.VERY_LOW,
                groupValue: _stiffnessValue,
                onChanged: _handleStiffnessValueChange,
              ),
              new Text('Very low'),
            ],
          ),
          Expanded(
            child: RubberBottomSheet(
              lowerLayer: _getLowerLayer(),
              upperLayer: _getUpperLayer(),
              animationController: _controller,
            ),
          ),
        ],
      ),
    );
  }

  void _handleStiffnessValueChange(double value) {
    _stiffnessValue = value;
    setState(() {
      _setController();
    });
  }

  void _handleDampingValueChange(double value) {
    _dampingValue = value;
    setState(() {
      _setController();
    });
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


  void _setController() {
    _controller.springDescription = SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: _stiffnessValue,
        ratio: _dampingValue
    );
  }

  TextStyle _heading() {
    return TextStyle(fontSize: 20.0,fontWeight: FontWeight.bold);
  }
}
