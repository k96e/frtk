import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

class DevicePanel extends StatelessWidget {
  const DevicePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '设备管理',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新设备列表'),
                    onPressed: () => deviceProvider.scanDevices(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: deviceProvider.selectedBaudRate,
                decoration: InputDecoration(
                  labelText: '通信波特率',
                  prefixIcon: const Icon(Icons.speed),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  helperText: deviceProvider.isConnected ? '连接状态下无法更改' : null,
                ),
                items: deviceProvider.baudRates.map((int rate) {
                  return DropdownMenuItem<int>(
                    value: rate,
                    child: Text('$rate bps'),
                  );
                }).toList(),
                onChanged: !deviceProvider.isConnected
                    ? (int? newValue) {
                        if (newValue != null) {
                          deviceProvider.setBaudRate(newValue);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              const Text(
                '可用设备',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: deviceProvider.availableDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.usb_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              '未发现串口设备',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请连接GNSS设备后点击刷新',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: deviceProvider.availableDevices.length,
                        itemBuilder: (context, index) {
                          final device = deviceProvider.availableDevices[index];
                          final isConnected = deviceProvider.connectedDevice == device;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                isConnected ? Icons.usb_rounded : Icons.usb,
                                color: isConnected ? Colors.green : Colors.grey,
                                size: 32,
                              ),
                              title: Text(
                                device.productName ?? device.name,
                                style: TextStyle(
                                  fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                device.manufacturer != null 
                                    ? '制造商: ${device.manufacturer}'
                                    : 'ID: ${device.id}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: isConnected
                                  ? ElevatedButton.icon(
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('断开'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[400],
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        await deviceProvider.disconnect();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("已断开连接")),
                                          );
                                        }
                                      },
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.link, size: 16),
                                      label: const Text('连接'),
                                      onPressed: () async {
                                        final success = await deviceProvider.connectTo(device);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? "已连接到 ${device.productName ?? device.name}"
                                                    : "连接失败: ${deviceProvider.status}",
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
