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

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with SingleTickerProviderStateMixin {
  final EspService _espService = EspService();
  Device? _device;
  String _deviceId = '';
  StreamSubscription<DatabaseEvent>? _deviceSub;
  Timer? _refreshTimer;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _listenDevice();
    }
  }

  void _listenDevice() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _deviceSub?.cancel();
    _deviceSub = FirebaseDatabase.instance
        .ref('users/$uid/devices/$_deviceId')
        .onValue
        .listen((event) {
      if (!mounted || !event.snapshot.exists) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() => _device = Device.fromMap(_deviceId, data));
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _refreshTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _togglePower() async {
    final device = _device;
    if (device == null) return;
    await _espService.toggleRelay(_deviceId, device.state != 'ON');
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgMid,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cihazi Sifirla',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'ESP-01 WiFi bilgisini unutacak ve kurulum moduna donecek. Emin misiniz?',
          style: TextStyle(color: AppTheme.textMuted),
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
                  content: Text('Sifirlaniyor... Lutfen bekleyin.'),
                  backgroundColor: Colors.orange,
                ),
              );
              await _espService.resetDevice(_deviceId);
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (_) => false);
              }
            },
            child: const Text('Sifirla',
                style: TextStyle(color: AppTheme.offline)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final isOn = device?.state == 'ON';
    final isPending = device != null && device.command != device.state;
    final online = device?.isOnline ?? false;

    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white60, size: 20),
                    ),
                    const Expanded(
                      child: Text(
                        'CIHAZ KONTROL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            letterSpacing: 2),
                      ),
                    ),
                    IconButton(
                      onPressed: _showResetDialog,
                      icon: const Icon(Icons.settings_rounded,
                          color: Colors.white38, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                device?.name ?? 'Yukleniyor...',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? AppTheme.online : AppTheme.offline,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online
                        ? 'Cevrimici'
                        : 'Cevrimdisi · ${device?.lastSeenText ?? ''}',
                    style: TextStyle(
                      color: online ? AppTheme.online : AppTheme.offline,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Hero guc dugmesi
              AnimatedBuilder(
                animation: _glowController,
                builder: (_, __) {
                  final glow =
                      isOn ? 0.25 + _glowController.value * 0.15 : 0.0;
                  return GestureDetector(
                    onTap: isPending ? null : _togglePower,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.glassFillSubtle,
                        border: Border.all(
                          color: isOn
                              ? AppTheme.accentStart.withValues(alpha: 0.6)
                              : AppTheme.glassBorder,
                          width: 1.5,
                        ),
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentStart
                                      .withValues(alpha: glow),
                                  blurRadius: 50,
                                  spreadRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 126,
                          height: 126,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                isOn ? AppTheme.accentGradient : null,
                            color: isOn ? null : AppTheme.glassFill,
                            boxShadow: isOn
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentStart
                                          .withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: isPending
                                ? const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3),
                                  )
                                : Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.power_settings_new_rounded,
                                        color: isOn
                                            ? Colors.white
                                            : AppTheme.textMuted,
                                        size: 44,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isOn ? 'ACIK' : 'KAPALI',
                                        style: TextStyle(
                                          color: isOn
                                              ? Colors.white
                                              : AppTheme.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Durum hapi
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: (isOn ? AppTheme.online : AppTheme.textMuted)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isOn ? AppTheme.online : AppTheme.textMuted)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isPending
                      ? 'KOMUT GONDERILDI...'
                      : (isOn ? 'ROLE AKTIF' : 'ROLE KAPALI'),
                  style: TextStyle(
                    color: isOn ? AppTheme.online : AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),

              // Bilgi cipleri
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        label: 'Cihaz ID',
                        value: _deviceId.length >= 8
                            ? _deviceId.substring(0, 8)
                            : _deviceId,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        label: 'Son gorulme',
                        value: device?.lastSeenText ?? '—',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
