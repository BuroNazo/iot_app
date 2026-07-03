import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../services/esp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EspService _espService = EspService();
  List<Device> _devices = [];
  StreamSubscription<DatabaseEvent>? _devicesSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _listenDevices();
    // isOnline zamana bagli: liste 30 sn'de bir tazelenir ki cihaz sustugunda
    // gosterge kendiliginden "cevrimdisi"na dussun.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listenDevices() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _devicesSub = FirebaseDatabase.instance
        .ref('users/$uid/devices')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (!event.snapshot.exists) {
        setState(() => _devices = []);
        return;
      }
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final devices = <Device>[];
      data.forEach((key, value) {
        if (value is Map) {
          devices.add(Device.fromMap(key.toString(), value));
        }
      });
      setState(() => _devices = devices);
    });
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showDeviceMenu(Device device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.offline),
              title: const Text('Cihazi Sil',
                  style: TextStyle(color: AppTheme.offline)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Device device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgMid,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:
            const Text('Cihazi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${device.name} silinsin mi?\nESP cihazi da sifirlanacak.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Iptal', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cihaz siliniyor...'),
                  backgroundColor: Colors.orange,
                ),
              );
              await _espService.deleteDevice(device.id);
            },
            child:
                const Text('Sil', style: TextStyle(color: AppTheme.offline)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cihazlarim',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              'Akilli Ev',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/scan'),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentStart
                                  .withValues(alpha: 0.3),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _devices.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _devices.length,
                        itemBuilder: (ctx, i) =>
                            _buildDeviceCard(_devices[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.glassFillSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(Icons.devices_other_rounded,
                  size: 48, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const Text('Henuz cihaz yok',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Yeni cihaz eklemek icin + butonuna basin',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Cihaz Ekle',
              icon: Icons.add_rounded,
              onTap: () => Navigator.pushNamed(context, '/scan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final isOn = device.state == 'ON';
    final online = device.isOnline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: () =>
            Navigator.pushNamed(context, '/control', arguments: device.id),
        onLongPress: () => _showDeviceMenu(device),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isOn ? AppTheme.accentGradient : null,
                color: isOn ? null : AppTheme.glassFillSubtle,
                shape: BoxShape.circle,
                border: isOn
                    ? null
                    : Border.all(color: AppTheme.glassBorder),
              ),
              child: Icon(
                isOn ? Icons.power_rounded : Icons.power_off_rounded,
                color: isOn ? Colors.white : AppTheme.textMuted,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              online ? AppTheme.online : AppTheme.offline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          online
                              ? (isOn ? 'Acik' : 'Kapali')
                              : 'Cevrimdisi · ${device.lastSeenText}',
                          style: TextStyle(
                            color: online
                                ? (isOn
                                    ? AppTheme.online
                                    : AppTheme.textMuted)
                                : AppTheme.offline,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.accentEnd,
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
              onChanged: (val) async {
                await _espService.toggleRelay(device.id, val);
              },
            ),
            IconButton(
              onPressed: () => _showDeviceMenu(device),
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white38, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
