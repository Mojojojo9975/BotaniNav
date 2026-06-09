// lib/services/compass_service.dart
//
// Reads the device magnetometer via sensors_plus and exposes a stream of
// compass headings in degrees (0–360, clockwise from north).
//
// sensors_plus 7.x API:
//   magnetometerEvents        → deprecated Stream getter (no samplingPeriod)
//   magnetometerEventStream() → current function with samplingPeriod param
//
// The arrow angle consumed by ArrowPainter is computed as:
//   arrowAngle = navigationState.bearing - compassHeading
// This subtraction is done in the provider, NOT here or in the widget.

import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class CompassService {
  final _controller = StreamController<double>.broadcast();

  /// Stream of device heading in degrees [0, 360).
  /// 0 = north, 90 = east, 180 = south, 270 = west.
  Stream<double> get headingStream => _controller.stream;

  StreamSubscription<MagnetometerEvent>? _subscription;

  /// Start listening to the magnetometer.
  void startListening() {
    _subscription = magnetometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
      (MagnetometerEvent event) {
        // atan2 gives radians in [-π, π]; convert to [0, 360) degrees.
        // x-axis points east, y-axis points north on a flat phone.
        final radians = math.atan2(event.x, event.y);
        final degrees = (radians * 180 / math.pi + 360) % 360;
        if (!_controller.isClosed) _controller.add(degrees);
      },
      onError: (Object e) {
        if (!_controller.isClosed) _controller.addError(e);
      },
    );
  }

  /// Stop listening and close the stream.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}