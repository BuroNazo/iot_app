import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wifi_service.dart';
import '../models/wifi_network.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/aurora_background.dart';
import '../widgets/gradient_button.dart';

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
  Timer? _espPollTimer;

  // ESP AP adı — ESP kodundaki AP_SSID ile aynı olmalı
  static const String _espApName = "OZDSOFT_ESPSetup";

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
        backgroundColor: AppTheme.bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Izin Gerekli",
            style: TextStyle(
                color: AppTheme.accentStart, fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: AppTheme.accentStart)),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgMid,
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
                style: TextStyle(color: AppTheme.accentStart)),
          ),
        ],
      ),
    );
  }

  void _handleEspFound() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "ESP Cihazi Bulundu!",
          style: TextStyle(
              color: AppTheme.accentStart, fontWeight: FontWeight.bold),
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
                  color: AppTheme.accentStart, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _pollForEspConnection() {
    _espPollTimer?.cancel();
    int attempts = 0;
    _espPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final connected = await _wifiService.isConnectedToSetupAP();
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (connected) {
        timer.cancel();
        Navigator.pushNamed(context, '/provision');
      }
      if (++attempts >= 15) timer.cancel();
    });
  }

  @override
  void dispose() {
    _espPollTimer?.cancel();
    _radarController.dispose();
    _wifiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: const Column(
                  children: [
                    Text(
                      "CIHAZ KURULUMU",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 2),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Yakindaki Aglar",
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
                            color: AppTheme.accentStart.withValues(alpha: 0.08),
                            blurRadius: 60,
                            spreadRadius: 30,
                          ),
                          BoxShadow(
                            color: AppTheme.accentEnd.withValues(alpha: 0.06),
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
                          final color = Color.lerp(
                              AppTheme.accentStart, AppTheme.accentEnd, phase)!;
                          return SizedBox(
                            width: size,
                            height: size,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: opacity * 0.8),
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
                          colors: [AppTheme.bgTop, AppTheme.bgMid],
                        ),
                        border: Border.all(
                            color: AppTheme.accentStart.withValues(alpha: 0.4),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppTheme.accentStart.withValues(alpha: 0.3),
                              blurRadius: 20),
                        ],
                      ),
                      child: const Icon(Icons.wifi_find_rounded,
                          color: AppTheme.accentStart, size: 32),
                    ),
                  ],
                ),
              ),

              Text(
                _isScanning
                    ? "Cihazlar araniyor..."
                    : "${_networks.length} ag bulundu",
                style: TextStyle(
                  color: _isScanning ? AppTheme.accentStart : Colors.white54,
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
                    color: AppTheme.glassFill,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _networks.isEmpty
                        ? Center(
                            child: _isScanning
                                ? const CircularProgressIndicator(
                                    color: AppTheme.accentStart)
                                : const Text("Ag bulunamadi",
                                    style: TextStyle(color: Colors.white38)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _networks.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Colors.white.withValues(alpha: 0.05),
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
                child: GradientButton(
                  label: 'Tekrar Tara',
                  icon: Icons.wifi_rounded,
                  onTap: _startScan,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  final WifiNetwork network;
  final String espApName;
  final VoidCallback onTap;

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
              ? AppTheme.accentStart.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEsp
                ? AppTheme.accentStart.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          Icons.wifi_rounded,
          color: isEsp ? AppTheme.accentStart : Colors.white54,
          size: 20,
        ),
      ),
      title: Text(
        network.ssid,
        style: TextStyle(
          color: isEsp ? AppTheme.accentStart : Colors.white,
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
          color: isEsp
              ? AppTheme.accentStart.withValues(alpha: 0.7)
              : Colors.white38,
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
            color: active ? AppTheme.accentStart : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
