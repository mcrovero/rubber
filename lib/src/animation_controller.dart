import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:rubber/src/spring_description/damping_ratio.dart';
import 'package:rubber/src/spring_description/stiffness.dart';

export 'package:flutter/scheduler.dart' show TickerFuture, TickerCanceled;

final SpringDescription _kFlingSpringDefaultDescription =
    SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: Stiffness.LOW,
  ratio: DampingRatio.LOW_BOUNCY,
);

const Tolerance _kFlingTolerance = Tolerance(
  velocity: double.infinity,
  distance: 0.00001,
);

enum AnimationState {
  expanded,
  half_expanded,
  collapsed,
  animating,
}

class AnimationControllerValue {
  double? percentage;
  double? pixel;
  AnimationControllerValue({this.percentage, this.pixel});
  @override
  String toString() {
    return "AnimationControllerValue(percentage: $percentage, pixel: $pixel)";
  }
}

/// Pads the animation using value.clamp
///
/// Useful for preventing the sheet from speeding off screen
/// or out of it's parent widget, without compromising too much on bounciness.
///
/// NOTE: the [top] padding value is interpeted as a distance from the top.
/// If you want to specify a range, use the `.fromPercentageRange` constructor
class AnimationPadding {
  static AnimationControllerValue get _zero =>
      AnimationControllerValue(percentage: 0);

  AnimationControllerValue? top;
  AnimationControllerValue bottom;

  AnimationPadding({this.top, required this.bottom});

  AnimationPadding.all(AnimationControllerValue value)
      : top = value,
        bottom = value;

  /// Pad with percent-distances from the top and bottom of the viewport
  ///
  /// i.e. `AnimationPadding.fromPercentages(bottom: 0, top: 0)` or `.contain()` (the default)
  /// only pads by the screen/viewport or containing widget.
  AnimationPadding.fromPercentages({double? top, double bottom = 0})
      : top = AnimationControllerValue(percentage: top),
        bottom = AnimationControllerValue(percentage: bottom);

  /// Contain the animation within the enclosing widget (default)
  ///
  /// Same as `AnimationPadding.fromPercentages(bottom: 0, top: 0)`
  factory AnimationPadding.contain() =>
      AnimationPadding.fromPercentages(top: 0, bottom: 0);

  /// No padding. Allows the bottom sheet to be flung off the top of the screen,
  /// but not the bottom (old default behavior).
  factory AnimationPadding.bottomOnly() =>
      AnimationPadding(top: null, bottom: _zero);

  /// Pad with percent-distances from the bottom of the viewport
  AnimationPadding.fromPercentageRange(double bottom, double top)
      : top = AnimationControllerValue(percentage: 1.0 - top),
        bottom = AnimationControllerValue(percentage: bottom);

  AnimationPadding.fromPixels({double? top, double? bottom})
      : top = top == null ? null : AnimationControllerValue(pixel: top),
        bottom =
            bottom == null ? _zero : AnimationControllerValue(pixel: bottom);

  /// Apply the padding to a controller value
  double apply(double value) {
    return value
        .clamp(
          bottom.percentage ?? 0,
          top?.percentage != null ? 1.0 - top!.percentage! : double.infinity,
        )
        .toDouble();
  }

  @override
  String toString() {
    return "AnimationPadding(top: $top, bottom: $bottom)";
  }
}

