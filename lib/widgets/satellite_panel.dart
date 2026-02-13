import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/gnss_provider.dart';
import '../nmea.dart';
import 'dart:math';

class SatellitePanel extends StatelessWidget {
  const SatellitePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<GnssProvider, List<SatelliteInfo>>(
      selector: (context, provider) => provider.satelliteList,
      shouldRebuild: (previous, next) => !listEquals(previous, next),
      builder: (context, satellites, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth * 0.95;
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: CustomPaint(
                        painter: SkyplotPainter(
                          satellites: satellites,
                          primaryColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // 图例区域
              const SatelliteLegend(),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: satellites.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无GSV卫星数据',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _SatelliteListView(satellites: satellites),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SatelliteListView extends StatelessWidget {
  final List<SatelliteInfo> satellites;

  const _SatelliteListView({required this.satellites});

  @override
  Widget build(BuildContext context) {
    final Map<String, _SatelliteGroup> groups = {};

    for (var sat in satellites) {
      final key = '${sat.system}-${sat.prn}';
      if (!groups.containsKey(key)) {
        groups[key] = _SatelliteGroup(
          system: sat.system,
          prn: sat.prn,
          elevation: sat.elevation,
          azimuth: sat.azimuth,
        );
      }
      var group = groups[key]!;
      if (group.elevation == null && sat.elevation != null) {
        group = group.copyWith(elevation: sat.elevation);
        groups[key] = group;
      }
      if (group.azimuth == null && sat.azimuth != null) {
        group = group.copyWith(azimuth: sat.azimuth);
        groups[key] = group;
      }

      group.signals.add(sat);
    }

    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final systemCompare = a.system.compareTo(b.system);
        if (systemCompare != 0) return systemCompare;
        return a.prn.compareTo(b.prn);
      });

    return ListView.builder(
      itemCount: sortedGroups.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final group = sortedGroups[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          elevation: 1,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SatelliteIcon(system: group.system),
                    const SizedBox(width: 8),
                    Text(
                      '${group.system} ${group.prn}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '仰角: ${group.elevation ?? '--'}°',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '方位角: ${group.azimuth ?? '--'}°',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.signals.map((sig) {
                    final snr = sig.snr ?? 0;
                    Color snrColor;
                    if (snr >= 40) {
                      snrColor = Colors.green;
                    } else if (snr >= 30) {
                      snrColor = Colors.orange;
                    } else {
                      snrColor = Colors.grey;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sig.signalId ?? 'UNK',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: snrColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '${sig.snr ?? '--'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: snrColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SatelliteGroup {
  final String system;
  final int prn;
  final int? elevation;
  final int? azimuth;
  final List<SatelliteInfo> signals;

  _SatelliteGroup({
    required this.system,
    required this.prn,
    this.elevation,
    this.azimuth,
    List<SatelliteInfo>? signals,
  }) : signals = signals ?? [];

  _SatelliteGroup copyWith({
    String? system,
    int? prn,
    int? elevation,
    int? azimuth,
    List<SatelliteInfo>? signals,
  }) {
    return _SatelliteGroup(
      system: system ?? this.system,
      prn: prn ?? this.prn,
      elevation: elevation ?? this.elevation,
      azimuth: azimuth ?? this.azimuth,
      signals: signals ?? this.signals,
    );
  }
}

class SatelliteLegend extends StatelessWidget {
  const SatelliteLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        LegendItem(label: 'GPS', shape: BoxShape.circle, color: Colors.blue),
        LegendItem(
            label: 'BeiDou',
            shape: BoxShape.rectangle,
            color: Colors.red),
        LegendItem(
            label: 'GLONASS',
            isTriangle: true,
            color: Colors.green),
        LegendItem(
            label: 'Galileo', icon: Icons.close, color: Colors.orange),
        LegendItem(
            label: 'Other', icon: Icons.star, color: Colors.purple),
      ],
    );
  }
}

class LegendItem extends StatelessWidget {
  final String label;
  final BoxShape? shape;
  final IconData? icon;
  final Color color;
  final bool isTriangle;

  const LegendItem({
    super.key,
    required this.label,
    required this.color,
    this.shape,
    this.icon,
    this.isTriangle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: color)
        else if (isTriangle)
          SizedBox(
            width: 12,
            height: 12,
            child: CustomPaint(
              painter: _TrianglePainter(color: color),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: shape ?? BoxShape.circle,
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class SatelliteIcon extends StatelessWidget {
  final String system;
  const SatelliteIcon({super.key, required this.system});

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    Color color = Colors.grey;
    bool isSquare = false;
    bool isTriangle = false;

    if (system == 'GPS') {
      color = Colors.blue;
    } else if (system == 'BeiDou') {
      isSquare = true;
      color = Colors.red;
    } else if (system == 'GLONASS') {
      isTriangle = true;
      color = Colors.green;
    } else if (system == 'Galileo') {
      icon = Icons.close;
      color = Colors.orange;
    } else {
      icon = Icons.star;
      color = Colors.purple;
    }

    if (icon != null) {
      double iconSize = 24.0;
      if (system == 'Galileo') {
        iconSize = 20.0;
      }
      return Icon(icon, color: color, size: iconSize);
    } else if (isSquare) {
      return Container(width: 18, height: 18, color: color);
    } else if (isTriangle) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(
          painter: _TrianglePainter(color: color),
        ),
      );
    } else {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
  }
}

class SkyplotPainter extends CustomPainter {
  final List<SatelliteInfo> satellites;
  final Color primaryColor;
  late final List<SatelliteInfo> _uniqueSatellites;

  SkyplotPainter({required this.satellites, required this.primaryColor}) {
    final uniqueMap = <String, SatelliteInfo>{};
    for (var sat in satellites) {
      if (sat.elevation == null || sat.azimuth == null) continue;
      if (!uniqueMap.containsKey(sat.uniqueKey)) {
        uniqueMap[sat.uniqueKey] = sat;
      }
    }
    _uniqueSatellites = uniqueMap.values.toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 2 / 3, gridPaint);
    canvas.drawCircle(center, radius * 1 / 3, gridPaint);

    for (int i = 0; i < 360; i += 45) {
      final angle = (i - 90) * pi / 180;
      final start = center;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(start, end, axisPaint);
    }

    _drawText(canvas, 'N', center.dx, center.dy - radius - 10, Colors.black);
    _drawText(canvas, 'S', center.dx, center.dy + radius + 10, Colors.black);
    _drawText(canvas, 'E', center.dx + radius + 10, center.dy, Colors.black);
    _drawText(canvas, 'W', center.dx - radius - 10, center.dy, Colors.black);

    for (var sat in _uniqueSatellites) {
      final r = radius * (1 - sat.elevation! / 90.0);
      final angle = (sat.azimuth! - 90) * pi / 180; 

      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      final pos = Offset(x, y);

      const double satSize = 8.0;

      Color color;
      if (sat.system == 'GPS') {
        color = Colors.blue;
      } else if (sat.system == 'BeiDou') {
        color = Colors.red;
      } else if (sat.system == 'GLONASS') {
        color = Colors.green;
      } else if (sat.system == 'Galileo') {
        color = Colors.orange;
      } else {
        color = Colors.purple;
      }
      _drawSatelliteShape(canvas, pos, sat.system, color, satSize);
      final textSpan = TextSpan(
        text: sat.prn.toString(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textOffset = Offset(
          x - textPainter.width / 2, y - textPainter.height / 2);

      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawSatelliteShape(
      Canvas canvas, Offset center, String system, Color color, double size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; 

    switch (system) {
      case 'GPS':
        canvas.drawCircle(center, size, paint);
        break;
      case 'BeiDou':
        canvas.drawRect(
            Rect.fromCenter(
                center: center, width: size * 1.8, height: size * 1.8),
            paint);
        break;
      case 'GLONASS':
        final path = Path();
        final h = size * 2.0;
        path.moveTo(center.dx, center.dy - h * 0.577);
        path.lineTo(center.dx + h / 2, center.dy + h * 0.289);
        path.lineTo(center.dx - h / 2, center.dy + h * 0.289);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case 'Galileo':
        final d = size * 0.7;
        canvas.drawLine(Offset(center.dx - d, center.dy - d),
            Offset(center.dx + d, center.dy + d), strokePaint);
        canvas.drawLine(Offset(center.dx + d, center.dy - d),
            Offset(center.dx - d, center.dy + d), strokePaint);
        break;
      default:
        final path = Path();
        for (int i = 0; i < 10; i++) {
          double angle = -pi / 2 + i * pi / 5;
          double r = (i.isEven) ? size : size * 0.4;
          double x = center.dx + r * cos(angle);
          double y = center.dy + r * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: 12),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant SkyplotPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        !listEquals(oldDelegate.satellites, satellites);
  }
}
