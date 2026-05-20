// lib/services/ble_service.dart
//
// Scans for BLE advertising packets, filters by provisioned beacon UUIDs,
// and exposes a stream of { beaconId → rssi } maps.
// The navigation provider consumes this stream to post position updates to
// the backend trilateration endpoint.
//
// TODO [Backend Phase 3 / Hardware]: This service requires physical BLE beacons
// deployed in the greenhouses. UUID filter list comes from Env.beaconUuids.
// Until hardware is available, MockBleService (bottom of file) is used.

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/env.dart';

typedef BeaconRssiMap = Map<String, int>;

// ─────────────────────────────────────────────────────────────────────────────
// Real BLE Service
// ─────────────────────────────────────────────────────────────────────────────

class BleService {
  final _controller = StreamController<BeaconRssiMap>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  /// Stream of beacon-ID → RSSI snapshots, emitted every scan cycle.
  Stream<BeaconRssiMap> get rssiStream => _controller.stream;

  /// Starts continuous BLE scanning filtered to our beacon UUIDs.
  ///
  /// TODO [Backend Phase 3 / Hardware]: Verify withServices UUID filter works
  /// with the exact advertising format of the provisioned hardware beacons.
  Future<void> startScanning() async {
    final isOn = await FlutterBluePlus.isSupported;
    if (!isOn) {
      _controller.addError(Exception('BLE not supported on this device.'));
      return;
    }

    // Filter by service UUIDs to limit scan results to our beacons.
    final uuidFilters = Env.beaconUuids
        .map((uuid) => Guid(uuid))
        .toList();

    await FlutterBluePlus.startScan(
      withServices: uuidFilters,
      continuousUpdates: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        final snapshot = <String, int>{};
        for (final result in results) {
          final id = result.device.remoteId.str;
          snapshot[id] = result.rssi;
        }
        if (!_controller.isClosed) _controller.add(snapshot);
      },
      onError: (Object e) {
        if (!_controller.isClosed) _controller.addError(e);
      },
    );
  }

  /// Stops scanning and releases resources.
  Future<void> dispose() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    await _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock BLE Service
//
// TODO [Backend Phase 3 / Hardware]: Replace with BleService once beacons are
// provisioned and hardware is available for testing.
// ─────────────────────────────────────────────────────────────────────────────

class MockBleService {
  final _controller = StreamController<BeaconRssiMap>.broadcast();
  Timer? _timer;

  Stream<BeaconRssiMap> get rssiStream => _controller.stream;

  Future<void> startScanning() async {
    int tick = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick++;
      // Simulate three beacons with slowly varying RSSI values.
      if (!_controller.isClosed) {
        _controller.add({
          'MOCK_BEACON_A': -55 - (tick % 10),
          'MOCK_BEACON_B': -72 + (tick % 8),
          'MOCK_BEACON_C': -80 + (tick % 5),
        });
      }
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