class RubberAnimationController extends Animation<double>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  /// Creates an animation controller.
  ///
  /// * [value] is the initial value of the animation. If defaults to the lower
  ///   bound.
  ///
  /// * [duration] is the length of time this animation should last.
  ///
  /// * [debugLabel] is a string to help identify this animation during
  ///   debugging (used by [toString]).
  ///
  /// * [lowerBoundValue] is the smallest value this animation can obtain and the
  ///   value at which this animation is deemed to be dismissed.
  ///   Defaults to 0% if [dismissable] and 10% if not.
  ///
  /// * [halfBoundValue] is the half value this animation can obtain and the
  ///   value at which this animation is deemed to be half expanded. It can be
  ///   null.
  ///
  /// * [dismissable] if set true when the bottomsheet goes at 0 is dismissed
  ///
  /// * [upperBoundValue] is the largest value this animation can obtain and the
  ///   value at which this animation is deemed to be completed. It cannot be
  ///   null.
  ///
  /// * `vsync` is the [TickerProvider] for the current context. It can be
  ///   changed by calling [resync]. It is required and must not be null. See
  ///   [TickerProvider] for advice on obtaining a ticker provider.

  RubberAnimationController({
    AnimationControllerValue? lowerBoundValue,
    this.halfBoundValue,
    AnimationControllerValue? upperBoundValue,
    this.dismissable = false,
    this.initialValue,
    this.duration,
    this.debugLabel,
    this.animationBehavior = AnimationBehavior.normal,
    AnimationPadding? padding,
    SpringDescription? springDescription,
    required TickerProvider vsync,
  })  : assert(!dismissable || (dismissable && halfBoundValue == null),
            "dismissable sheets are imcompatible with halfBoundValue"),
        lowerBoundValue = lowerBoundValue ??
            AnimationControllerValue(percentage: dismissable ? 0.0 : 0.1),
        upperBoundValue =
            upperBoundValue ?? AnimationControllerValue(percentage: 0.9),
        _padding = padding ?? AnimationPadding.contain() {
    if (springDescription != null) _springDescription = springDescription;

    _ticker = vsync.createTicker(_tick);

    if (lowerBound != null) _internalSetValue(initialValue ?? lowerBound!);
  }

  /// The value at which this animation is collapsed.
  late AnimationControllerValue lowerBoundValue;
  double? get lowerBound => lowerBoundValue.percentage;

  /// The value at which this animation is half expanded
  AnimationControllerValue? halfBoundValue;
  double? get halfBound => halfBoundValue?.percentage;

  /// The value at which this animation is expanded.
  late AnimationControllerValue upperBoundValue;
  double? get upperBound => upperBoundValue.percentage;

  late AnimationPadding _padding;

  /// Pads the animation using value.clamp
  ///
  /// Useful for preventing the sheet from speeding off screen
  /// or out of containing widget,
  /// without compromising too much on bounciness
  AnimationPadding get padding => _padding;
  set padding(AnimationPadding p) {
    _padding = p;
    pixelValuesToPercentage();
  }

  /// Tells if the bottomsheet has to remain closed after drag down
  final bool dismissable;

  /// A label that is used in the [toString] output. Intended to aid with
  /// identifying animation controller instances in debug output.
  final String? debugLabel;

  /// The behavior of the controller when [AccessibilityFeatures.disableAnimations]
  /// is true.
  ///
  /// Defaults to [AnimationBehavior.normal] for the [new AnimationController]
  /// constructor, and [AnimationBehavior.preserve] for the
  /// [new AnimationController.unbounded] constructor.
  final AnimationBehavior animationBehavior;

  SpringDescription _springDescription = _kFlingSpringDefaultDescription;
  set springDescription(value) {
    _springDescription = value;
  }

  /// Returns an [Animation<double>] for this animation controller, so that a
  /// pointer to this object can be passed around without allowing users of that
  /// pointer to mutate the [RubberAnimationController] state.
  Animation<double> get view => this;

  /// The length of time this animation should last.
  Duration? duration;

  Ticker? _ticker;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) {
    final Ticker oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  Simulation? _simulation;

  ValueNotifier<AnimationState> animationState =
      ValueNotifier(AnimationState.collapsed);

  /// Initial value of the controller in percentage
  double? initialValue;

  /// The current value of the animation.
  ///
  /// Setting this value notifies all the listeners that the value
  /// changed.
  ///
  /// Setting this value also stops the controller if it is currently
  /// running; if this happens, it also notifies all the status
  /// listeners.
  @override
  double get value => padding.apply(_value);
  double _value = 0.0;

  /// Stops the animation controller and sets the current value of the
  /// animation.
  ///
  /// The new value is clamped to the range set by [lowerBound] and [upperBound].
  ///
  /// Value listeners are notified even if this does not change the value.
  /// Status listeners are notified if the animation was previously playing.
  set value(double newValue) {
    if (lowerBound != null && newValue <= lowerBound!) {
      newValue = lowerBound!;
    }
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkState();
  }

  /// Sets the controller's value to [initialValue] or [lowerBound], stopping the animation (if
  /// in progress), and resetting to its beginning point, or collapsed state.
  void reset() {
    value = initialValue ?? lowerBound!;
  }

  double _height = 0.0;
  set height(double value) {
    _height = value;
    pixelValuesToPercentage();
    value = _value;
  }

  void _resolvePixels(AnimationControllerValue value) {
    final px = value.pixel;
    if (px != null && _height > 0.0) {
      value.percentage = (px / _height).toDouble();
    }
  }

  void pixelValuesToPercentage() {
    // sets initial value if lowerbound has only pixel value
    if (initialValue == null && lowerBound == null) {
      _value = lowerBoundValue.pixel! / _height;
    }
    for (final value in [
      lowerBoundValue,
      halfBoundValue,
      upperBoundValue,
      padding.top,
      padding.bottom,
    ]) {
      if (value != null) {
        _resolvePixels(value);
      }
    }
  }

  /// The rate of change of [value] per second.
  ///
  /// If [isAnimating] is false, then [value] is not changing and the rate of
  /// change is zero.
  double get velocity {
    if (!isAnimating) return 0.0;
    return _simulation!.dx(lastElapsedDuration!.inMicroseconds.toDouble() /
        Duration.microsecondsPerSecond);
  }

  void _internalSetValue(double newValue) {
    _value = newValue;
  }

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration? get lastElapsedDuration => _lastElapsedDuration;
  Duration? _lastElapsedDuration;

  /// Whether this animation is currently animating in either the forward or reverse direction.
  ///
  /// This is separate from whether it is actively ticking. An animation
  /// controller's ticker might get muted, in which case the animation
  /// controller's callbacks will no longer fire even though time is continuing
  /// to pass. See [Ticker.muted] and [TickerMode].
  bool get isAnimating => _ticker != null && _ticker!.isActive;

  /// Tells if the animations is running(forward) or completed
  @override
  AnimationStatus get status => _status;
  AnimationStatus _status = AnimationStatus.completed;

  TickerFuture expand({double? from}) {
    return animateTo(from: from, to: upperBound!);
  }

  TickerFuture halfExpand({double? from}) {
    return animateTo(from: from, to: halfBound!);
  }

  TickerFuture collapse({double? from}) {
    return animateTo(from: from, to: lowerBound!);
  }

  TickerFuture animateTo(
      {double? from, required double to, Curve curve = Curves.easeOut}) {
    assert(() {
      if (duration == null) {
        throw FlutterError(
            'AnimationController.collapse() called with no default Duration.\n'
            'The "duration" property should be set, either in the constructor or later, before '
            'calling the collapse() function.');
      }
      return true;
    }());
    if (from != null) value = from;
    return _animateToInternal(to, curve: curve);
  }

  ValueNotifier<bool> visibility = ValueNotifier(true);
  void setVisibility(bool show) {
    visibility.value = show;
  }

  void _checkState() {
    var roundValue = double.parse(value.toStringAsFixed(2));
    var roundLowerBound = double.parse(lowerBound!.toStringAsFixed(2));
    var roundHalfBound = 0.0;
    if (halfBound != null)
      roundHalfBound = double.parse(halfBound!.toStringAsFixed(2));
    var roundUppperBound = double.parse(upperBound!.toStringAsFixed(2));

    if (roundValue == roundLowerBound) {
      animationState.value = AnimationState.collapsed;
    } else if (halfBound != null && roundValue == roundHalfBound) {
      animationState.value = AnimationState.half_expanded;
    } else if (roundValue == roundUppperBound) {
      animationState.value = AnimationState.expanded;
    } else {
      animationState.value = AnimationState.animating;
    }
  }

  TickerFuture _animateToInternal(double target,
      {Curve curve = Curves.easeOut, AnimationBehavior? animationBehavior}) {
    final AnimationBehavior behavior =
        animationBehavior ?? this.animationBehavior;
    double scale = 1.0;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 0.05;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }
    Duration? simulationDuration = duration;
    if (simulationDuration == null) {
      assert(() {
        if (this.duration == null) {
          throw FlutterError(
              'AnimationController.animateTo() called with no explicit Duration and no default Duration.\n'
              'Either the "duration" argument to the animateTo() method should be provided, or the '
              '"duration" property should be set, either in the constructor or later, before '
              'calling the animateTo() function.');
        }
        return true;
      }());
      final double range = upperBound! - lowerBound!;
      final double remainingFraction =
          range.isFinite ? (target - _value).abs() / range : 1.0;
      simulationDuration = this.duration! * remainingFraction;
    } else if (target == value) {
      // Already at target, don't animate.
      simulationDuration = Duration.zero;
    }
    stop();
    if (simulationDuration == Duration.zero) {
      if (value != target) {
        _value = target;
        notifyListeners();
      }
      _status = AnimationStatus.completed;
      _checkState();
      return TickerFuture.complete();
    }
    assert(simulationDuration > Duration.zero);
    assert(!isAnimating);
    return _startSimulation(_InterpolationSimulation(
        _value, target, simulationDuration, curve, scale));
  }

  double? getBoundFromState(AnimationState state) {
    switch (state) {
      case AnimationState.collapsed:
        return lowerBound;
      case AnimationState.half_expanded:
        return halfBound;
      case AnimationState.expanded:
        return upperBound;
      case AnimationState.animating:
        return null;
    }
  }

  TickerFuture fling(double? from, double? to,
      {double velocity = 1.0, AnimationBehavior? animationBehavior}) {
    final double? target = velocity < 0.0 ? from : to;
    return launchTo(value, target,
        velocity: velocity, animationBehavior: animationBehavior);
  }

  TickerFuture launchTo(double from, double? to,
      {double velocity = 1.0, AnimationBehavior? animationBehavior}) {
    double scale = 1.0;
    final AnimationBehavior behavior =
        animationBehavior ?? this.animationBehavior;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 200.0;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }

    final Simulation simulation =
        SpringSimulation(_springDescription, from, to!, velocity * scale)
          ..tolerance = _kFlingTolerance;
    return animateWith(simulation);
  }

  /// Drives the animation according to the given simulation.
  ///
  /// Returns a [TickerFuture] that completes when the animation is complete.
  TickerFuture animateWith(Simulation simulation) {
    stop();
    return _startSimulation(simulation);
  }

  TickerFuture _startSimulation(Simulation simulation) {
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.zero;
    _value = simulation.x(0.0);
    final TickerFuture result = _ticker!.start();
    _status = AnimationStatus.forward;
    notifyStatusListeners(_status);
    return result;
  }

  /// Stops running this animation.
  ///
  /// This does not trigger any notifications. The animation stops in its
  /// current state.
  void stop({bool canceled = true}) {
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker!.stop(canceled: canceled);
  }

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds =
        elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = _simulation!.x(elapsedInSeconds);
    if (_simulation!.isDone(elapsedInSeconds) ||
        (dismissable && _value < lowerBound! && elapsedInSeconds > 0)) {
      if (_value < lowerBound! && dismissable) _value = lowerBound!;

      _status = AnimationStatus.completed;
      notifyStatusListeners(_status);
      stop();
      _checkState();
    }
    notifyListeners();
  }

  @override
  String toStringDetails() {
    final String paused = isAnimating ? '' : '; paused';
    final String ticker =
        _ticker == null ? '; DISPOSED' : (_ticker!.muted ? '; silenced' : '');
    final String label = debugLabel == null ? '' : '; for $debugLabel';
    final String more =
        '${super.toStringDetails()} ${value.toStringAsFixed(3)}';
    return '$more$paused$ticker$label';
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(
      this._begin, this._end, Duration duration, this._curve, double scale)
      : assert(duration.inMicroseconds > 0),
        _durationInSeconds =
            (duration.inMicroseconds * scale) / Duration.microsecondsPerSecond;

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    final double t = (timeInSeconds / _durationInSeconds).clamp(0.0, 1.0);
    return _begin + (_end - _begin) * _curve.transform(t);
  }

  @override
  double dx(double timeInSeconds) {
    final double epsilon = tolerance.time;
    return (x(timeInSeconds + epsilon) - x(timeInSeconds - epsilon)) /
        (2 * epsilon);
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}
