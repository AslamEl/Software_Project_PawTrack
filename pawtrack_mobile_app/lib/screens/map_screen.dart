import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // latlong2 Path<T> conflicts with dart:ui Path
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';
import '../services/routing_service.dart';

const _kDefaultCenter = LatLng(6.9271, 79.8612); // Colombo, Sri Lanka

// ─── Screen ───────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  LatLng? _userLocation;
  bool _mapReady = false;
  String? _activeFilter;
  late Stream<QuerySnapshot> _dogsStream;

  // Routing state
  List<LatLng> _routePoints = [];
  RouteResult? _activeRoute;
  bool _isLoadingRoute = false;

  static const _filterLabels = ['All', 'Hungry', 'Injured', 'Rescued', 'Stray'];

  @override
  void initState() {
    super.initState();
    _dogsStream = _buildStream(null);
    _initLocation();
  }

  // ── Firestore stream ────────────────────────────────────────────────────────
  Stream<QuerySnapshot> _buildStream(String? filter) {
    final col = FirebaseFirestore.instance.collection('dog_reports');
    if (filter == null) return col.limit(100).snapshots();
    return col.where('status', arrayContains: filter).limit(100).snapshots();
  }

  void _setFilter(String? filter) {
    setState(() {
      _activeFilter = filter;
      _dogsStream = _buildStream(filter);
    });
  }

  // ── Location ─────────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = loc);
      if (_mapReady) _mapController.move(loc, 15);
    } catch (_) {}
  }

  void _locateMe() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    } else {
      _initLocation();
    }
  }

  // ── Routing ──────────────────────────────────────────────────────────────────
  Future<void> _fetchRoute(
    GeoPoint dogGeoPoint, {
    TransportMode mode = TransportMode.walk,
  }) async {
    if (_userLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location to get directions.')),
      );
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
      _activeRoute = null;
    });

    final result = await RoutingService.getRoute(
      from: _userLocation!,
      to: LatLng(dogGeoPoint.latitude, dogGeoPoint.longitude),
      mode: mode,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingRoute = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not calculate route. Try again.')),
      );
      return;
    }

    _applyRoute(result, dogGeoPoint);
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _activeRoute = null;
      _isLoadingRoute = false;
    });
  }

  // ── Markers ──────────────────────────────────────────────────────────────────

  // Applies a pre-fetched (or freshly fetched) RouteResult to the map state
  // and fits the camera to show both user and dog.
  void _applyRoute(RouteResult result, GeoPoint dogGeoPoint) {
    final dogLatLng = LatLng(dogGeoPoint.latitude, dogGeoPoint.longitude);
    setState(() {
      _routePoints = result.path;
      _activeRoute = result;
      _isLoadingRoute = false;
    });
    final bounds = LatLngBounds.fromPoints([_userLocation!, dogLatLng]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 240),
      ),
    );
  }

  void _showDogSheet(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoPoint = data['location'] as GeoPoint?;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DogSheet(
        data: data,
        docId: doc.id,
        userLocation: _userLocation,
        dogGeoPoint: geoPoint,
        onDirections: geoPoint != null
            ? (RouteResult? preloaded, TransportMode mode) {
                Navigator.pop(context);
                if (preloaded != null && _userLocation != null) {
                  _applyRoute(preloaded, geoPoint);
                } else {
                  _fetchRoute(geoPoint, mode: mode);
                }
              }
            : null,
      ),
    );
  }

  List<Marker> _buildMarkers(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      return (doc.data() as Map<String, dynamic>)['location'] != null;
    }).map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final geo = data['location'] as GeoPoint;
      final urgency = (data['urgency'] as String? ?? 'low').toLowerCase();
      final name = (data['dogName'] as String?) ?? '';
      return Marker(
        point: LatLng(geo.latitude, geo.longitude),
        width: 110,
        height: 72,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _showDogSheet(doc),
          child: _DogPin(urgency: urgency, name: name),
        ),
      );
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    final hasRoute = _activeRoute != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Base Map ───────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _kDefaultCenter,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 15);
                }
              },
            ),
            children: [
              // Tiles
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.pawtrack.app',
              ),

              // Route polyline — always present so list length never shifts.
              // Empty when no route is active; filled when one is drawn.
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty) ...[
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 9,
                      color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF2196F3),
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ],
              ),

              // Dog report markers — always present StreamBuilder.
              // Keeping this at a fixed index prevents flutter_map from
              // re-mounting the StreamBuilder when route layers appear/disappear,
              // which was causing markers to vanish after cancelling a route.
              StreamBuilder<QuerySnapshot>(
                stream: _dogsStream,
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return MarkerLayer(
                    markers: _buildMarkers(snap.data!.docs),
                  );
                },
              ),

              // User location blue dot — always present, empty when no GPS yet
              MarkerLayer(
                markers: _userLocation == null
                    ? []
                    : [
                        Marker(
                          point: _userLocation!,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4285F4)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
              ),

            ],
          ),

          // ── Attribution (CartoDB / OSM license) ───────────────────────────
          Positioned(
            bottom: bottomPad + 140,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors © CARTO',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),

          // ── Floating search bar ───────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      color: AppColors.muted, size: 20),
                  const SizedBox(width: 8),
                  Text('Search area...',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
                  const Spacer(),
                  Container(width: 1, height: 20, color: AppColors.border),
                  const SizedBox(width: 12),
                  const Icon(Icons.tune_rounded,
                      color: AppColors.orange, size: 20),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),

          // ── Route loading indicator ───────────────────────────────────────
          if (_isLoadingRoute)
            Positioned(
              top: topPad + 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculating shortest path…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom controls ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Route info card (shown when a route is active)
                if (hasRoute)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _RouteInfoCard(
                      route: _activeRoute!,
                      onCancel: _clearRoute,
                    ),
                  ),

                // Filter chips
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filterLabels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final label = _filterLabels[i];
                      final isAll = label == 'All';
                      final selected = isAll
                          ? _activeFilter == null
                          : _activeFilter == label;
                      return GestureDetector(
                        onTap: () => _setFilter(isAll ? null : label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.orange : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: selected
                                    ? AppColors.orange.withOpacity(0.32)
                                    : Colors.black.withOpacity(0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Locate me + Report FAB row
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
                  child: Row(
                    children: [
                      // My location button
                      GestureDetector(
                        onTap: _locateMe,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.my_location_rounded,
                              color: AppColors.ink, size: 22),
                        ),
                      ),
                      const Spacer(),
                      // Report a Dog FAB
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.report),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.orange.withOpacity(0.42),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Report a Dog',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dog Pin ──────────────────────────────────────────────────────────────────
// Lollipop-style marker: info label on top, round ball, thin stick.
// Marker uses alignment: Alignment.bottomCenter so the stick tip sits on the
// exact reported GeoPoint. Whole pin is urgency-coloured; content is white.

class _DogPin extends StatelessWidget {
  const _DogPin({required this.urgency, required this.name});

  final String urgency;
  final String name;

  Color get _pinColor {
    if (urgency == 'high') return const Color(0xFFE53935);
    if (urgency == 'medium') return AppColors.orange;
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty && name.toLowerCase() != 'unknown'
        ? (name.length > 9 ? '${name.substring(0, 9)}…' : name)
        : null;

    final color = _pinColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Info label (current card style, floating above the ball) ──────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.42),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets_rounded, size: 12, color: Colors.white),
              if (displayName != null) ...[
                const SizedBox(width: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),

        // ── Round ball ────────────────────────────────────────────────────────
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),

        // ── Stick / stem ──────────────────────────────────────────────────────
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Route Info Card ──────────────────────────────────────────────────────────

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.route, required this.onCancel});

  final RouteResult route;
  final VoidCallback onCancel;

  IconData get _modeIcon {
    switch (route.mode) {
      case TransportMode.walk:
        return Icons.directions_walk_rounded;
      case TransportMode.bike:
        return Icons.directions_bike_rounded;
      case TransportMode.car:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          // Mode icon (walk / bike / car)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_modeIcon, color: const Color(0xFF2196F3), size: 24),
          ),
          const SizedBox(width: 12),
          // Distance + duration
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                route.distanceLabel,
                style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                route.durationLabel,
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
          const Spacer(),
          // Dijkstra badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Dijkstra',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2196F3),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFFE53935), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dog Detail Bottom Sheet ──────────────────────────────────────────────────

class _DogSheet extends StatefulWidget {
  const _DogSheet({
    required this.data,
    required this.docId,
    this.userLocation,
    this.dogGeoPoint,
    this.onDirections,
  });

  final Map<String, dynamic> data;
  final String docId;
  final LatLng? userLocation;
  final GeoPoint? dogGeoPoint;
  // Receives pre-fetched RouteResult (or null) + selected TransportMode so
  // _MapScreenState can apply it instantly without a second API call.
  final void Function(RouteResult?, TransportMode)? onDirections;

  @override
  State<_DogSheet> createState() => _DogSheetState();
}

class _DogSheetState extends State<_DogSheet> {
  RouteResult? _routeResult;
  bool _isLoadingRoute = false;
  TransportMode _selectedMode = TransportMode.walk;

  @override
  void initState() {
    super.initState();
    _prefetchRoute();
  }

  Future<void> _prefetchRoute() async {
    if (widget.userLocation == null || widget.dogGeoPoint == null) return;
    setState(() {
      _isLoadingRoute = true;
      _routeResult = null;
    });
    final result = await RoutingService.getRoute(
      from: widget.userLocation!,
      to: LatLng(
        widget.dogGeoPoint!.latitude,
        widget.dogGeoPoint!.longitude,
      ),
      mode: _selectedMode,
    );
    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _isLoadingRoute = false;
    });
  }

  void _selectMode(TransportMode mode) {
    if (_selectedMode == mode) return;
    setState(() => _selectedMode = mode);
    _prefetchRoute();
  }

  IconData _modeIconFor(TransportMode mode) {
    switch (mode) {
      case TransportMode.walk:
        return Icons.directions_walk_rounded;
      case TransportMode.bike:
        return Icons.directions_bike_rounded;
      case TransportMode.car:
        return Icons.directions_car_rounded;
    }
  }

  String _modeLabelFor(TransportMode mode) {
    switch (mode) {
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.bike:
        return 'Bike';
      case TransportMode.car:
        return 'Car';
    }
  }

  String _shortDuration(double secs) {
    final mins = (secs / 60).round();
    if (mins < 60) return '~$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '~${h}h' : '~${h}h ${m}m';
  }

  Color get _urgencyColor {
    final u = (widget.data['urgency'] as String? ?? 'low').toLowerCase();
    if (u == 'high') return const Color(0xFFE53935);
    if (u == 'medium') return AppColors.orange;
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final name = (data['dogName'] as String?)?.isNotEmpty == true
        ? data['dogName'] as String
        : 'Unknown Dog';
    final urgency = (data['urgency'] as String? ?? 'low').toLowerCase();
    final statusRaw = data['status'];
    final statuses =
        statusRaw is List ? List<String>.from(statusRaw) : <String>[];
    final notes = (data['notes'] as String?)?.isNotEmpty == true
        ? data['notes'] as String
        : 'No description provided.';
    final photoUrl = data['photoUrl'] as String?;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Photo + info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _PhotoPlaceholder(),
                          errorWidget: (_, __, ___) => _PhotoPlaceholder(),
                        )
                      : _PhotoPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Urgency badge + road distance (from Dijkstra route)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            urgency.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (widget.userLocation != null &&
                            widget.dogGeoPoint != null) ...[
                          const SizedBox(width: 8),
                          if (_isLoadingRoute)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.muted,
                              ),
                            )
                          else if (_routeResult != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _modeIconFor(_selectedMode),
                                  size: 12,
                                  color: const Color(0xFF2196F3),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${_routeResult!.distanceLabel} · '
                                  '${_shortDuration(_routeResult!.durationSeconds)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        style: AppTextStyles.titleMedium
                            .copyWith(fontSize: 16)),
                    const SizedBox(height: 5),
                    if (statuses.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: statuses.take(3).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: AppColors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      notes,
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Transport mode selector: Walk / Bike / Car
          Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: TransportMode.values.map((mode) {
                final selected = _selectedMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectMode(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2196F3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _modeIconFor(mode),
                            size: 18,
                            color: selected ? Colors.white : AppColors.muted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _modeLabelFor(mode),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color:
                                  selected ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Get Directions — passes pre-fetched route + mode so map applies instantly
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onDirections != null
                  ? () => widget.onDirections!(_routeResult, _selectedMode)
                  : null,
              icon: Icon(_modeIconFor(_selectedMode), size: 18),
              label: const Text(
                'Get Directions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF2196F3).withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Offer Help + View Details row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.offerHelp,
                        arguments: widget.docId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(
                        color: AppColors.orange, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Offer Help',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.dogDetail,
                        arguments: widget.docId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('View Details',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.cream,
        child: const Center(
          child: Icon(Icons.pets_rounded, color: AppColors.orange, size: 32),
        ),
      );
}

