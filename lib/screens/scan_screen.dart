import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wifi_service.dart';
import '../models/wifi_network.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final WifiService _wifiService = WifiService();
  late AnimationController _radarController;
  List<WifiNetwork> _networks = [];
  bool _isScanning = false;

  // ESP AP adı — ESP kodundaki AP_SSID ile aynı olmalı
  static const String _espApName = "OZDSOFT_ESPSetup";

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _neonPurple = Color(0xFF7C3AED);
  static const Color _cardBg = Color(0xFF0D1117);
  static const Color _darkBg = Color(0xFF060A0F);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _networks = [];
    });

    final granted = await _wifiService.requestPermissions();

    if (!granted && mounted) {
      setState(() => _isScanning = false);
      _showPermissionDialog();
      return;
    }

    final results = await _wifiService.scan();

    if (!mounted) return;

    if (results.isEmpty) {
      _showLocationServiceDialog();
    }

    setState(() {
      _networks = results;
      _isScanning = false;
    });

    if (results.any((n) => n.ssid == _espApName)) {
      _handleEspFound();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Izin Gerekli",
            style: TextStyle(
                color: Color(0xFF00F5FF), fontWeight: FontWeight.bold)),
        content: const Text(
          "WiFi aglarini taramak icin Konum izni gereklidir.\nAyarlar'dan uygulamaya Konum izni verin.",
          style: TextStyle(color: Colors.white70, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _wifiService.openLocationSettings();
            },
            child: const Text("Ayarlari Ac",
                style: TextStyle(color: Color(0xFF00F5FF))),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Konum Servisi Kapali",
            style: TextStyle(
                color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          "Android, WiFi taramasi icin Konum Servisinin acik olmasini zorunlu kilar.\nLutfen Konum'u acip tekrar deneyin.",
          style: TextStyle(color: Colors.white70, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tamam", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _wifiService.openLocationSettings();
            },
            child: const Text("Konum Ayarlari",
                style: TextStyle(color: Color(0xFF00F5FF))),
          ),
        ],
      ),
    );
  }

  void _handleEspFound() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "ESP Cihazi Bulundu!",
          style:
              TextStyle(color: Color(0xFF00F5FF), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "1. 'WiFi Ayarlari'na git\n"
          "2. '$_espApName' agina baglan\n"
          "3. Geri don — uygulama otomatik devam eder.",
          style: TextStyle(color: Colors.white70, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _wifiService.openWifiSettings();
              _pollForEspConnection();
            },
            child: const Text(
              "WiFi Ayarlarini Ac",
              style: TextStyle(
                  color: Color(0xFF00F5FF), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _pollForEspConnection() {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final connected = await _wifiService.isConnectedToSetupAP();
      if (connected) {
        timer.cancel();
        if (mounted) Navigator.pushNamed(context, '/provision');
      }
      if (++attempts >= 15) timer.cancel();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _wifiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
            child: const Column(
              children: [
                Text(
                  "Device Provisioning",
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12, letterSpacing: 2),
                ),
                SizedBox(height: 8),
                Text(
                  "Nearby Networks",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Radar Animasyonu
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _neonCyan.withOpacity(0.08),
                        blurRadius: 60,
                        spreadRadius: 30,
                      ),
                      BoxShadow(
                        color: _neonPurple.withOpacity(0.06),
                        blurRadius: 80,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
                ...List.generate(4, (i) {
                  return AnimatedBuilder(
                    animation: _radarController,
                    builder: (_, __) {
                      final phase = (_radarController.value + i / 4) % 1.0;
                      final size = 40 + phase * 160;
                      final opacity = (1 - phase).clamp(0.0, 1.0);
                      final color = Color.lerp(_neonCyan, _neonPurple, phase)!;
                      return SizedBox(
                        width: size,
                        height: size,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withOpacity(opacity * 0.8),
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2744), Color(0xFF0D1117)],
                    ),
                    border: Border.all(
                        color: _neonCyan.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: _neonCyan.withOpacity(0.3), blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.wifi_find_rounded,
                      color: Color(0xFF00F5FF), size: 32),
                ),
              ],
            ),
          ),

          Text(
            _isScanning
                ? "Scanning for Devices..."
                : "${_networks.length} networks found",
            style: TextStyle(
              color: _isScanning ? _neonCyan : Colors.white54,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),

          // Ağ Listesi
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _networks.isEmpty
                    ? Center(
                        child: _isScanning
                            ? const CircularProgressIndicator(
                                color: Color(0xFF00F5FF))
                            : const Text("No networks found",
                                style: TextStyle(color: Colors.white38)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _networks.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.05),
                          height: 1,
                          indent: 70,
                        ),
                        itemBuilder: (_, i) => _NetworkTile(
                          network: _networks[i],
                          espApName: _espApName,
                          onTap: () {
                            if (_networks[i].ssid == _espApName) {
                              _handleEspFound();
                            } else {
                              Navigator.pushNamed(context, '/provision',
                                  arguments: _networks[i].ssid);
                            }
                          },
                        ),
                      ),
              ),
            ),
          ),

          // Tara Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _NeonButton(
              label: "Scan Again",
              icon: Icons.wifi_rounded,
              onTap: _startScan,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  final WifiNetwork network;
  final String espApName;
  final VoidCallback onTap;
  static const _neonCyan = Color(0xFF00F5FF);

  const _NetworkTile({
    required this.network,
    required this.espApName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEsp = network.ssid == espApName;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isEsp
              ? _neonCyan.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEsp ? _neonCyan.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Icon(
          Icons.wifi_rounded,
          color: isEsp ? _neonCyan : Colors.white54,
          size: 20,
        ),
      ),
      title: Text(
        network.ssid,
        style: TextStyle(
          color: isEsp ? _neonCyan : Colors.white,
          fontWeight: isEsp ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        isEsp
            ? "ESP Cihazi — Baglamak icin tiklayin"
            : network.isSecure
                ? (network.signalStrength > 60
                    ? "Guvenli, Guclu Sinyal"
                    : "Guvenli, Orta Sinyal")
                : "Acik Ag",
        style: TextStyle(
          color: isEsp ? _neonCyan.withOpacity(0.7) : Colors.white38,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (network.isSecure && !isEsp)
            const Icon(Icons.lock_rounded, color: Colors.white38, size: 14),
          const SizedBox(width: 8),
          _SignalBars(strength: network.signalStrength),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int strength;
  const _SignalBars({required this.strength});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = strength > (i * 25);
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 4,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00F5FF) : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NeonButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4E8), Color(0xFF00F5FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00F5FF).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alt Navigasyon ────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

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
            onTap: () => _showSettings(context),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
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
            const Text(
              "Ayarlar",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: Color(0xFF00F5FF)),
              title: const Text("Ana Sayfa",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.wifi_find_rounded, color: Color(0xFF00F5FF)),
              title: const Text("Yeni Cihaz Ekle",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/scan');
              },
            ),
          ],
        ),
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
