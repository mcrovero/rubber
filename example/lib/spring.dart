import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class SpringPage extends StatefulWidget {
  const SpringPage({super.key});

  @override
  State<SpringPage> createState() => _SpringPageState();
}

class _SpringPageState extends State<SpringPage>
    with SingleTickerProviderStateMixin {
  late RubberAnimationController _controller;

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
        ratio: _dampingValue,
      ),
      duration: Duration(milliseconds: 300),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Spring", style: TextStyle(color: Colors.cyan[900])),
      ),
      body: Column(
        children: <Widget>[
          Text("Daming ratio", style: _heading()),
          RadioGroup<double>(
            groupValue: _dampingValue,
            onChanged: _handleDampingValueChange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Radio<double>(value: DampingRatio.HIGH_BOUNCY),
                Text('High'),
                Radio<double>(value: DampingRatio.MEDIUM_BOUNCY),
                Text('Medium'),
                Radio<double>(value: DampingRatio.LOW_BOUNCY),
                Text('Low'),
                Radio<double>(value: DampingRatio.NO_BOUNCY),
                Text('No'),
              ],
            ),
          ),
          Text("Stiffness", style: _heading()),
          RadioGroup<double>(
            groupValue: _stiffnessValue,
            onChanged: _handleStiffnessValueChange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Radio<double>(value: Stiffness.HIGH),
                Text('High'),
                Radio<double>(value: Stiffness.MEDIUM),
                Text('Medium'),
                Radio<double>(value: Stiffness.LOW),
                Text('Low'),
                Radio<double>(value: Stiffness.VERY_LOW),
                Text('Very low'),
              ],
            ),
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

  void _handleStiffnessValueChange(double? value) {
    if (value == null) return;
    _stiffnessValue = value;
    setState(() {
      _setController();
    });
  }

  void _handleDampingValueChange(double? value) {
    if (value == null) return;
    _dampingValue = value;
    setState(() {
      _setController();
    });
  }

  Widget _getLowerLayer() {
    return Container(decoration: BoxDecoration(color: Colors.cyan[100]));
  }

  Widget _getUpperLayer() {
    return Container(decoration: BoxDecoration(color: Colors.cyan));
  }

  void _setController() {
    _controller.springDescription = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: _stiffnessValue,
      ratio: _dampingValue,
    );
  }

  TextStyle _heading() {
    return TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold);
  }
}
