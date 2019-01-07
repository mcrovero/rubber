import 'package:flutter/material.dart';

class RubberScrollController extends ScrollController {

  Future<void> flingTo(double offset, {
    @required Duration duration,
    @required Curve curve,
  }) {
    assert(positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    final List<Future<void>> animations = List<Future<void>>(positions.length);
    for (int i = 0; i < positions.length; i += 1)
      animations[i] = positions.elementAt(i).animateTo(offset, duration: duration, curve: curve);
    return Future.wait<void>(animations).then<void>((List<void> _) => null);
  }

}