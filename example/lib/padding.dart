import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';

class AnimationPaddingPage extends StatefulWidget {
  AnimationPaddingPage({Key? key}) : super(key: key);

  @override
  _AnimationPaddingPageState createState() => _AnimationPaddingPageState();
}

class _AnimationPaddingPageState extends State<AnimationPaddingPage>
    with SingleTickerProviderStateMixin {
  late RubberAnimationController _controller;

  static final contain = AnimationPadding.contain();
  static final fivePercent =
      AnimationPadding.fromPercentages(bottom: 0.05, top: 0.05);
  static final minus50px = AnimationPadding.fromPixels(top: -50);
  static final bottomOnly = AnimationPadding.bottomOnly();

  AnimationPadding _padding = contain;

  @override
  void initState() {
    _controller = RubberAnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
      padding: _padding,
    );
    super.initState();
  }

  Row option(AnimationPadding padding, String text) =>
      Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        SizedBox(width: 32),
        Radio(
          value: padding,
          groupValue: _padding,
          onChanged: _handleAnimationPaddingChange,
        ),
        Text(text),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Animation Padding",
          style: TextStyle(color: Colors.cyan[900]),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                "In this example we see the behavior of a few AnimationPadding options."
                "The other configurations are the same – the sheet will come to rest at "
                "10% bounds from the top and bottom of the cyan container."),
          ),
          option(contain,
              "AnimationPadding.contain():\nbounce to edge of containing widget."),
          option(fivePercent,
              ".fromPercentages(bottom: 0.05, top: 0.05):\nbounce to within 5% padding\nof containing widget."),
          option(
            minus50px,
            ".fromPixels(top: -50): bounce out of\nthe containing widget by 50px at the top",
          ),
          option(
            bottomOnly,
            "AnimationPadding.bottomOny()\nbounce beyond top of containing widget\ninfinitely (old default)",
          ),
          Expanded(
            child: RubberBottomSheet(
              lowerLayer: _getLowerLayer(),
              upperLayer: _getUpperLayer(),
              animationController: _controller,
              header: Container(
                color: Colors.yellow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAnimationPaddingChange(AnimationPadding? padding) {
    if (padding == null) return;
    _padding = padding;
    setState(() {
      _controller.padding = _padding;
    });
  }

  Widget _getLowerLayer() {
    return Container(
      decoration: BoxDecoration(color: Colors.cyan[100]),
    );
  }

  Widget _getUpperLayer() {
    return Container(
      decoration: BoxDecoration(color: Colors.cyan),
    );
  }
}
