import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:rubber/rubber_spring_simulation.dart';

export 'package:flutter/scheduler.dart' show TickerFuture, TickerCanceled;

final SpringDescription _kFlingSpringDescription = SpringDescription.withDampingRatio(
  mass: 1.5,
  stiffness: 300.0,
  ratio: 0.4,
);

const Tolerance _kFlingTolerance = Tolerance(
  velocity: double.infinity,
  distance: 0.01,
);

/// The status of an animation
enum RubberAnimationStatus {
  /// The animation is stopped at the beginning
  dismissed,

  /// The animation is running from beginning to end
  forward,

  /// The animation is running backwards, from end to beginning
  reverse,

  /// The animation is stopped at the end
  completed,
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
  /// * [lowerBound] is the smallest value this animation can obtain and the
  ///   value at which this animation is deemed to be dismissed. It cannot be
  ///   null.
  ///
  /// * [halfBound] is the half value this animation can obtain and the
  ///   value at which this animation is deemed to be half expanded. It can be
  ///   null.
  ///
  /// * [upperBound] is the largest value this animation can obtain and the
  ///   value at which this animation is deemed to be completed. It cannot be
  ///   null.
  ///
  /// * `vsync` is the [TickerProvider] for the current context. It can be
  ///   changed by calling [resync]. It is required and must not be null. See
  ///   [TickerProvider] for advice on obtaining a ticker provider.
  RubberAnimationController({
    double value,
    this.duration,
    this.debugLabel,
    this.lowerBound = 0.0,
    this.halfBound = 0.4,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
    @required TickerProvider vsync,
  }) : assert(lowerBound != null),
        assert(upperBound != null),
        assert(upperBound >= lowerBound),
        assert(vsync != null) {
    _ticker = vsync.createTicker(_tick);
    _internalSetValue(value ?? lowerBound);
  }

  /// The value at which this animation is deemed to be dismissed.
  final double lowerBound;

  /// The value at which this animation is deemed to be half completed.
  final double halfBound;

  /// The value at which this animation is deemed to be completed.
  final double upperBound;

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
  ///
  /// The most recently returned [TickerFuture], if any, is marked as having been
  /// canceled, meaning the future never completes and its [TickerFuture.orCancel]
  /// derivative future completes with a [TickerCanceled] error.
  ///
  /// See also:
  ///
  ///  * [reset], which is equivalent to setting [value] to [lowerBound].
  ///  * [stop], which aborts the animation without changing its value or status
  ///    and without dispatching any notifications other than completing or
  ///    canceling the [TickerFuture].
  ///  * [forward], [reverse], [animateTo], [animateWith], [fling], and [repeat],
  ///    which start the animation controller.
  set value(double newValue) {
    assert(newValue != null);
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkStatusChanged();
  }

  /// Sets the controller's value to [lowerBound], stopping the animation (if
  /// in progress), and resetting to its beginning point, or dismissed state.
  ///
  /// The most recently returned [TickerFuture], if any, is marked as having been
  /// canceled, meaning the future never completes and its [TickerFuture.orCancel]
  /// derivative future completes with a [TickerCanceled] error.
  ///
  /// See also:
  ///
  ///  * [value], which can be explicitly set to a specific value as desired.
  ///  * [forward], which starts the animation in the forward direction.
  ///  * [stop], which aborts the animation without changing its value or status
  ///    and without dispatching any notifications other than completing or
  ///    canceling the [TickerFuture].
  void reset() {
    value = lowerBound;
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
    print("expand");
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
    //_direction = _AnimationDirection.forward;
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
    //_direction = _AnimationDirection.collapsed_to_half_expanded;
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

  TickerFuture _animateToInternal(double target, { Duration duration, Curve curve = Curves.easeOut, AnimationBehavior animationBehavior }) {
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    double scale = 1.0;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
        // Since the framework cannot handle zero duration animations, we run it at 5% of the normal
        // duration to limit most animations to a single frame.
        // TODO(jonahwilliams): determine a better process for setting duration.
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
      _checkStatusChanged();
      return TickerFuture.complete();
    }
    assert(simulationDuration > Duration.zero);
    assert(!isAnimating);
    return _startSimulation(_InterpolationSimulation(_value, target, simulationDuration, curve, scale));
  }

  /// Drives the animation with a critically damped spring (within [lowerBound]
  /// and [upperBound]) and initial velocity.
  ///
  /// If velocity is positive, the animation will complete, otherwise it will
  /// dismiss.
  ///
  /// Returns a [TickerFuture] that completes when the animation is complete.
  ///
  /// The most recently returned [TickerFuture], if any, is marked as having been
  /// canceled, meaning the future never completes and its [TickerFuture.orCancel]
  /// derivative future completes with a [TickerCanceled] error.
  TickerFuture fling(double from, double to, { double velocity = 1.0, AnimationBehavior animationBehavior }) {
    //_direction = velocity < 0.0 ? _AnimationDirection.reverse : _AnimationDirection.forward;
    final double target = velocity < 0.0 ? from
        : to;
    double scale = 1.0;
    print("from: $from to: $to velocity: $velocity target: $target");
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
    final Simulation simulation = RubberSpringSimulation(_kFlingSpringDescription, value, target, velocity * scale)
      ..tolerance = _kFlingTolerance;
    return animateWith(simulation);
  }

  /// Drives the animation according to the given simulation.
  ///
  /// Returns a [TickerFuture] that completes when the animation is complete.
  ///
  /// The most recently returned [TickerFuture], if any, is marked as having been
  /// canceled, meaning the future never completes and its [TickerFuture.orCancel]
  /// derivative future completes with a [TickerCanceled] error.
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
    _checkStatusChanged();
    return result;
  }

  /// Stops running this animation.
  ///
  /// This does not trigger any notifications. The animation stops in its
  /// current state.
  ///
  /// By default, the most recently returned [TickerFuture] is marked as having
  /// been canceled, meaning the future never completes and its
  /// [TickerFuture.orCancel] derivative future completes with a [TickerCanceled]
  /// error. By passing the `canceled` argument with the value false, this is
  /// reversed, and the futures complete successfully.
  ///
  /// See also:
  ///
  ///  * [reset], which stops the animation and resets it to the [lowerBound],
  ///    and which does send notifications.
  ///  * [forward], [reverse], [animateTo], [animateWith], [fling], and [repeat],
  ///    which restart the animation controller.
  void stop({ bool canceled = true }) {
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker.stop(canceled: canceled);
  }

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  ///
  /// The most recently returned [TickerFuture], if any, is marked as having been
  /// canceled, meaning the future never completes and its [TickerFuture.orCancel]
  /// derivative future completes with a [TickerCanceled] error.
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

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    final AnimationStatus newStatus = status;
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      notifyStatusListeners(newStatus);
    }
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds = elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = _simulation.x(elapsedInSeconds);
    if (_simulation.isDone(elapsedInSeconds)) {
      print("cancelled");
      stop(canceled: false);
    }
    notifyListeners();
    _checkStatusChanged();
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
