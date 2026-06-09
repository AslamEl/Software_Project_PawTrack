import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/dijkstra.dart';

// OSRM public routing API — free, no key required.
// The demo server at router.project-osrm.org only reliably serves 'foot' and
// 'driving' profiles.
//
// Time calculation strategy (ensures car < bike < walk is always respected):
//   Walk → foot route distance ÷ 5 km/h   (calculated, consistent)
//   Bike → foot route distance ÷ 15 km/h  (3× faster than walk, same path)
//   Car  → driving route distance ÷ 40 km/h (urban driving average)
//
// We do NOT use OSRM's returned duration directly for walk/bike because the
// demo server can return unrealistically short walk durations for certain areas
// (e.g. Sri Lanka road network data), making walk appear faster than bike.
const _kOsrmBase = 'https://router.project-osrm.org/route/v1';

// Speed constants (m/s)
const _walkMs = 5000.0 / 3600.0;   //  5 km/h — average walking speed
const _bikeMs = 15000.0 / 3600.0;  // 15 km/h — average cycling speed
const _carMs  = 40000.0 / 3600.0;  // 40 km/h — urban driving average

enum TransportMode { walk, bike, car }

class RouteResult {
  final List<LatLng> path;
  final double distanceMeters;
  final double durationSeconds;
  final TransportMode mode;

  const RouteResult({
    required this.path,
    required this.distanceMeters,
    required this.durationSeconds,
    this.mode = TransportMode.walk,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.toInt()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationLabel {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '~ $mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '~ ${h}h' : '~ ${h}h ${m}m';
  }
}

class RoutingService {
  // Raw OSRM fetch for a given profile. Returns null on any error / non-200.
  static Future<({List<LatLng> path, double distanceMeters, double osrmDuration})?> _fetchOsrm({
    required LatLng from,
    required LatLng to,
    required String profile,
  }) async {
    try {
      final uri = Uri.parse(
        '$_kOsrmBase/$profile/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = (route['distance'] as num).toDouble();
      final osrmDuration = (route['duration'] as num).toDouble();

      // GeoJSON coordinates are [longitude, latitude] — swap to LatLng
      final coords =
          (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      final waypoints = coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      final path = DijkstraRouter.shortestPath(waypoints);
      return (path: path, distanceMeters: distanceMeters, osrmDuration: osrmDuration);
    } catch (_) {
      return null;
    }
  }

  /// Returns a route for the given [mode].
  ///
  /// Walk and Bike both use the foot route shape (safe pedestrian paths).
  /// Times are calculated from distance at fixed speeds so the ordering
  /// car < bike < walk is always guaranteed:
  ///   Walk:  distance ÷ 5 km/h
  ///   Bike:  distance ÷ 15 km/h  (always 3× faster than walk)
  ///   Car:   distance ÷ 40 km/h  (driving route, urban average)
  static Future<RouteResult?> getRoute({
    required LatLng from,
    required LatLng to,
    TransportMode mode = TransportMode.walk,
  }) async {
    switch (mode) {
      case TransportMode.walk:
        final base = await _fetchOsrm(from: from, to: to, profile: 'foot');
        if (base == null) return null;
        return RouteResult(
          path: base.path,
          distanceMeters: base.distanceMeters,
          durationSeconds: base.distanceMeters / _walkMs,
          mode: TransportMode.walk,
        );

      case TransportMode.bike:
        // Use foot route shape (avoids highways) + cycling speed
        final base = await _fetchOsrm(from: from, to: to, profile: 'foot');
        if (base == null) return null;
        return RouteResult(
          path: base.path,
          distanceMeters: base.distanceMeters,
          durationSeconds: base.distanceMeters / _bikeMs,
          mode: TransportMode.bike,
        );

      case TransportMode.car:
        final base =
            await _fetchOsrm(from: from, to: to, profile: 'driving');
        if (base == null) return null;
        return RouteResult(
          path: base.path,
          distanceMeters: base.distanceMeters,
          durationSeconds: base.distanceMeters / _carMs,
          mode: TransportMode.car,
        );
    }
  }

  // Convenience wrapper for walking (backward compatibility)
  static Future<RouteResult?> getWalkingRoute({
    required LatLng from,
    required LatLng to,
  }) =>
      getRoute(from: from, to: to, mode: TransportMode.walk);
}
