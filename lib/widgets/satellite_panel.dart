import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gnss_provider.dart';

class SatellitePanel extends StatelessWidget {
  const SatellitePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GnssProvider>(
      builder: (context, gnssProvider, child) {
        final satellites = gnssProvider.satelliteList;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '卫星列表',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    avatar: const Icon(Icons.satellite_alt, size: 18),
                    label: Text('共 ${satellites.length} 颗'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: satellites.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无GSV卫星数据',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Card(
                        child: ListView.separated(
                          itemCount: satellites.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sat = satellites[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text(
                                  sat.system.isEmpty ? '?' : sat.system.substring(0, 1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text('${sat.system}  PRN ${sat.prn}'),
                              subtitle: Text(
                                '仰角 ${sat.elevation ?? '--'}°  方位角 ${sat.azimuth ?? '--'}°',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('SNR ${sat.snr ?? '--'}'),
                                  Text(
                                    'Signal ${sat.signalId ?? '--'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
