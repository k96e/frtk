import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ntrip_provider.dart';
import '../providers/device_provider.dart';
import '../providers/log_provider.dart';

class NtripPanel extends StatefulWidget {
  const NtripPanel({super.key});

  @override
  State<NtripPanel> createState() => _NtripPanelState();
}

class _NtripPanelState extends State<NtripPanel> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _mountController;
  late TextEditingController _userController;
  late TextEditingController _passController;

  @override
  void initState() {
    super.initState();
    final ntripProvider = context.read<NtripProvider>();
    _hostController = TextEditingController(text: ntripProvider.host);
    _portController = TextEditingController(text: ntripProvider.port);
    _mountController = TextEditingController(text: ntripProvider.mountPoint);
    _userController = TextEditingController(text: ntripProvider.username);
    _passController = TextEditingController(text: ntripProvider.password);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mountController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final ntripProvider = context.read<NtripProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final logProvider = context.read<LogProvider>();

    if (ntripProvider.isConnected) {
      ntripProvider.disconnect();
      return;
    }

    FocusScope.of(context).unfocus();
    ntripProvider.updateConfig(
      host: _hostController.text.trim(),
      port: _portController.text.trim(),
      mountPoint: _mountController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text.trim(),
    );

    await ntripProvider.connect(
      onDataReceived: (data) {
        deviceProvider.write(data);
      },
      onLog: (log) {
        logProvider.addLog(log);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NtripProvider>(
      builder: (context, ntripProvider, child) {
        final isConnected = ntripProvider.isConnected;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NTRIP 配置',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isConnected ? Colors.green : Colors.grey),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: isConnected ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ntripProvider.status,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (isConnected)
                            Text(
                              "接收数据: ${ntripProvider.rtcmBytesCount / 1024 > 1 ? 
                              '${(ntripProvider.rtcmBytesCount / 1024).toStringAsFixed(2)} KB' : 
                              '${ntripProvider.rtcmBytesCount} Bytes'}",
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Caster Host (IP/Domain)',
                  border: OutlineInputBorder(),
                ),
                enabled: !isConnected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !isConnected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mountController,
                decoration: const InputDecoration(
                  labelText: 'Mount Point',
                  border: OutlineInputBorder(),
                ),
                enabled: !isConnected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'Username (Optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !isConnected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: 'Password (Optional)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !isConnected,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: Icon(isConnected ? Icons.link_off : Icons.link),
                  label: Text(isConnected ? '断开连接' : '连接 NTRIP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _handleConnect,
                ),
              ),
              if (ntripProvider.rtcmStats.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'RTCM 消息统计',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatsTable(ntripProvider.rtcmStats),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsTable(Map<int, int> stats) {
    final keys = stats.keys.toList()..sort();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          headingRowHeight: 40,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 30,
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Count', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: keys.map((id) {
            return DataRow(cells: [
              DataCell(Text(id.toString())),
              DataCell(Text(stats[id].toString())),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
