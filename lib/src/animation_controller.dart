import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:rubber/src/spring_description/damping_ratio.dart';
import 'package:rubber/src/spring_description/stiffness.dart';
import 'package:rubber/src/spring_simulation.dart';

export 'package:flutter/scheduler.dart' show TickerFuture, TickerCanceled;


final SpringDescription _kFlingSpringDefaultDescription = SpringDescription.withDampingRatio(
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
  collapsed
}

class AnimationControllerValue {
  double percentage;
  double pixel;
  AnimationControllerValue({this.percentage = 0.0, this.pixel});
  @override
  String toString() {
    return "percentace: $percentage pixel: $pixel";
  }
}

class RubberAnimationController extends Animation<double>
    with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {

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
  ///   value at which this animation is deemed to be dismissed. It cannot be
  ///   null.
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
  ///
  RubberAnimationController({
    this.lowerBoundValue,
    this.halfBoundValue,
    this.upperBoundValue,
    this.dismissable = false,
    double value,
    this.duration,
    this.debugLabel,
    this.animationBehavior = AnimationBehavior.normal,
    springDescription,
    @required TickerProvider vsync,
  }) : assert(vsync != null) {
    if(springDescription!=null) _springDescription = springDescription;
    _ticker = vsync.createTicker(_tick);
    if(lowerBoundValue == null){
      lowerBoundValue = AnimationControllerValue(percentage: 0.1);
    }
    if(upperBoundValue == null){
      upperBoundValue = AnimationControllerValue(percentage: 0.9);
    }
    _internalSetValue(value ?? lowerBound);
  }

  /// The value at which this animation is collapsed.
  AnimationControllerValue lowerBoundValue;
  double get lowerBound => lowerBoundValue.percentage;

  /// The value at which this animation is half expanded
  AnimationControllerValue halfBoundValue;
  double get halfBound => halfBoundValue != null ? halfBoundValue.percentage : null;

  /// The value at which this animation is expanded.
  AnimationControllerValue upperBoundValue;
  double get upperBound => upperBoundValue.percentage;

  final bool dismissable;

  /// A label that is used in the [toString] output. Intended to aid with
  /// identifying animation controller instances in debug output.
  final String debugLabel;

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
  Duration duration;

  Ticker _ticker;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) {
    final Ticker oldTicker = _ticker;
    _ticker = vsync.createTicker(_tick);
    _ticker.absorbTicker(oldTicker);
  }

  Simulation _simulation;

  AnimationState animationState;

  /// The current value of the animation.
  ///
  /// Setting this value notifies all the listeners that the value
  /// changed.
  ///
  /// Setting this value also stops the controller if it is currently
  /// running; if this happens, it also notifies all the status
  /// listeners.
  @override
  double get value => _value;
  double _value;
  /// Stops the animation controller and sets the current value of the
  /// animation.
  ///
  /// The new value is clamped to the range set by [lowerBound] and [upperBound].
  ///
  /// Value listeners are notified even if this does not change the value.
  /// Status listeners are notified if the animation was previously playing.
  set value(double newValue) {
    assert(newValue != null);
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkStateChanged();
  }

  /// Sets the controller's value to [lowerBound], stopping the animation (if
  /// in progress), and resetting to its beginning point, or dismissed state.
  void reset() {
    value = lowerBound;
  }

  set height(double value) {
    if(lowerBoundValue.pixel != null) {
      lowerBoundValue.percentage = lowerBoundValue.pixel / value;
    }
    if(halfBoundValue!= null && halfBoundValue.pixel != null) {
      halfBoundValue.percentage = halfBoundValue.pixel / value;
    }
    if(upperBoundValue.pixel != null) {
      upperBoundValue.percentage = upperBoundValue.pixel / value;
    }
    _animateToInternal(lowerBound);
  }

  /// The rate of change of [value] per second.
  ///
  /// If [isAnimating] is false, then [value] is not changing and the rate of
  /// change is zero.
  double get velocity {
    if (!isAnimating)
      return 0.0;
    return _simulation.dx(lastElapsedDuration.inMicroseconds.toDouble() / Duration.microsecondsPerSecond);
  }

  void _internalSetValue(double newValue) {
    _value = newValue;
    if (_value == lowerBound || _value == halfBound || _value == upperBound || _value == 0) {
      _status = AnimationStatus.completed;
    } else {
      _status = AnimationStatus.forward;
    }
    _checkStateChanged();
  }

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration get lastElapsedDuration => _lastElapsedDuration;
  Duration _lastElapsedDuration;

  /// Whether this animation is currently animating in either the forward or reverse direction.
  ///
  /// This is separate from whether it is actively ticking. An animation
  /// controller's ticker might get muted, in which case the animation
  /// controller's callbacks will no longer fire even though time is continuing
  /// to pass. See [Ticker.muted] and [TickerMode].
  bool get isAnimating => _ticker != null && _ticker.isActive;

  @override
  AnimationStatus get status => _status;
  AnimationStatus _status;

  TickerFuture expand({ double from }) {
    assert(() {
      if (duration == null) {
        throw FlutterError(
            'AnimationController.forward() called with no default Duration.\n'
                'The "duration" property should be set, either in the constructor or later, before '
                'calling the forward() function.'
        );
      }
      return true;
    }());
    if (from != null)
      value = from;
    return _animateToInternal(upperBound);
  }
  TickerFuture halfExpand({ double from }) {
    assert(() {
      if (duration == null) {
        throw FlutterError(
            'AnimationController.forward() called with no default Duration.\n'
                'The "duration" property should be set, either in the constructor or later, before '
                'calling the forward() function.'
        );
      }
      return true;
    }());
    if (from != null)
      value = from;
    return _animateToInternal(halfBound);
  }
  TickerFuture collapse({ double from }) {
    assert(() {
      if (duration == null) {
        throw FlutterError(
            'AnimationController.reverse() called with no default Duration.\n'
                'The "duration" property should be set, either in the constructor or later, before '
                'calling the reverse() function.'
        );
      }
      return true;
    }());
    if (from != null)
      value = from;
    return _animateToInternal(lowerBound);
  }

  ValueNotifier<bool> visibility = ValueNotifier(true);
  void setVisibility(bool show) {
    visibility.value = show;
  }

  void _checkState() {
    if(nearZero(value - lowerBound, 0.1)) {
      animationState = AnimationState.collapsed;
    }
    else if(halfBound!= null && nearZero(value - halfBound, 0.1)) {
      animationState = AnimationState.half_expanded;
    }
    else if(nearZero(value - upperBound, 0.1)) {
      animationState = AnimationState.expanded;
    }
  }

  TickerFuture _animateToInternal(double target, { Curve curve = Curves.easeOut, AnimationBehavior animationBehavior }) {
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
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
    Duration simulationDuration = duration;
    if (simulationDuration == null) {
      assert(() {
        if (this.duration == null) {
          throw FlutterError(
              'AnimationController.animateTo() called with no explicit Duration and no default Duration.\n'
                  'Either the "duration" argument to the animateTo() method should be provided, or the '
                  '"duration" property should be set, either in the constructor or later, before '
                  'calling the animateTo() function.'
          );
        }
        return true;
      }());
      final double range = upperBound - lowerBound;
      final double remainingFraction = range.isFinite ? (target - _value).abs() / range : 1.0;
      simulationDuration = this.duration * remainingFraction;
    } else if (target == value) {
      // Already at target, don't animate.
      simulationDuration = Duration.zero;
    }
    stop();
    if (simulationDuration == Duration.zero) {
      if (value != target) {
        _value = target.clamp(lowerBound, upperBound);
        notifyListeners();
      }
      _status = AnimationStatus.completed;
      _checkStateChanged();
      return TickerFuture.complete();
    }
    assert(simulationDuration > Duration.zero);
    assert(!isAnimating);
    return _startSimulation(_InterpolationSimulation(_value, target, simulationDuration, curve, scale));
  }

  double getBoundFromState(AnimationState state) {
    switch(state) {
      case AnimationState.collapsed:
        return lowerBound;
      case AnimationState.half_expanded:
        return halfBound;
      case AnimationState.expanded:
        return upperBound;
    }
    return 1.0;
  }

  final double launchSpeed = 7;
  TickerFuture launchTo(AnimationState targetState) {
    final targetBound = getBoundFromState(targetState);
    final currentBound = getBoundFromState(animationState);
    final direction = targetBound < currentBound ? -1.0 : 1.0;
    return launch(min(targetBound,currentBound), max(targetBound,currentBound),velocity: launchSpeed*(direction));
  }
  TickerFuture launch(double from, double to, { double velocity = 1.0, AnimationBehavior animationBehavior }) {
    // no animation necessary
    if(to == from)
      return TickerFuture.complete();
    final double target = velocity < 0.0 ? from : to;
    double scale = 1.0;
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 200.0;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }
    var dismissing = false;
    if(target == lowerBound && dismissable) dismissing = true;

    final Simulation simulation = RubberSpringSimulation(dismissing,_springDescription, value, target, velocity * scale)
      ..tolerance = _kFlingTolerance;
    return animateWith(simulation);
  }

  TickerFuture fling(double from, double to, { double velocity = 1.0, AnimationBehavior animationBehavior }) {
    final double target = velocity < 0.0 ? from : to;
    //print("animationState $animationState from: $from, to: $to, target: $target velocity: $velocity, value: $value");

    double scale = 1.0;
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 200.0;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }

    var dismissing = false;
    if(target == lowerBound && dismissable) dismissing = true;
    final Simulation simulation = RubberSpringSimulation(dismissing,_springDescription, value, target, velocity * scale)
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
    assert(simulation != null);
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.zero;
    _value = simulation.x(0.0);
    final TickerFuture result = _ticker.start();
    _status = AnimationStatus.forward;
    _checkStateChanged();
    return result;
  }

  /// Stops running this animation.
  ///
  /// This does not trigger any notifications. The animation stops in its
  /// current state.
  void stop({ bool canceled = true }) {
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker.stop(canceled: canceled);
  }

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  @override
  void dispose() {
    assert(() {
      if (_ticker == null) {
        throw FlutterError(
            'AnimationController.dispose() called more than once.\n'
                'A given $runtimeType cannot be disposed more than once.\n'
                'The following $runtimeType object was disposed multiple times:\n'
                '  $this'
        );
      }
      return true;
    }());
    _ticker.dispose();
    _ticker = null;
    super.dispose();
  }

  AnimationState _lastReportedState = AnimationState.collapsed;
  void _checkStateChanged() {
    _checkState();
    _checkCurrentState();
  }
  void _checkCurrentState() {
    if (_lastReportedState != animationState) {
      _lastReportedState = animationState;
      notifyStatusListeners(status);
    }
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds = elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = _simulation.x(elapsedInSeconds).clamp(0.0, 1.0);
    if (_simulation.isDone(elapsedInSeconds)) {
      _status = AnimationStatus.completed;
      stop();
      _checkStateChanged();
    }
    notifyListeners();
  }

  @override
  String toStringDetails() {
    final String paused = isAnimating ? '' : '; paused';
    final String ticker = _ticker == null ? '; DISPOSED' : (_ticker.muted ? '; silenced' : '');
    final String label = debugLabel == null ? '' : '; for $debugLabel';
    final String more = '${super.toStringDetails()} ${value.toStringAsFixed(3)}';
    return '$more$paused$ticker$label';
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(this._begin, this._end, Duration duration, this._curve, double scale)
      : assert(_begin != null),
        assert(_end != null),
        assert(duration != null && duration.inMicroseconds > 0),
        _durationInSeconds = (duration.inMicroseconds * scale) / Duration.microsecondsPerSecond;

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    final double t = (timeInSeconds / _durationInSeconds).clamp(0.0, 1.0);
    if (t == 0.0)
      return _begin;
    else if (t == 1.0)
      return _end;
    else
      return _begin + (_end - _begin) * _curve.transform(t);
  }

  @override
  double dx(double timeInSeconds) {
    final double epsilon = tolerance.time;
    return (x(timeInSeconds + epsilon) - x(timeInSeconds - epsilon)) / (2 * epsilon);
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}
