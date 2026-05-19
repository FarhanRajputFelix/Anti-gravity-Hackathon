import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? analysisResult;
  const MapScreen({super.key, this.analysisResult});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _showAfterState = false;
  late AnimationController _pulseController;

  // Geoapify tile URL — dark-matter matches SAHARA midnight theme.
  // Override at build/run time with: --dart-define=GEOAPIFY_KEY=<your-key>
  static const _geoapifyKey = String.fromEnvironment(
    'GEOAPIFY_KEY',
    defaultValue: 'a983e3c179d9424482cf810b3878fdb4',
  );
  static const _tileUrl =
      'https://maps.geoapify.com/v1/tile/dark-matter/{z}/{x}/{y}.png?apiKey=$_geoapifyKey';

  // Dynamic center based on analysis result location
  LatLng get _center =>
      _centerForLocation(widget.analysisResult?['location'] as String?);

  LatLng _centerForLocation(String? location) {
    final loc = (location ?? '').toLowerCase();
    if (loc.contains('karachi')) return const LatLng(24.8607, 67.0104);
    if (loc.contains('lahore')) return const LatLng(31.5204, 74.3587);
    if (loc.contains('peshawar')) return const LatLng(34.0151, 71.5249);
    if (loc.contains('quetta')) return const LatLng(30.1798, 66.9750);
    if (loc.contains('rawalpindi')) return const LatLng(33.5651, 73.0169);
    if (loc.contains('faisalabad')) return const LatLng(31.4187, 73.0791);
    if (loc.contains('multan')) return const LatLng(30.1575, 71.5249);
    // Default: Islamabad
    return const LatLng(33.6938, 73.0145);
  }

  String get _crisisType =>
      (widget.analysisResult?['crisis_type'] as String?) ?? 'FLOODING';
  String get _location =>
      (widget.analysisResult?['location'] as String?) ?? 'G-10, Islamabad';
  String get _severity =>
      (widget.analysisResult?['severity'] as String?) ?? 'CRITICAL';

  // Dynamic crisis markers based on actual analysis
  List<Marker> get _markers {
    final center = _center;
    final markers = <Marker>[];

    // Primary crisis marker
    markers.add(Marker(
      point: center,
      width: 50,
      height: 50,
      child: _buildCrisisMarkerWidget(
          _crisisType, AppTheme.alertRed, Icons.crisis_alert),
    ));

    // Secondary impact zone marker
    markers.add(Marker(
      point: LatLng(center.latitude + 0.015, center.longitude + 0.033),
      width: 44,
      height: 44,
      child: _buildCrisisMarkerWidget(
          'Impact', AppTheme.alertOrange, Icons.warning_amber_rounded),
    ));

    // After-state response markers
    if (_showAfterState) {
      markers.add(Marker(
        point: LatLng(center.latitude + 0.011, center.longitude + 0.014),
        width: 44,
        height: 44,
        child: _buildCrisisMarkerWidget(
            'Rescue', AppTheme.electricBlue, Icons.medical_services),
      ));
      markers.add(Marker(
        point: LatLng(center.latitude - 0.009, center.longitude - 0.010),
        width: 44,
        height: 44,
        child: _buildCrisisMarkerWidget(
            'Evacuate', AppTheme.successGreen, Icons.shield_outlined),
      ));
    }

    return markers;
  }

  Widget _buildCrisisMarkerWidget(String label, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
              color: AppTheme.midnight.withOpacity(0.85),
              borderRadius: BorderRadius.circular(3)),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // Dynamic polylines
  List<Polyline> get _polylines {
    final center = _center;
    final lines = <Polyline>[];

    // Blocked road (red)
    lines.add(Polyline(
      points: [center, LatLng(center.latitude + 0.012, center.longitude + 0.015)],
      color: AppTheme.alertRed,
      strokeWidth: 5,
    ));

    if (_showAfterState) {
      // Alternate route (green)
      lines.add(Polyline(
        points: [
          center,
          LatLng(center.latitude - 0.014, center.longitude - 0.015),
          LatLng(center.latitude - 0.019, center.longitude - 0.025),
        ],
        color: AppTheme.successGreen,
        strokeWidth: 4,
      ));
      // Emergency dispatch route (blue dashed)
      lines.add(Polyline(
        points: [
          LatLng(center.latitude + 0.026, center.longitude + 0.046),
          center,
        ],
        color: AppTheme.electricBlue,
        strokeWidth: 4,
        pattern: const StrokePattern.dotted(),
      ));
    }

    return lines;
  }

  // Dynamic circle overlays
  List<CircleMarker> get _circles {
    final center = _center;
    return [
      CircleMarker(
        point: center,
        radius: 120,
        color: (_showAfterState ? AppTheme.alertOrange : AppTheme.alertRed)
            .withOpacity(0.12),
        borderColor:
            (_showAfterState ? AppTheme.alertOrange : AppTheme.alertRed)
                .withOpacity(0.5),
        borderStrokeWidth: 2,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = widget.analysisResult != null;

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Live Crisis Map'),
        backgroundColor: AppTheme.deepNavy,
        actions: [
          if (hasResult)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildToggleSwitch(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.navyBorder, height: 1),
        ),
      ),
      body: hasResult
          ? Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 13.5,
                    backgroundColor: AppTheme.midnight,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tileUrl,
                      userAgentPackageName: 'com.sahara.ai',
                    ),
                    CircleLayer(circles: _circles),
                    PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: FadeInDown(child: _buildMapLegend())),
                Positioned(
                    bottom: 20,
                    left: 12,
                    right: 12,
                    child: FadeInUp(child: _buildMapStats())),
              ],
            )
          : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: AppTheme.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('No Crisis Analyzed Yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Run an analysis from the Input tab to see the crisis map.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () => setState(() => _showAfterState = !_showAfterState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showAfterState
              ? AppTheme.successGreen.withOpacity(0.2)
              : AppTheme.alertRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _showAfterState
                  ? AppTheme.successGreen.withOpacity(0.5)
                  : AppTheme.alertRed.withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_showAfterState ? Icons.check_circle : Icons.warning,
              color:
                  _showAfterState ? AppTheme.successGreen : AppTheme.alertRed,
              size: 14),
          const SizedBox(width: 6),
          Text(_showAfterState ? 'AFTER' : 'BEFORE',
              style: TextStyle(
                  color: _showAfterState
                      ? AppTheme.successGreen
                      : AppTheme.alertRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildMapLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.midnight.withOpacity(0.9),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(AppTheme.alertRed, 'Danger Zone'),
          const SizedBox(width: 16),
          if (_showAfterState) ...[
            _legendItem(AppTheme.successGreen, 'Reroute'),
            const SizedBox(width: 16),
            _legendItem(AppTheme.electricBlue, 'Dispatch'),
          ] else ...[
            _legendItem(AppTheme.alertOrange, 'Impact Zone'),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ]);
  }

  Widget _buildMapStats() {
    // Read from real analysis result if available
    final sim =
        widget.analysisResult?['simulation'] as Map<String, dynamic>? ?? {};
    final congBefore =
        (sim['congestion_level_before'] as num?)?.toInt() ?? 88;
    final congAfter =
        (sim['congestion_level_after'] as num?)?.toInt() ?? 32;
    final unitsDispatched =
        (sim['emergency_units_dispatched'] as num?)?.toInt() ?? 6;
    final roadsRerouted =
        (sim['roads_rerouted'] as List?)?.length ?? 2;
    final blocked =
        (widget.analysisResult?['shared_memory']?['roads_impacted'] as num?)
                ?.toInt() ??
            3;

    final stats = _showAfterState
        ? [
            {
              'label': 'Congestion',
              'value': '$congAfter%',
              'icon': Icons.traffic,
              'color': AppTheme.successGreen
            },
            {
              'label': 'Routes Active',
              'value': '$roadsRerouted',
              'icon': Icons.alt_route,
              'color': AppTheme.glowBlue
            },
            {
              'label': 'Units',
              'value': '$unitsDispatched',
              'icon': Icons.medical_services,
              'color': AppTheme.electricBlue
            },
          ]
        : [
            {
              'label': 'Congestion',
              'value': '$congBefore%',
              'icon': Icons.traffic,
              'color': AppTheme.alertRed
            },
            {
              'label': 'Blocked',
              'value': '$blocked',
              'icon': Icons.block,
              'color': AppTheme.alertOrange
            },
            {
              'label': 'Units',
              'value': '0',
              'icon': Icons.medical_services,
              'color': AppTheme.textMuted
            },
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.midnight.withOpacity(0.92),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: stats
            .map((s) => Expanded(
                  child: Column(children: [
                    Icon(s['icon'] as IconData,
                        color: s['color'] as Color, size: 18),
                    const SizedBox(height: 4),
                    Text(s['value'] as String,
                        style: TextStyle(
                            color: s['color'] as Color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(s['label'] as String,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}
