import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gnss_provider.dart';

class DataPanel extends StatelessWidget {
  const DataPanel({super.key});

  String _getDms(String formattedPos) {
    if (!formattedPos.contains("°")) return "";
    try {
      final parts = formattedPos.split("°");
      final double val = double.parse(parts[0].trim());
      final String dir = parts[1].trim();
      int d = val.floor();
      double mTotal = (val - d) * 60;
      int m = mTotal.floor();
      double s = (mTotal - m) * 60;
      return "$d° $m' ${s.toStringAsFixed(4)}\" $dir";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GnssProvider>(
      builder: (context, gnssProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GNSS 数据',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildBigLocationRow(
                        '纬度',
                        gnssProvider.latitude,
                        Icons.south,
                        _getDms(gnssProvider.latitude),
                      ),
                      const Divider(height: 16),
                      _buildBigLocationRow(
                        '经度',
                        gnssProvider.longitude,
                        Icons.east,
                        _getDms(gnssProvider.longitude),
                      ),
                      const Divider(height: 16),
                      _buildBigLocationRow(
                        '海拔',
                        gnssProvider.altitude,
                        Icons.terrain,
                        '',
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAccuracyColumn(
                                '纬度误差', gnssProvider.latStdDev),
                          ),
                          Expanded(
                            child: _buildAccuracyColumn(
                                '经度误差', gnssProvider.lonStdDev),
                          ),
                          Expanded(
                            child: _buildAccuracyColumn(
                                '高程误差', gnssProvider.altStdDev),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSpeedCourseCard(gnssProvider.speed, gnssProvider.course),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'UTC 时间',
                      gnssProvider.time,
                      Icons.access_time,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      'HDOP',
                      gnssProvider.hdop,
                      Icons.location_searching,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedCourseCard(String speedVal, String courseVal) {
    double rotation = 0.0;
    if (courseVal != "--") {
      try {
        rotation = double.parse(courseVal) * (3.1415926535 / 180.0);
      } catch (_) {}
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.speed, color: Colors.orange, size: 28),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text('速度',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: speedVal == "--"
                          ? const Text(
                              "--",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'monospace',
                              ),
                            )
                          : RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: speedVal,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const TextSpan(
                                    text: " km/h",
                                    style: TextStyle(
                                      fontSize: 14, // 缩小字号
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.grey.withOpacity(0.3),
                indent: 10,
                endIndent: 10,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Transform.rotate(
                          angle: rotation,
                          child: const Icon(Icons.navigation,
                              color: Colors.indigo, size: 28),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text('航向',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        courseVal == "--" ? "--" : "$courseVal°",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigLocationRow(
      String label, String value, IconData icon, String dms) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Icon(icon, color: Colors.blue, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
              if (dms.isNotEmpty)
                Text(
                  dms,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value == "--" ? "--" : "${value}m",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
