# Rubber example

First create the RubberAnimationController object that controls the bottomsheet animation.
```dart
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
```

Then we can add the bottomsheet to our layout
```dart
    Container(
        child: RubberBottomSheet(
            lowerLayer: _getLowerLayer(),
            upperLayer: _getUpperLayer(),
            animationController: _controller,
        ),
    ),
```
