import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

// ─── Dijkstra's Shortest Path Algorithm ──────────────────────────────────────
//
// Finds the shortest route through a list of geographic waypoints.
// Used after OSRM provides the road-following waypoints: we build a graph
// connecting sequential nodes AND nearby cross-connections, then run
// Dijkstra's to find the globally optimal path from index 0 → last.
//
// Time complexity: O(V²) — sufficient for ≤500 road waypoints.

class DijkstraRouter {
  // ── Haversine great-circle distance (metres) ─────────────────────────────
  static double haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final c = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLon * sinLon;
    return 2 * r * math.atan2(math.sqrt(c), math.sqrt(1 - c));
  }

  // ── Build adjacency list ──────────────────────────────────────────────────
  // Each node i connects to:
  //   • i−1 and i+1  (sequential road waypoints)
  //   • any node j where the straight-line distance is < [shortcutRadius] metres
  //     (simulates alternative road segments that happen to be physically close)
  static List<List<(int, double)>> _buildGraph(
    List<LatLng> pts, {
    double shortcutRadius = 150,
  }) {
    final n = pts.length;
    final g = List<List<(int, double)>>.generate(n, (_) => []);

    for (int i = 0; i < n; i++) {
      // Sequential edge
      if (i + 1 < n) {
        final d = haversineMeters(pts[i], pts[i + 1]);
        g[i].add((i + 1, d));
        g[i + 1].add((i, d));
      }
      // Shortcut edges to geometrically close non-adjacent nodes
      for (int j = i + 2; j < n; j++) {
        final d = haversineMeters(pts[i], pts[j]);
        if (d < shortcutRadius) {
          g[i].add((j, d));
          g[j].add((i, d));
        }
      }
    }
    return g;
  }

  // ── Dijkstra's algorithm ──────────────────────────────────────────────────
  /// Returns the shortest path through [waypoints] from index 0 to last.
  /// If the graph has alternative shortcuts, Dijkstra will choose the
  /// globally minimal-distance path rather than the strictly sequential one.
  static List<LatLng> shortestPath(List<LatLng> waypoints) {
    if (waypoints.length <= 2) return waypoints;

    final n = waypoints.length;
    final graph = _buildGraph(waypoints);

    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int?>.filled(n, null);
    final visited = List<bool>.filled(n, false);
    dist[0] = 0;

    for (int iter = 0; iter < n; iter++) {
      // Select unvisited node with minimum tentative distance
      int u = -1;
      for (int i = 0; i < n; i++) {
        if (!visited[i] && (u == -1 || dist[i] < dist[u])) u = i;
      }
      if (u == -1 || dist[u].isInfinite) break;
      visited[u] = true;
      if (u == n - 1) break; // reached the destination node

      // Relax edges from u
      for (final (v, w) in graph[u]) {
        if (!visited[v]) {
          final alt = dist[u] + w;
          if (alt < dist[v]) {
            dist[v] = alt;
            prev[v] = u;
          }
        }
      }
    }

    // Reconstruct path from destination back to source
    final path = <LatLng>[];
    int? curr = n - 1;
    while (curr != null) {
      path.insert(0, waypoints[curr]);
      curr = prev[curr];
    }
    return path.isEmpty ? waypoints : path;
  }
}
