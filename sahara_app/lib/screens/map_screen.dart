import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? analysisResult;
  const MapScreen({super.key, this.analysisResult});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _showAfterState = false;
  late AnimationController _pulseController;

  // Default: Islamabad flood scenario
  final LatLng _defaultCenter = const LatLng(33.6938, 73.0145);

  Set<Marker> get _markers {
    final crisisMarkers = {
      Marker(
        markerId: const MarkerId('crisis_1'),
        position: const LatLng(33.6938, 73.0145),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'G-10 Flood Zone', snippet: '🚨 CRITICAL — Active flooding'),
      ),
      Marker(
        markerId: const MarkerId('crisis_2'),
        position: const LatLng(33.7086, 73.0478),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Srinagar Hwy Overflow', snippet: '⚠ HIGH — Road submerged'),
      ),
      if (_showAfterState) ...[
        Marker(
          markerId: const MarkerId('rescue_1'),
          position: const LatLng(33.7050, 73.0280),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Rescue 1122', snippet: '✅ En route — Unit deployed'),
        ),
        Marker(
          markerId: const MarkerId('rescue_2'),
          position: const LatLng(33.6850, 73.0050),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Evacuation Point', snippet: '✅ 850 residents evacuated'),
        ),
      ],
    };
    return crisisMarkers;
  }

  Set<Polyline> get _polylines {
    final lines = <Polyline>{};
    // Blocked road (red)
    lines.add(const Polyline(
      polylineId: PolylineId('blocked_1'),
      color: Color(0xFFFF3B3B),
      width: 6,
      points: [LatLng(33.6938, 73.0145), LatLng(33.7050, 73.0290)],
    ));
    if (_showAfterState) {
      // Alternate route (green)
      lines.add(const Polyline(
        polylineId: PolylineId('reroute_1'),
        color: Color(0xFF00E676),
        width: 4,
        points: [LatLng(33.6938, 73.0145), LatLng(33.6800, 73.0000), LatLng(33.6750, 72.9900)],
      ));
      // Emergency dispatch (blue)
      lines.add(const Polyline(
        polylineId: PolylineId('dispatch_1'),
        color: Color(0xFF1E6FFF),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        points: [LatLng(33.7200, 73.0600), LatLng(33.6938, 73.0145)],
      ));
    }
    return lines;
  }

  Set<Circle> get _circles {
    return {
      Circle(
        circleId: const CircleId('alert_zone'),
        center: const LatLng(33.6938, 73.0145),
        radius: 2500,
        fillColor: (_showAfterState ? AppTheme.alertOrange : AppTheme.alertRed).withOpacity(0.12),
        strokeColor: (_showAfterState ? AppTheme.alertOrange : AppTheme.alertRed).withOpacity(0.5),
        strokeWidth: 2,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Live Crisis Map'),
        backgroundColor: AppTheme.deepNavy,
        actions: [
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _defaultCenter, zoom: 13.5),
            onMapCreated: (c) => _mapController = c,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            style: _mapStyle,
          ),
          Positioned(top: 12, left: 12, right: 12, child: FadeInDown(child: _buildMapLegend())),
          Positioned(bottom: 20, left: 12, right: 12, child: FadeInUp(child: _buildMapStats())),
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
          color: _showAfterState ? AppTheme.successGreen.withOpacity(0.2) : AppTheme.alertRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _showAfterState ? AppTheme.successGreen.withOpacity(0.5) : AppTheme.alertRed.withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_showAfterState ? Icons.check_circle : Icons.warning, color: _showAfterState ? AppTheme.successGreen : AppTheme.alertRed, size: 14),
          const SizedBox(width: 6),
          Text(_showAfterState ? 'AFTER' : 'BEFORE', style: TextStyle(color: _showAfterState ? AppTheme.successGreen : AppTheme.alertRed, fontSize: 11, fontWeight: FontWeight.w700)),
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
            _legendItem(AppTheme.alertOrange, 'Alert Zone'),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ]);
  }

  Widget _buildMapStats() {
    final stats = _showAfterState ? [
      {'label': 'Congestion', 'value': '32%', 'icon': Icons.traffic, 'color': AppTheme.successGreen},
      {'label': 'Routes Active', 'value': '2', 'icon': Icons.alt_route, 'color': AppTheme.glowBlue},
      {'label': 'Units', 'value': '6', 'icon': Icons.local_ambulance, 'color': AppTheme.electricBlue},
    ] : [
      {'label': 'Congestion', 'value': '88%', 'icon': Icons.traffic, 'color': AppTheme.alertRed},
      {'label': 'Blocked', 'value': '3', 'icon': Icons.block, 'color': AppTheme.alertOrange},
      {'label': 'Units', 'value': '0', 'icon': Icons.local_ambulance, 'color': AppTheme.textMuted},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.midnight.withOpacity(0.92),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: stats.map((s) => Expanded(
          child: Column(children: [
            Icon(s['icon'] as IconData, color: s['color'] as Color, size: 18),
            const SizedBox(height: 4),
            Text(s['value'] as String, style: TextStyle(color: s['color'] as Color, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(s['label'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        )).toList(),
      ),
    );
  }

  // Dark map style
  static const String? _mapStyle = null; // Use null for default; pass JSON string for dark style
}
