import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/gnss_provider.dart';
import '../nmea.dart';
import 'dart:math';

class SatellitePanel extends StatefulWidget {
  const SatellitePanel({super.key});

  @override
  State<SatellitePanel> createState() => _SatellitePanelState();
}

class _SatellitePanelState extends State<SatellitePanel> {
  String _selectedSystem = 'BeiDou';

  @override
  Widget build(BuildContext context) {
    return Selector<GnssProvider, List<SatelliteInfo>>(
      selector: (context, provider) => provider.satelliteList,
      shouldRebuild: (previous, next) => !listEquals(previous, next),
      builder: (context, satellites, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, outerConstraints) {
              const double legendHeight = 40.0;
              const double dividerHeight = 16.0;
              const double spacing = 24.0;
              const double minBarChartRatio = 0.20;
              
              final availableHeight = outerConstraints.maxHeight;
              final minBarChartHeight = availableHeight * minBarChartRatio;
              
              final maxSkyplotHeight = availableHeight - minBarChartHeight - 
                                        legendHeight - dividerHeight - spacing;
              
              final size = min(outerConstraints.maxWidth * 0.95, maxSkyplotHeight);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
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
                  ),
                  const SizedBox(height: 8),
                  SatelliteLegend(
                    selectedSystem: _selectedSystem,
                    onSystemSelected: (system) {
                      setState(() {
                        _selectedSystem = system;
                      });
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: satellites.isEmpty
                        ? const Center(
                            child: Text(
                              '暂无GSV卫星数据',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : _SnrBarChart(
                            satellites: satellites,
                            selectedSystem: _selectedSystem,
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SnrBarChart extends StatelessWidget {
  final List<SatelliteInfo> satellites;
  final String selectedSystem;

  const _SnrBarChart({
    required this.satellites,
    required this.selectedSystem,
  });

  @override
  Widget build(BuildContext context) {
    final systemSats =
        satellites.where((s) => s.system == selectedSystem).toList();

    if (systemSats.isEmpty) {
      return Center(
        child: Text('暂无$selectedSystem卫星数据',
            style: const TextStyle(color: Colors.grey)),
      );
    }

    final groups = <int, Map<String, SatelliteInfo>>{};
    for (var sat in systemSats) {
      final prnMap = groups.putIfAbsent(sat.prn, () => {});
      final key = sat.signalId ?? 'UNK';
      if (!prnMap.containsKey(key) ||
          (sat.snr ?? 0) > (prnMap[key]!.snr ?? 0)) {
        prnMap[key] = sat;
      }
    }

    final allSignals = <String>{};
    for (var prnMap in groups.values) {
      allSignals.addAll(prnMap.keys);
    }
    final sortedSignals = allSignals.toList()..sort();

    return Column(
      children: [
        _SignalLegend(signals: sortedSignals, system: selectedSystem),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int totalBars = 0;
              for (var prnMap in groups.values) {
                totalBars += prnMap.length;
              }
              const double minBarWidth = 6.0;
              const double marginH = 40.0;
              final minWidth = totalBars * minBarWidth +
                  (groups.length - 1) * minBarWidth * 1.2 +
                  marginH;
              final paintWidth = max(constraints.maxWidth, minWidth);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CustomPaint(
                  size: Size(paintWidth, constraints.maxHeight),
                  painter: SnrBarChartPainter(
                    groups: groups,
                    sortedSignals: sortedSignals,
                    system: selectedSystem,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SnrBarChartPainter extends CustomPainter {
  final Map<int, Map<String, SatelliteInfo>> groups;
  final List<String> sortedSignals;
  final String system;

  static const Map<String, Map<String, Color>> systemSignalColors = {
    'GPS': {
      'L1 C/A': Color(0xFF0D47A1),
      'L1 P(Y)': Color(0xFF1565C0),
      'L1 M': Color(0xFF1976D2),
      'L2 P(Y)': Color(0xFF1E88E5),
      'L2C-M': Color(0xFF2196F3),
      'L2C-L': Color(0xFF42A5F5),
      'L5-I': Color(0xFF64B5F6),
      'L5-Q': Color(0xFF90CAF9),
    },
    'BeiDou': {
      'B1I': Color(0xFFB71C1C),
      'B1Q': Color(0xFFC62828),
      'B1C': Color(0xFFD32F2F),
      'B1A': Color(0xFFE53935),
      'B2a': Color(0xFFF44336),
      'B2b': Color(0xFFEF5350),
      'B2 a+b': Color(0xFFE57373),
      'B3I': Color(0xFFFF5722),
      'B3Q': Color(0xFFFF7043),
      'B3A': Color(0xFFFF8A65),
      'B2I': Color(0xFFAD1457),
      'B2Q': Color(0xFFD81B60),
    },
    'GLONASS': {
      'G1 C/A': Color(0xFF1B5E20),
      'G1 P': Color(0xFF2E7D32),
      'G2 C/A': Color(0xFF43A047),
      'G2 P': Color(0xFF66BB6A),
    },
    'Galileo': {
      'E5a': Color(0xFFE65100),
      'E5b': Color(0xFFEF6C00),
      'E5 a+b': Color(0xFFF57C00),
      'E6-A': Color(0xFFFB8C00),
      'E6-BC': Color(0xFFFF9800),
      'L1-A': Color(0xFFFFA726),
      'L1-BC': Color(0xFFFFB74D),
    },
    'QZSS': {
      'L1 C/A': Color(0xFF4A148C),
      'L1C (D)': Color(0xFF6A1B9A),
      'L1C (P)': Color(0xFF7B1FA2),
      'L1S': Color(0xFF8E24AA),
      'L2C-M': Color(0xFF9C27B0),
      'L2C-L': Color(0xFFAB47BC),
      'L5-I': Color(0xFFBA68C8),
      'L5-Q': Color(0xFFCE93D8),
      'L6D': Color(0xFF7C4DFF),
      'L6E': Color(0xFFB388FF),
    },
  };

  static const List<Color> _fallbackColors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFF6D4C41),
    Color(0xFF78909C),
  ];

  SnrBarChartPainter({
    required this.groups,
    required this.sortedSignals,
    required this.system,
  });

  Color _getSignalColor(String signalId) {
    final systemColors = systemSignalColors[system];
    if (systemColors != null && systemColors.containsKey(signalId)) {
      return systemColors[signalId]!;
    }
    final idx = sortedSignals.indexOf(signalId);
    return _fallbackColors[idx % _fallbackColors.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 32;
    const double bottomMargin = 24;
    const double topMargin = 10;
    const double rightMargin = 8;
    const double maxSnr = 60;

    const chartLeft = leftMargin;
    final chartRight = size.width - rightMargin;
    const chartTop = topMargin;
    final chartBottom = size.height - bottomMargin;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // --- 绘制网格与坐标轴 ---
    final gridPaint = Paint()
      ..color = const Color(0x33999999)
      ..strokeWidth = 0.5;
    final axisPaint = Paint()
      ..color = const Color(0x88999999)
      ..strokeWidth = 1;

    for (int snr = 0; snr <= maxSnr.toInt(); snr += 10) {
      final y = chartBottom - (snr / maxSnr) * chartHeight;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$snr',
          style: const TextStyle(color: Color(0xFF757575), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 4, y - tp.height / 2));
    }

    canvas.drawLine(
        const Offset(chartLeft, chartTop), Offset(chartLeft, chartBottom), axisPaint);
    canvas.drawLine(
        Offset(chartLeft, chartBottom), Offset(chartRight, chartBottom), axisPaint);

    // --- 准备数据 ---
    final sortedPrns = groups.keys.toList()..sort();
    if (sortedPrns.isEmpty) return;

    final int totalGroups = sortedPrns.length;
    int totalBars = 0;
    for (var prn in sortedPrns) {
      totalBars += groups[prn]!.length;
    }

    // 自适应柱宽：所有柱子 + 组间间距均分可用宽度
    final double totalUnits = totalBars + (totalGroups - 1) * 1.2;
    double barWidth = chartWidth / totalUnits;
    barWidth = barWidth.clamp(4.0, 28.0);
    final double groupGap = barWidth * 1.2;

    // 计算实际总宽度并居中
    double totalBarWidth = 0;
    for (var prn in sortedPrns) {
      totalBarWidth += groups[prn]!.length * barWidth;
    }
    final double totalWidth = totalBarWidth + (totalGroups - 1) * groupGap;
    double curX = chartLeft + (chartWidth - totalWidth) / 2;

    for (var prn in sortedPrns) {
      final prnSignals = groups[prn]!;
      final signalKeys = prnSignals.keys.toList()
        ..sort((a, b) =>
            sortedSignals.indexOf(a).compareTo(sortedSignals.indexOf(b)));

      final groupStartX = curX;

      for (var key in signalKeys) {
        final sat = prnSignals[key]!;
        final snr = (sat.snr ?? 0).clamp(0, maxSnr.toInt()).toDouble();
        final barHeight = (snr / maxSnr) * chartHeight;

        final color = _getSignalColor(key);
        final barPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        final barRect = Rect.fromLTWH(
          curX,
          chartBottom - barHeight,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            barRect,
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          barPaint,
        );

        curX += barWidth;
      }

      // PRN 标签居中显示在组下方
      final groupEndX = curX;
      final groupCenterX = (groupStartX + groupEndX) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '$prn',
          style: const TextStyle(color: Color(0xFF616161), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(groupCenterX - tp.width / 2, chartBottom + 4));

      curX += groupGap;
    }
  }

  @override
  bool shouldRepaint(covariant SnrBarChartPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.sortedSignals != sortedSignals ||
        oldDelegate.system != system;
  }
}

class _SignalLegend extends StatelessWidget {
  final List<String> signals;
  final String system;

  const _SignalLegend({required this.signals, required this.system});

  @override
  Widget build(BuildContext context) {
    final systemColors = SnrBarChartPainter.systemSignalColors[system] ?? {};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: signals.map((sig) {
          final color = systemColors[sig] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(sig, style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SatelliteLegend extends StatelessWidget {
  final String selectedSystem;
  final ValueChanged<String> onSystemSelected;

  const SatelliteLegend({
    super.key,
    required this.selectedSystem,
    required this.onSystemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          LegendItem(
              label: 'GPS',
              shape: BoxShape.circle,
              color: Colors.blue,
              isSelected: selectedSystem == 'GPS',
              onTap: () => onSystemSelected('GPS'),
            ),
          const SizedBox(width: 2),
          LegendItem(
            label: 'BeiDou',
            shape: BoxShape.rectangle,
            color: Colors.red,
            isSelected: selectedSystem == 'BeiDou',
            onTap: () => onSystemSelected('BeiDou'),
          ),
          const SizedBox(width: 2),
          LegendItem(
            label: 'GLONASS',
            isTriangle: true,
            color: Colors.green,
            isSelected: selectedSystem == 'GLONASS',
            onTap: () => onSystemSelected('GLONASS'),
          ),
          const SizedBox(width: 2),
          LegendItem(
            label: 'Galileo',
            icon: Icons.close,
            color: Colors.orange,
            isSelected: selectedSystem == 'Galileo',
            onTap: () => onSystemSelected('Galileo'),
          ),
          const SizedBox(width: 2),
          LegendItem(
            label: 'QZSS',
            icon: Icons.star,
            color: Colors.purple,
            isSelected: selectedSystem == 'QZSS',
            onTap: () => onSystemSelected('QZSS'),
          ),
        ]),
      )
    );
  }
}

class LegendItem extends StatelessWidget {
  final String label;
  final BoxShape? shape;
  final IconData? icon;
  final Color color;
  final bool isTriangle;
  final bool isSelected;
  final VoidCallback? onTap;

  const LegendItem({
    super.key,
    required this.label,
    required this.color,
    this.shape,
    this.icon,
    this.isTriangle = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
