import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'providers/gnss_provider.dart';

enum MeasureState { idle, measuring, finished }
const double _rulerZoomThreshold = 19.0;

class PolarRulerPainter extends CustomPainter {
  final double zoom;
  final double latitude;
  final double rotation;

  PolarRulerPainter({
    required this.zoom,
    required this.latitude,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const double earthRadius = 6378137.0;
    final double latRad = latitude * math.pi / 180;
    final double metersPerPixel = (2 * math.pi * earthRadius * math.cos(latRad)) / (256 * math.pow(2, zoom));
    final double pixelsPerMeter = 1.0 / metersPerPixel;
    final double pixelsPerCm = pixelsPerMeter / 100.0;

    final Paint circlePaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint majorCirclePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Paint crossPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint centerDotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final double rotationRad = rotation * math.pi / 180.0;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationRad); 
    canvas.translate(-center.dx, -center.dy);

    final double crossLength = math.min(size.width, size.height) * 0.45;
    canvas.drawLine(
      Offset(center.dx - crossLength, center.dy),
      Offset(center.dx + crossLength, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crossLength),
      Offset(center.dx, center.dy + crossLength),
      crossPaint,
    );

    final TextPainter northPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    northPainter.layout();
    northPainter.paint(
      canvas,
      Offset(center.dx - northPainter.width / 2, center.dy - crossLength - 20),
    );

    final List<double> scaleOptions = [
      0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0
    ];
    
    final double maxRadius = math.min(size.width, size.height) * 0.4;
    double scaleInterval = scaleOptions.last;
    for (final scale in scaleOptions) {
      if (scale * pixelsPerMeter <= maxRadius / 5) {
        scaleInterval = scale;
      } else {
        break;
      }
    }
    for (int i = 1; i <= 10; i++) {
      final double radiusMeters = scaleInterval * i;
      final double radiusPixels = radiusMeters * pixelsPerMeter;
      if (radiusPixels > maxRadius) break;
      final bool isMajor = i % 5 == 0;
      canvas.drawCircle(
        center,
        radiusPixels,
        isMajor ? majorCirclePaint : circlePaint,
      );
      String label;
      if (radiusMeters >= 1.0) {
        label = '${radiusMeters.toStringAsFixed(radiusMeters == radiusMeters.roundToDouble() ? 0 : 1)}m';
      } else {
        label = '${(radiusMeters * 100).toStringAsFixed(0)}cm';
      }
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isMajor ? Colors.grey.shade800 : Colors.grey.shade600,
            fontSize: isMajor ? 11 : 9,
            fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
            backgroundColor: Colors.white.withOpacity(0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - radiusPixels - textPainter.height),
      );
    }
    canvas.restore();
    canvas.drawCircle(center, 3, centerDotPaint);
  }

  @override
  bool shouldRepaint(PolarRulerPainter oldDelegate) {
    return zoom != oldDelegate.zoom ||
        latitude != oldDelegate.latitude ||
        rotation != oldDelegate.rotation;
  }
}


enum BaseMapType {
  osm,
  googleSatellite,
  arcgisImagery,
  arcgisStreet,
  cartoLight,
}

class BaseMapConfig {
  final String name;
  final String urlTemplate;
  final String? subdomains;

  const BaseMapConfig({
    required this.name,
    required this.urlTemplate,
    this.subdomains,
  });
}

