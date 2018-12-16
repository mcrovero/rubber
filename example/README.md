# Rubber example
Firstly add the *SingleTickerProviderStateMixin* to the State containing the bottomsheet.
```dart
class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
    ...
```
Then create the RubberAnimationController object that controls the bottomsheet animation.
```dart
@override
  void initState() {
    _controller = RubberAnimationController(
        vsync: this, // Thanks to the mixin
        lowerBound: 0.15, // Percentage at which the bottomsheet is collapsed
        halfBound: 0.5, // Percentage when half expanded
        upperBound: 0.9, // Percentage when expanded
        duration: Duration(milliseconds: 200) // Duration of animations
    );
    _controller.addStatusListener(_statusListener);

    super.initState();
  }
```
Then we can add the bottomsheet to our layout as a classic widget.
```dart
RubberBottomSheet(
    lowerLayer: _getLowerLayer(), // The underlying page
    upperLayer: _getUpperLayer(), // The bottomsheet content
    animationController: _controller, // The one we created earlier
)
```
