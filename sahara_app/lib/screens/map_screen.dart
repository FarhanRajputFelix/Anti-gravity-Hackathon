import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? analysisResult;
  const MapScreen({super.key, this.analysisResult});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final PageController _carouselController = PageController(viewportFraction: 0.88, initialPage: 0);
  late AnimationController _pulseController;
  late AnimationController _scanController;
  Timer? _refreshTimer;
  Timer? _zoomTimer;

  bool _loading        = true;
  bool _worldView      = true;
  bool _carouselExpanded = true;   // collapsible bottom bar
  int  _selectedCrisis = 0;

  List<Map<String, dynamic>> _crises = [];

  static const _worldCam    = LatLng(20.0, 60.0);
  static const _pakistanCam = LatLng(30.3753, 69.3451);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _scanController  = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadData());

    // Cinematic intro: world → Pakistan → just-analyzed crisis
    _zoomTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _mapController.move(_pakistanCam, 5.5);
        setState(() => _worldView = false);
        Future.delayed(const Duration(seconds: 2), _focusOnFirstCrisis);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final crises = await ApiService.getLiveCrises();
      if (mounted) {
        // If the user just submitted an analysis, move that crisis to position 0
        final justAnalyzedId = widget.analysisResult?['crisis_id'] as String?;
        if (justAnalyzedId != null) {
          final idx = crises.indexWhere((c) => c['crisis_id'] == justAnalyzedId);
          if (idx > 0) {
            final pinned = crises.removeAt(idx);
            crises.insert(0, pinned);
          }
        }
        setState(() {
          _crises = crises;
          _loading = false;
        });
        // Auto-focus on the just-analyzed crisis (or first/most recent)
        if (_crises.isNotEmpty) _focusOnFirstCrisis();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _focusOnFirstCrisis() {
    if (_crises.isEmpty) return;
    final c = _crises[0];
    final lat = (c['lat'] as num?)?.toDouble();
    final lon = (c['lon'] as num?)?.toDouble();
    if (lat != null && lon != null) {
      _mapController.move(LatLng(lat, lon), 11);
      setState(() => _selectedCrisis = 0);
    }
  }

  bool get _showRoutes => _crises.any((c) =>
    c['verification'] == 'CONFIRMED' ||
    ((c['confidence'] as num?)?.toDouble() ?? 0) > 0.7
  );

  void _focusOnCritical() {
    if (_crises.isEmpty) return;
    final sorted = List<Map<String, dynamic>>.from(_crises)..sort((a, b) {
      final order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};
      return (order[a['severity']] ?? 9).compareTo(order[b['severity']] ?? 9);
    });
    final top = sorted.first;
    final lat = (top['lat'] as num?)?.toDouble() ?? 33.6938;
    final lon = (top['lon'] as num?)?.toDouble() ?? 73.0145;
    _mapController.move(LatLng(lat, lon), 11);
  }

  // ─── Marker layer: pulsing red dots for crises + green for hospitals ──
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    final justAnalyzedId = widget.analysisResult?['crisis_id'] as String?;

    for (int i = 0; i < _crises.length; i++) {
      final c = _crises[i];
      final lat = (c['lat'] as num?)?.toDouble();
      final lon = (c['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final sev = c['severity'] as String? ?? 'UNKNOWN';
      final color = _severityColor(sev);
      final type = (c['crisis_type'] as String? ?? 'UNKNOWN').replaceAll('_', ' ');
      final isJustAnalyzed = c['crisis_id'] == justAnalyzedId;
      final markerScale = isJustAnalyzed ? 1.4 : 1.0;

      markers.add(Marker(
        point: LatLng(lat, lon),
        width: 110 * markerScale, height: 110 * markerScale,
        child: GestureDetector(
          onTap: () => setState(() => _selectedCrisis = i),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final pulse = (math.sin(_pulseController.value * 2 * math.pi) + 1) / 2;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing ring (extra dramatic on just-analyzed)
                  Container(
                    width: (60 + pulse * 30) * markerScale,
                    height: (60 + pulse * 30) * markerScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15 * (1 - pulse * 0.5)),
                      border: Border.all(
                        color: color.withOpacity(0.6 - pulse * 0.4),
                        width: isJustAnalyzed ? 3 : 2,
                      ),
                    ),
                  ),
                  if (isJustAnalyzed)
                    Container(
                      width: (75 + pulse * 30) * markerScale,
                      height: (75 + pulse * 30) * markerScale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.successGreen.withOpacity(0.4 + pulse * 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  // Core marker
                  Container(
                    width: 36 * markerScale, height: 36 * markerScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [color, color.withOpacity(0.6)]),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.9), blurRadius: 14, spreadRadius: 3)],
                    ),
                    child: Icon(_crisisIcon(type), color: Colors.white, size: 18 * markerScale),
                  ),
                  // "Just Analyzed" badge floats above
                  if (isJustAnalyzed)
                    Positioned(
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.successGreen, Color(0xFF00A046)]),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(0.6), blurRadius: 8)],
                        ),
                        child: const Text('YOUR INPUT',
                            style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ));

      // Emergency facility markers (only after verification)
      if (_showRoutes) {
        // Hospitals — green
        for (final f in List<Map<String, dynamic>>.from(c['hospitals'] ?? []).take(5)) {
          _addFacilityMarker(markers, f, AppTheme.successGreen, Icons.local_hospital);
        }
        // Shelters — cyan
        for (final f in List<Map<String, dynamic>>.from(c['shelters'] ?? []).take(3)) {
          _addFacilityMarker(markers, f, AppTheme.cyanAccent, Icons.home_work);
        }
        // Police — blue
        for (final f in List<Map<String, dynamic>>.from(c['police'] ?? []).take(2)) {
          _addFacilityMarker(markers, f, AppTheme.electricBlue, Icons.local_police);
        }
        // Fire stations — orange
        for (final f in List<Map<String, dynamic>>.from(c['fire_stations'] ?? []).take(2)) {
          _addFacilityMarker(markers, f, AppTheme.alertOrange, Icons.local_fire_department);
        }
      }
    }
    return markers;
  }

  void _addFacilityMarker(List<Marker> markers, Map<String, dynamic> f, Color color, IconData icon) {
    final lat = (f['lat'] as num?)?.toDouble();
    final lon = (f['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    markers.add(Marker(
      point: LatLng(lat, lon),
      width: 32, height: 32,
      child: Tooltip(
        message: '${f['name'] ?? ''}\n${f['distance_km'] ?? '?'} km',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    ));
  }

  // ─── Polylines: multi-color routes (revealed after verification) ──
  List<Polyline> _buildPolylines() {
    final lines = <Polyline>[];
    if (!_showRoutes) return lines;

    final colors = [
      const Color(0xFF00E676),
      const Color(0xFF1E6FFF),
      const Color(0xFFFF7A00),
    ];

    for (final c in _crises) {
      final clat = (c['lat'] as num?)?.toDouble();
      final clon = (c['lon'] as num?)?.toDouble();
      if (clat == null || clon == null) continue;

      final routes = List<Map<String, dynamic>>.from(c['routes'] ?? []);
      for (int r = 0; r < routes.length; r++) {
        final polyline = List<Map<String, dynamic>>.from(routes[r]['polyline'] ?? []);
        if (polyline.length < 2) continue;
        final points = polyline.map((p) => LatLng(
          (p['lat'] as num).toDouble(),
          (p['lon'] as num).toDouble(),
        )).toList();
        lines.add(Polyline(
          points: points,
          color: colors[r % colors.length],
          strokeWidth: 5,
          isDotted: r > 0,
        ));
      }

      // Synthetic radial routes to hospitals if no Geoapify routes
      if (routes.isEmpty) {
        final hospitals = List<Map<String, dynamic>>.from(c['hospitals'] ?? []);
        for (int h = 0; h < hospitals.length && h < 3; h++) {
          final hos = hospitals[h];
          final hlat = (hos['lat'] as num?)?.toDouble();
          final hlon = (hos['lon'] as num?)?.toDouble();
          if (hlat == null || hlon == null) continue;
          lines.add(Polyline(
            points: [LatLng(clat, clon), LatLng(hlat, hlon)],
            color: colors[h % colors.length],
            strokeWidth: 4,
            isDotted: h > 0,
          ));
        }
      }
    }
    return lines;
  }

  // ─── Circles: pulsing alert zones (radius animates with sine) ──
  List<CircleMarker> _buildCircles() {
    final circles = <CircleMarker>[];
    final pulse = (math.sin(_pulseController.value * 2 * math.pi) + 1) / 2;

    for (final c in _crises) {
      final lat = (c['lat'] as num?)?.toDouble();
      final lon = (c['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final sev = c['severity'] as String? ?? 'UNKNOWN';
      final color = _severityColor(sev);
      final baseRadius = sev == 'CRITICAL' ? 3500.0 : sev == 'HIGH' ? 2500.0 : 1500.0;

      // Outer pulsing ring
      circles.add(CircleMarker(
        point: LatLng(lat, lon),
        radius: baseRadius * (1.0 + pulse * 0.3),
        useRadiusInMeter: true,
        color: color.withOpacity(0.08 + pulse * 0.05),
        borderColor: color.withOpacity(0.5 + pulse * 0.3),
        borderStrokeWidth: 3,
      ));

      // Core danger zone
      circles.add(CircleMarker(
        point: LatLng(lat, lon),
        radius: baseRadius * 0.5,
        useRadiusInMeter: true,
        color: color.withOpacity(0.18),
        borderColor: color.withOpacity(0.7),
        borderStrokeWidth: 2,
      ));

      // Traffic congestion ring
      if (_showRoutes) {
        circles.add(CircleMarker(
          point: LatLng(lat, lon),
          radius: baseRadius * 1.4,
          useRadiusInMeter: true,
          color: AppTheme.alertOrange.withOpacity(0.04),
          borderColor: AppTheme.alertOrange.withOpacity(0.3),
          borderStrokeWidth: 1,
        ));
      }
    }
    return circles;
  }

  String _severityEmoji(String sev) {
    switch (sev) {
      case 'CRITICAL': return '🔴';
      case 'HIGH':     return '🟠';
      case 'MEDIUM':   return '🟡';
      default:         return '🟢';
    }
  }

  Color _severityColor(String sev) {
    switch (sev) {
      case 'CRITICAL': return AppTheme.alertRed;
      case 'HIGH':     return AppTheme.alertOrange;
      case 'MEDIUM':   return AppTheme.alertYellow;
      default:         return AppTheme.successGreen;
    }
  }

  IconData _crisisIcon(String type) {
    final t = type.toUpperCase();
    if (t.contains('FLOOD')) return Icons.water;
    if (t.contains('HEAT')) return Icons.thermostat;
    if (t.contains('FIRE')) return Icons.local_fire_department;
    if (t.contains('ACCIDENT') || t.contains('TRAFFIC')) return Icons.car_crash;
    if (t.contains('EARTHQUAKE')) return Icons.vibration;
    return Icons.warning_amber_rounded;
  }

  void _onCarouselChanged(int i) {
    setState(() => _selectedCrisis = i);
    if (i >= _crises.length) return;
    final c = _crises[i];
    final lat = (c['lat'] as num?)?.toDouble();
    final lon = (c['lon'] as num?)?.toDouble();
    if (lat != null && lon != null) {
      _mapController.move(LatLng(lat, lon), 12.5);
    }
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    _refreshTimer?.cancel();
    _zoomTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = _crises.where((c) => c['severity'] == 'CRITICAL').length;

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ─── Base Map ──────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _worldCam,
                initialZoom: 2.5,
                maxZoom: 18,
                minZoom: 2,
                backgroundColor: Color(0xFF050E1F),
              ),
              children: [
                // Dark OpenStreetMap tiles via CartoDB Dark Matter
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.sahara.ai',
                  maxZoom: 19,
                ),
                CircleLayer(circles: _buildCircles()),
                PolylineLayer(polylines: _buildPolylines()),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          // ─── Scanning Radar (intro animation) ──
          if (_worldView)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (_, __) => CustomPaint(
                    painter: _RadarPainter(progress: _scanController.value),
                  ),
                ),
              ),
            ),

          // ─── Top Status Bar ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  FadeInDown(child: _buildTopBar(criticalCount)),
                  if (widget.analysisResult != null)
                    FadeInDown(delay: const Duration(milliseconds: 200), child: _buildJustAnalyzedBanner()),
                ],
              ),
            ),
          ),

          // ─── Left: Verification Panel ──
          Positioned(
            top: 110, left: 12,
            child: FadeInLeft(delay: const Duration(milliseconds: 400), child: _buildVerificationPanel()),
          ),

          // ─── Right: Quick Actions ──
          Positioned(
            top: 110, right: 12,
            child: FadeInRight(delay: const Duration(milliseconds: 600), child: _buildQuickActions()),
          ),

          // ─── Bottom: Crisis Carousel ──
          if (_crises.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: FadeInUp(child: _buildCrisisCarousel()),
            ),

          // ─── Loading Overlay ──
          if (_loading)
            Container(
              color: AppTheme.midnight.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.electricBlue),
                    const SizedBox(height: 16),
                    Text('Connecting to SAHARA AI...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJustAnalyzedBanner() {
    final r = widget.analysisResult!;
    final type = (r['crisis_type'] as String? ?? 'UNKNOWN').replaceAll('_', ' ');
    final city = (r['city'] as String? ?? 'Unknown');
    final loc = r['location'] as String? ?? city;
    final sev = r['severity'] as String? ?? 'UNKNOWN';
    final conf = ((r['confidence'] as num? ?? 0) * 100).round();
    final color = _severityColor(sev);

    return GestureDetector(
      onTap: _focusOnFirstCrisis,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              AppTheme.successGreen.withOpacity(0.25),
              color.withOpacity(0.20),
              AppTheme.deepNavy.withOpacity(0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(0.3), blurRadius: 16)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.successGreen, Color(0xFF00A046)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(0.5), blurRadius: 10)],
              ),
              child: const Icon(Icons.gps_fixed, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('FOCUSED ON YOUR INPUT',
                          style: TextStyle(color: AppTheme.successGreen, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                        child: Text(sev,
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$type · $loc',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('$conf%',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(int criticalCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.midnight.withOpacity(0.85),
          AppTheme.deepNavy.withOpacity(0.75),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassStroke),
        boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Row(
        children: [
          BackButton(onPressed: () => Navigator.maybePop(context), color: AppTheme.textPrimary),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.blueGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.5), blurRadius: 12)],
            ),
            child: const Icon(Icons.public, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIVE CRISIS MAP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              Text('Pakistan • Real-time monitoring', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final p = (math.sin(_pulseController.value * 2 * math.pi) + 1) / 2;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.alertRed.withOpacity(0.4 + p * 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.alertRed.withOpacity(p), blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$criticalCount CRITICAL', style: TextStyle(color: AppTheme.alertRed, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPanel() {
    final verifiedCount = _crises.where((c) => c['verification'] == 'CONFIRMED').length;
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.deepNavy.withOpacity(0.92), AppTheme.navyCard.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _showRoutes ? AppTheme.successGreen.withOpacity(0.5) : AppTheme.glassStroke),
        boxShadow: [BoxShadow(color: (_showRoutes ? AppTheme.successGreen : AppTheme.electricBlue).withOpacity(0.2), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _showRoutes ? Icons.verified : Icons.security,
                color: _showRoutes ? AppTheme.successGreen : AppTheme.electricBlue,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(_showRoutes ? 'VERIFIED' : 'SCANNING',
                style: TextStyle(
                  color: _showRoutes ? AppTheme.successGreen : AppTheme.electricBlue,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _agentRow('Signal Ingestion', _crises.isNotEmpty),
          _agentRow('Verification',     _crises.isNotEmpty),
          _agentRow('Severity Analysis', _crises.isNotEmpty),
          _agentRow('Response Planning', _showRoutes),
          _agentRow('Geoapify Routing',  _showRoutes),
          _agentRow('Hospital Dispatch', _showRoutes),
          if (_showRoutes) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('AUTHENTIC $verifiedCount/${_crises.length}',
                style: TextStyle(color: AppTheme.successGreen, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _agentRow(String name, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppTheme.successGreen : AppTheme.textMuted, size: 11),
          const SizedBox(width: 5),
          Expanded(
            child: Text(name,
              style: TextStyle(color: done ? AppTheme.textSecondary : AppTheme.textMuted, fontSize: 9),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _quickBtn(Icons.zoom_out_map, () { _mapController.move(_worldCam, 2.5); setState(() => _worldView = true); }),
        const SizedBox(height: 8),
        _quickBtn(Icons.flag, () { _mapController.move(_pakistanCam, 5.5); setState(() => _worldView = false); }),
        const SizedBox(height: 8),
        _quickBtn(Icons.crisis_alert, _focusOnCritical, color: AppTheme.alertRed),
        const SizedBox(height: 8),
        _quickBtn(Icons.refresh, _loadData),
        const SizedBox(height: 8),
        _quickBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
        const SizedBox(height: 8),
        _quickBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
      ],
    );
  }

  Widget _quickBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.deepNavy.withOpacity(0.92), AppTheme.navyCard.withOpacity(0.85)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (color ?? AppTheme.glassStroke).withOpacity(0.4)),
          boxShadow: [BoxShadow(color: (color ?? AppTheme.electricBlue).withOpacity(0.15), blurRadius: 8)],
        ),
        child: Icon(icon, color: color ?? AppTheme.textPrimary, size: 18),
      ),
    );
  }

  Widget _buildCrisisCarousel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: _carouselExpanded ? 195 : 40,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppTheme.midnight.withOpacity(0.85), AppTheme.midnight],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _carouselExpanded = !_carouselExpanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              color: Colors.transparent,
              child: Row(
                children: [
                  Text('ACTIVE INCIDENTS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.alertRed.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text('${_crises.length} LIVE', style: TextStyle(color: AppTheme.alertRed, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(_carouselExpanded ? 'tap to collapse' : 'tap to expand',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  const SizedBox(width: 4),
                  Icon(_carouselExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: AppTheme.textMuted, size: 16),
                ],
              ),
            ),
          ),
          if (!_carouselExpanded) const SizedBox.shrink() else
          SizedBox(
            height: 145,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _carouselController,
                  onPageChanged: _onCarouselChanged,
                  itemCount: _crises.length,
                  itemBuilder: (_, i) => _buildCrisisDetailCard(_crises[i], i == _selectedCrisis),
                ),
                // Left arrow
                if (_selectedCrisis > 0)
                  Positioned(
                    left: 8, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _carouselController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        ),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.deepNavy.withOpacity(0.92),
                            border: Border.all(color: AppTheme.electricBlue.withOpacity(0.4)),
                            boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.chevron_left, color: AppTheme.textPrimary, size: 22),
                        ),
                      ),
                    ),
                  ),
                // Right arrow
                if (_selectedCrisis < _crises.length - 1)
                  Positioned(
                    right: 8, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _carouselController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        ),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.deepNavy.withOpacity(0.92),
                            border: Border.all(color: AppTheme.electricBlue.withOpacity(0.4)),
                            boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.chevron_right, color: AppTheme.textPrimary, size: 22),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisDetailCard(Map<String, dynamic> c, bool active) {
    final sev = c['severity'] as String? ?? 'UNKNOWN';
    final color = _severityColor(sev);
    final type = (c['crisis_type'] as String? ?? 'UNKNOWN').replaceAll('_', ' ');
    final conf = ((c['confidence'] as num? ?? 0) * 100).round();
    final verification = c['verification'] as String? ?? 'UNVERIFIED';
    final isAuthentic = verification == 'CONFIRMED';
    final hospitalsCount = (c['hospitals'] as List? ?? []).length;
    final routesCount    = (c['routes']    as List? ?? []).length;
    final sheltersCount  = (c['shelters']  as List? ?? []).length;

    return AnimatedScale(
      scale: active ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppTheme.deepNavy.withOpacity(0.95), color.withOpacity(0.10)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_crisisIcon(type), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      Text(c['location'] as String? ?? c['city'] as String? ?? 'Unknown',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Text(sev, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(isAuthentic ? Icons.verified : Icons.pending, size: 12,
                  color: isAuthentic ? AppTheme.successGreen : AppTheme.alertYellow),
                const SizedBox(width: 4),
                Text(isAuthentic ? 'AUTHENTIC' : verification,
                  style: TextStyle(color: isAuthentic ? AppTheme.successGreen : AppTheme.alertYellow,
                    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Confidence', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: conf / 100, backgroundColor: AppTheme.navyBorder, color: color, minHeight: 4),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$conf%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat(Icons.local_hospital, '$hospitalsCount', 'Hosp', AppTheme.successGreen),
                const SizedBox(width: 6),
                _miniStat(Icons.home_work, '$sheltersCount', 'Shelt', AppTheme.cyanAccent),
                const SizedBox(width: 6),
                _miniStat(Icons.alt_route, '$routesCount', 'Rt', AppTheme.electricBlue),
                const SizedBox(width: 6),
                _miniStat(Icons.list_alt, '${c['action_count'] ?? 0}', 'Act', AppTheme.alertOrange),
                const Spacer(),
                if (isAuthentic)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.successGreen, Color(0xFF00B453)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text('DISPATCHED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Radar scanning effect during world view ────
class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    for (int i = 0; i < 3; i++) {
      final offset = (progress + i / 3) % 1.0;
      final radius = maxRadius * offset;
      final paint = Paint()
        ..color = const Color(0xFF1E6FFF).withOpacity((1 - offset) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }

    final angle = progress * 2 * math.pi;
    final lineEnd = Offset(
      center.dx + math.cos(angle) * maxRadius,
      center.dy + math.sin(angle) * maxRadius,
    );
    final linePaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1E6FFF).withOpacity(0.5), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..strokeWidth = 3;
    canvas.drawLine(center, lineEnd, linePaint);
  }

  @override
  bool shouldRepaint(_) => true;
}
