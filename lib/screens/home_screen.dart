import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../services/esp_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EspService _espService = EspService();
  final AuthService _authService = AuthService();
  List<Device> _devices = [];
  String _userEmail = '';

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _darkBg = Color(0xFF060A0F);

  @override
  void initState() {
    super.initState();
    _userEmail = _authService.currentUser?.email ?? '';
    _listenDevices();
  }

  void _listenDevices() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseDatabase.instance.ref("users/$uid/devices").onValue.listen((event) {
      if (!event.snapshot.exists) {
        setState(() => _devices = []);
        return;
      }
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<Device> devices = [];
      data.forEach((key, value) {
        if (value is Map) {
          devices.add(Device.fromMap(key.toString(), value));
        }
      });
      setState(() => _devices = devices);
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showDeleteDialog(Device device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Cihazi Sil", style: TextStyle(color: Colors.white)),
        content: Text(
          "${device.name} cihazini silmek istiyor musun?\nESP de sifirlancak.",
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Iptal", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Cihaz siliniyor..."),
                  backgroundColor: Colors.orange,
                ),
              );
              await _espService.deleteDevice(device.id);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ayarlar",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _userEmail,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.add_rounded, color: Color(0xFF00F5FF)),
              title: const Text("Yeni Cihaz Ekle",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/scan');
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Cikis Yap",
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _neonCyan.withOpacity(0.05),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
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
                          const Text(
                            "Cihazlarim",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _userEmail.isNotEmpty ? _userEmail : "Smart Home",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/scan'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: _neonCyan.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Color(0xFF00F5FF)),
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
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: 1,
        onSettingsTap: _showSettings,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices_other_rounded,
                size: 50, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 24),
          const Text("Henuz cihaz yok",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Yeni cihaz eklemek icin + butonuna basin",
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/scan'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4E8), Color(0xFF00F5FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _neonCyan.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text("Cihaz Ekle",
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final isOn = device.state == 'ON';
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/control', arguments: device.id),
      onLongPress: () => _showDeleteDialog(device),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn
                ? _neonCyan.withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: isOn
              ? [BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 20)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isOn
                    ? _neonCyan.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOn ? _neonCyan.withOpacity(0.3) : Colors.white12,
                ),
              ),
              child: Icon(
                isOn ? Icons.power_rounded : Icons.power_off_rounded,
                color: isOn ? _neonCyan : const Color(0xFF475569),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn ? _neonCyan : Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOn ? "Acik" : "Kapali",
                        style: TextStyle(
                          color: isOn ? _neonCyan : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              activeColor: _neonCyan,
              activeTrackColor: _neonCyan.withOpacity(0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
              onChanged: (val) async {
                await _espService.toggleRelay(device.id, val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSettingsTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.wifi_find_rounded,
            label: "Scan",
            selected: currentIndex == 0,
            onTap: () => Navigator.pushReplacementNamed(context, '/scan'),
          ),
          _NavItem(
            icon: Icons.home_rounded,
            label: "Home",
            selected: currentIndex == 1,
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: "Settings",
            selected: currentIndex == 2,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00F5FF);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? neonCyan : Colors.white24, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? neonCyan : Colors.white24,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