const Map<BaseMapType, BaseMapConfig> baseMapConfigs = {
  BaseMapType.osm: BaseMapConfig(
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  BaseMapType.googleSatellite: BaseMapConfig(
    name: '谷歌地球影像',
    urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
  ),
  BaseMapType.arcgisImagery: BaseMapConfig(
    name: 'ArcGIS 世界影像',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  BaseMapType.arcgisStreet: BaseMapConfig(
    name: 'ArcGIS 街道地图',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  ),
  BaseMapType.cartoLight: BaseMapConfig(
    name: 'CartoDB 地图',
    urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  ),

};

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  MeasureState _measureState = MeasureState.idle;
  LatLng? _measureStartPoint;
  LatLng? _measureEndPoint;

  BaseMapType _currentBaseMap = BaseMapType.osm;

  double _currentZoom = 18.0;
  double _currentRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBaseMapPreference();
  }

  Future<void> _loadBaseMapPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMapType = prefs.getString('baseMapType');
    if (savedMapType != null) {
      setState(() {
        _currentBaseMap = BaseMapType.values.firstWhere(
          (e) => e.name == savedMapType,
          orElse: () => BaseMapType.osm,
        );
      });
    }
  }

  Future<void> _saveBaseMapPreference(BaseMapType mapType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseMapType', mapType.name);
  }

  void _showBaseMapDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择底图'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: BaseMapType.values.map((mapType) {
              final config = baseMapConfigs[mapType]!;
              return RadioListTile<BaseMapType>(
                title: Text(config.name),
                value: mapType,
                groupValue: _currentBaseMap,
                onChanged: (BaseMapType? value) {
                  if (value != null) {
                    setState(() {
                      _currentBaseMap = value;
                    });
                    _saveBaseMapPreference(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * math.pi / 180;
    final double lon1 = start.longitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double lon2 = end.longitude * math.pi / 180;

    final double dLon = lon2 - lon1;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  void _handleMeasureTap(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("等待定位...")),
      );
      return;
    }
    final currentPos = LatLng(latitude, longitude);
    setState(() {
      switch (_measureState) {
        case MeasureState.idle:
          _measureState = MeasureState.measuring;
          _measureStartPoint = currentPos;
          _measureEndPoint = null;
          break;
        case MeasureState.measuring:
          _measureState = MeasureState.finished;
          _measureEndPoint = currentPos;
          break;
        case MeasureState.finished:
          _measureState = MeasureState.idle;
          _measureStartPoint = null;
          _measureEndPoint = null;
          break;
      }
    });
  }


  List<LatLng> _getErrorEllipsePoints(
      double centerLat, double centerLon, double semiMajor, double semiMinor, 
      double orientationDeg) {
    if (semiMajor <= 0 || semiMinor <= 0) return [];
    const int segments = 36;
    List<LatLng> points = [];
    const double metersPerLatDegree = 111319.9;
    double metersPerLonDegree = metersPerLatDegree * math.cos(centerLat * math.pi / 180);
    double alpha = orientationDeg * math.pi / 180;

    for (int i = 0; i <= segments; i++) {
        double t = (i / segments) * 2 * math.pi;
        double dx = semiMajor * math.cos(t) * math.sin(alpha) + semiMinor * math.sin(t) * math.cos(alpha);
        double dy = semiMajor * math.cos(t) * math.cos(alpha) - semiMinor * math.sin(t) * math.sin(alpha);
        double dLat = dy / metersPerLatDegree;
        double dLon = dx / metersPerLonDegree;
        points.add(LatLng(centerLat + dLat, centerLon + dLon));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GnssProvider>(
      builder: (context, gnssProvider, child) {
        final latitude = gnssProvider.latitudeDeg;
        final longitude = gnssProvider.longitudeDeg;
        final elevation = gnssProvider.altitude;
        final latStdDev = double.tryParse(gnssProvider.latStdDev);
        final lonStdDev = double.tryParse(gnssProvider.lonStdDev);
        final eleStdDev = double.tryParse(gnssProvider.altStdDev);
        final ellipseOrientation = double.tryParse(gnssProvider.ellipseOrientation);
        final semiMajor = double.tryParse(gnssProvider.ellipseSemiMajor);
        final semiMinor = double.tryParse(gnssProvider.ellipseSemiMinor);

        final initialCenter = LatLng(
          latitude ?? 39.9042,
          longitude ?? 116.4074,
        );
        
        List<LatLng> ellipsePoints = [];
        if (latitude != null && longitude != null) {
           double major = semiMajor ?? latStdDev ?? 0;
           double minor = semiMinor ?? lonStdDev ?? 0;
           double orientation = ellipseOrientation ?? 0;
           if (major > 0 && minor > 0) {
              ellipsePoints = _getErrorEllipsePoints(
                 latitude, longitude, major, minor, orientation);
           }
        }

        double measureDist = 0;
        double measureBear = 0;
        List<LatLng> measureLinePoints = [];
        if (_measureState != MeasureState.idle && _measureStartPoint != null) {
          LatLng? target;
          if (_measureState == MeasureState.measuring) {
            if (latitude != null && longitude != null) {
              target = LatLng(latitude, longitude);
            }
          } else if (_measureState == MeasureState.finished) {
            target = _measureEndPoint;
          }
          if (target != null) {
            measureLinePoints = [_measureStartPoint!, target];
            const Distance distance = Distance(roundResult: false);
            measureDist = distance.as(LengthUnit.Meter, _measureStartPoint!, target);
            measureBear = _calculateBearing(_measureStartPoint!, target);
          }
        }

        return _buildMap(
          context,
          initialCenter,
          latitude,
          longitude,
          elevation,
          latStdDev,
          lonStdDev,
          eleStdDev,
          ellipsePoints,
          measureLinePoints,
          measureDist,
          measureBear,
        );
      },
    );
  }

  Widget _buildMap(
    BuildContext context,
    LatLng initialCenter,
    double? latitude,
    double? longitude,
    String? elevation,
    double? latStdDev,
    double? lonStdDev,
    double? eleStdDev,
    List<LatLng> ellipsePoints,
    List<LatLng> measureLinePoints,
    double measureDist,
    double measureBear,
  ) {

    return Scaffold(
      body: Stack(
        children: [
          if (_currentZoom > _rulerZoomThreshold)
            Container(color: Colors.grey.shade200),
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 18.0,
              minZoom: 1.0,
              maxZoom: 27.0,
              onPositionChanged: (position, hasGesture) {
                final newZoom = position.zoom;
                final newRotation = position.rotation;
                final zoomCrossedThreshold = 
                    (_currentZoom <= _rulerZoomThreshold && newZoom > _rulerZoomThreshold) ||
                    (_currentZoom > _rulerZoomThreshold && newZoom <= _rulerZoomThreshold);
                if (newZoom != _currentZoom || newRotation != _currentRotation || zoomCrossedThreshold) {
                  setState(() {
                    _currentZoom = newZoom;
                    _currentRotation = newRotation;
                  });
                }
              },
            ),
            children: [
              if (_currentZoom > _rulerZoomThreshold)
                ColoredBox(
                  color: Colors.grey.shade200,
                  child: const SizedBox.expand(),
                )
              else
                TileLayer(
                  key: ValueKey(_currentBaseMap),
                  urlTemplate: baseMapConfigs[_currentBaseMap]!.urlTemplate,
                  userAgentPackageName: 'com.k96e.frtk'
                ),
              if (measureLinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: measureLinePoints,
                      color: Colors.green,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
              if (ellipsePoints.isNotEmpty)
                 PolygonLayer(
                   polygons: [
                     Polygon(
                       points: ellipsePoints,
                       color: Colors.blue.withOpacity(0.3),
                       borderColor: Colors.blue,
                       borderStrokeWidth: 1.0,
                     ),
                   ],
                 ),
              if (_measureStartPoint != null && _measureState != MeasureState.idle)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _measureStartPoint!,
                      width: 10,
                      height: 10,
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              if (latitude != null && longitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude, longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_currentZoom > _rulerZoomThreshold && latitude != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PolarRulerPainter(
                    zoom: _currentZoom,
                    latitude: latitude,
                    rotation: _currentRotation,
                  ),
                ),
              ),
            ),

          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                   BoxShadow(blurRadius: 4, color: Colors.black26),
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Lat: ${latitude?.toStringAsFixed(8) ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  Text("Lon: ${longitude?.toStringAsFixed(8) ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  Text("Ele: ${elevation ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  if (latStdDev != null || lonStdDev != null || eleStdDev != null) ...[
                      const Divider(height: 4, thickness: 1),
                  ],
                  if (latStdDev != null) Text("LatErr: ${latStdDev.toStringAsFixed(3)} m", style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  if (lonStdDev != null) Text("LonErr: ${lonStdDev.toStringAsFixed(3)} m", style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  if (eleStdDev != null) Text("EleErr: ${eleStdDev.toStringAsFixed(3)} m", style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_measureState != MeasureState.idle)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("距离: ${measureDist.toStringAsFixed(4)} m",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        Text("方位: ${measureBear.toStringAsFixed(2)}°",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                FloatingActionButton(
                  heroTag: "measureTool",
                  mini: true,
                  onPressed: () => _handleMeasureTap(latitude, longitude),
                  backgroundColor: _measureState == MeasureState.measuring
                      ? Colors.orange
                      : (_measureState == MeasureState.finished
                          ? Colors.red
                          : Colors.white),
                  child: Icon(
                    _measureState == MeasureState.idle
                        ? Icons.straighten
                        : (_measureState == MeasureState.measuring
                            ? Icons.pause
                            : Icons.close),
                    color: _measureState == MeasureState.idle
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "centerWifi",
                  mini: true,
                  onPressed: () {
                    if (latitude != null && longitude != null) {
                      _mapController.move(
                        LatLng(latitude, longitude),
                        _mapController.camera.zoom,
                      );
                      _mapController.rotate(0.0);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("暂无定位数据")),
                      );
                    }
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    double newZoom = currentZoom + 1;
                    if (newZoom > 25.0) newZoom = 25.0;
                    _mapController.move(
                        _mapController.camera.center, newZoom);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    double newZoom = currentZoom - 1;
                    if (newZoom < 1.0) newZoom = 1.0;
                    _mapController.move(
                        _mapController.camera.center, newZoom);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: "mapSettings",
              mini: true,
              onPressed: _showBaseMapDialog,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.layers,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
