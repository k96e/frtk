import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/gnss_provider.dart';
import 'providers/ntrip_provider.dart';
import 'providers/log_provider.dart';
import 'provider_coordinator.dart';
import 'map.dart';
import 'widgets/device_panel.dart';
import 'widgets/data_panel.dart';
import 'widgets/log_panel.dart';
import 'widgets/ntrip_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => GnssProvider()),
        ChangeNotifierProvider(create: (_) => NtripProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRTK',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GpsUsbPage(),
    );
  }
}

class GpsUsbPage extends StatefulWidget {
  const GpsUsbPage({super.key});

  @override
  State<GpsUsbPage> createState() => _GpsUsbPageState();
}

class _GpsUsbPageState extends State<GpsUsbPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  
  late ProviderCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coordinator = ProviderCoordinator();
      _coordinator.initialize(context);
    });
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            const Divider(height: 1),
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                accountName: const Text(
                  "FRTK Manager",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(deviceProvider.connectedDevice?.productName ?? "未连接设备"),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.satellite_alt_rounded, size: 40, color: Colors.blue),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.usb),
                title: const Text('设备管理'),
                selected: _selectedIndex == 0,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('数据显示'),
                selected: _selectedIndex == 1,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('地图定位'),
                selected: _selectedIndex == 4,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync),
                title: const Text('NTRIP 设置'),
                selected: _selectedIndex == 3,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('原始日志'),
                selected: _selectedIndex == 2,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar() {
    return Consumer2<DeviceProvider, GnssProvider>(
      builder: (context, deviceProvider, gnssProvider, child) {
        final connectedDevice = deviceProvider.connectedDevice;
        final status = deviceProvider.status;
        final quality = gnssProvider.quality;
        final satellites = gnssProvider.satellites;

        Color statusColor;
        IconData statusIcon;
        
        if (connectedDevice != null) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
        } else if (status.contains("正在")) {
          statusColor = Colors.orange;
          statusIcon = Icons.sync;
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.cancel;
        }

        return InkWell(
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.menu, color: Colors.black54),
                const SizedBox(width: 16),
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connectedDevice?.productName ?? "无设备连接",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (connectedDevice != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: quality.contains("RTK") ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: quality.contains("RTK") ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          quality,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: quality.contains("RTK") ? Colors.green[700] : Colors.orange[800],
                          ),
                        ),
                        Text(
                          "卫星: $satellites",
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DevicePanel();
      case 1:
        return const DataPanel();
      case 2:
        return const LogPanel();
      case 3:
        return const NtripPanel();
      case 4:
        return const MapPage();
      default:
        return const Center(child: Text('未知面板'));
    }
  }
}