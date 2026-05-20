// lib/services/api_service.dart
//
// Thin wrapper around `http` for all REST calls to the FastAPI backend.
// Every request attaches the X-API-Key header required by the backend.
// Business logic lives in providers — this class only sends/receives data.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/plant.dart';
import '../models/navigation_state.dart';

/// Thrown when the backend returns a non-2xx status.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  /// The API key extracted from the deep link (X-API-Key header value).
  final String apiKey;
  final http.Client _client;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Env.apiBase;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '/api/v1$path',
      queryParameters: query,
    );
  }

  Future<dynamic> _get(String path) async {
    final response = await _client.get(_uri(path), headers: _headers);
    _assertOk(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    _assertOk(response);
    return jsonDecode(response.body);
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        response.body.isNotEmpty ? response.body : 'No response body',
      );
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// GET /api/v1/plants
  /// Returns the full plant catalogue for the garden.
  Future<List<Plant>> getPlants() async {
    final data = await _get('/plants') as List<dynamic>;
    return data
        .map((json) => Plant.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/navigation/route
  /// Accepts the user's current GPS coordinates and the target [plantId].
  /// Returns an [OutdoorRoute] with an encoded polyline and step instructions.
  Future<OutdoorRoute> getOutdoorRoute({
    required String plantId,
    required double userLat,
    required double userLng,
  }) async {
    final data = await _post('/navigation/route', {
      'plant_id': plantId,
      'user_lat': userLat,
      'user_lng': userLng,
    });
    return OutdoorRoute.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/v1/scan
  /// Accepts a [sectionId] decoded from a QR code in the greenhouse.
  /// Returns anchored greenhouse coordinates and updated navigation state.
  ///
  /// TODO [Backend Phase 3 / Hardware]: Backend endpoint not yet implemented.
  /// Throws UnimplementedError until the endpoint is ready.
  Future<Map<String, dynamic>> postQrScan({required String sectionId}) async {
    // TODO [Backend Phase 3 / Hardware]: Remove throw and call real endpoint.
    throw UnimplementedError(
      'POST /api/v1/scan is pending backend phase 3. '
      'sectionId=$sectionId received.',
    );
    // Intended implementation when ready:
    // final data = await _post('/scan', {'section_id': sectionId});
    // return data as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}
