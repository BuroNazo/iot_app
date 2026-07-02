import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/esp_service.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_sheet.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with SingleTickerProviderStateMixin {
  final EspService _espService = EspService();
  final ScheduleService _scheduleService = ScheduleService();
  bool _relayStatus = false;
  bool _isOnline = false;
  bool _isLoading = false;
  String _deviceName = "Smart Switch";
  String _deviceId = "";
  late AnimationController _glowController;

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _neonPurple = Color(0xFF7C3AED);
  static const Color _darkBg = Color(0xFF060A0F);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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

    FirebaseDatabase.instance
        .ref("users/$uid/devices/$_deviceId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _relayStatus = data['state'] == 'ON';
        _deviceName = data['name'] ?? 'Smart Switch';
        _isOnline = true;
      });
    });
  }

  Future<void> _toggleRelay() async {
    setState(() => _isLoading = true);
    await _espService.toggleRelay(_deviceId, !_relayStatus);
    setState(() => _isLoading = false);
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:
            const Text("Cihazi Sifirla", style: TextStyle(color: Colors.white)),
        content: const Text(
          "ESP-01 WiFi bilgisini unutacak ve kurulum moduna donecek. Emin misiniz?",
          style: TextStyle(color: Color(0xFF94A3B8)),
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
                  content: Text("Sifirlaniyor... Lutfen bekleyin."),
                  backgroundColor: Colors.orange,
                ),
              );
              await _espService.resetDevice(_deviceId);
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (_) => false);
              }
            },
            child: const Text("Sifirla",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ScheduleSheet(deviceId: _deviceId),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (_, __) {
              return Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_relayStatus ? _neonCyan : Colors.white12)
                              .withOpacity(0.06 + _glowController.value * 0.04),
                          blurRadius: 120,
                          spreadRadius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white60, size: 20),
                      ),
                      const Expanded(
                        child: Text(
                          "Device Control",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              letterSpacing: 1),
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
                const Text(
                  "Smart Switch",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _deviceName,
                  style: TextStyle(
                    color: _neonCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Kontrol Kartı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _relayStatus
                            ? _neonCyan.withOpacity(0.3)
                            : Colors.white.withOpacity(0.06),
                      ),
                      boxShadow: _relayStatus
                          ? [
                              BoxShadow(
                                color: _neonCyan.withOpacity(0.1),
                                blurRadius: 40,
                                spreadRadius: 10,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Status: ",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 16)),
                            Text(
                              _relayStatus ? "ON" : "OFF",
                              style: TextStyle(
                                color:
                                    _relayStatus ? _neonCyan : Colors.white38,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Ampul
                            Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _glowController,
                                  builder: (_, __) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _relayStatus
                                            ? _neonCyan.withOpacity(0.12 +
                                                _glowController.value * 0.08)
                                            : Colors.white.withOpacity(0.04),
                                        border: Border.all(
                                          color: _relayStatus
                                              ? _neonCyan.withOpacity(0.3)
                                              : Colors.white12,
                                        ),
                                        boxShadow: _relayStatus
                                            ? [
                                                BoxShadow(
                                                  color: _neonCyan.withOpacity(
                                                      0.3 +
                                                          _glowController
                                                                  .value *
                                                              0.1),
                                                  blurRadius: 30,
                                                  spreadRadius: 4,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Icon(
                                        _relayStatus
                                            ? Icons.lightbulb_rounded
                                            : Icons.lightbulb_outline_rounded,
                                        color: _relayStatus
                                            ? _neonCyan
                                            : Colors.white24,
                                        size: 40,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _relayStatus ? "Glowing" : "Off",
                                  style: TextStyle(
                                    color: _relayStatus
                                        ? _neonCyan
                                        : Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),

                            // Toggle
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: _isLoading ? null : _toggleRelay,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 80,
                                    height: 48,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: _relayStatus
                                          ? const LinearGradient(colors: [
                                              Color(0xFF5B21B6),
                                              Color(0xFF7C3AED)
                                            ])
                                          : null,
                                      color: _relayStatus
                                          ? null
                                          : const Color(0xFF1F2937),
                                      boxShadow: _relayStatus
                                          ? [
                                              BoxShadow(
                                                color: _neonPurple
                                                    .withOpacity(0.4),
                                                blurRadius: 16,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: AnimatedAlign(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      alignment: _relayStatus
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _relayStatus
                                              ? Colors.white
                                              : Colors.white38,
                                        ),
                                        child: _isLoading
                                            ? const Padding(
                                                padding: EdgeInsets.all(10),
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.purple),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _relayStatus
                                      ? "Relay Activated"
                                      : "Relay Off",
                                  style: TextStyle(
                                    color: _relayStatus
                                        ? _neonPurple
                                        : Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Cihaz Bilgisi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(label: "Device", value: _deviceName),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: "ID",
                          value: _deviceId.length >= 8
                              ? _deviceId.substring(0, 8)
                              : _deviceId,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: "Signal",
                          value: _isOnline ? "Strong" : "Offline",
                          valueColor:
                              _isOnline ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Zamanlama
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Zamanlama",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _showAddScheduleSheet,
                            icon: const Icon(Icons.add_circle_rounded,
                                color: _neonCyan),
                          ),
                        ],
                      ),
                      StreamBuilder<List<Schedule>>(
                        stream: _scheduleService.schedulesStream(_deviceId),
                        builder: (context, snapshot) {
                          final schedules = snapshot.data ?? [];
                          if (schedules.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                "Henuz zamanlama yok",
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13),
                              ),
                            );
                          }
                          return Column(
                            children: schedules
                                .map((s) => _ScheduleRow(
                                      schedule: s,
                                      onEnabledChanged: (value) =>
                                          _scheduleService.setEnabled(
                                              _deviceId, s.id, value),
                                      onDelete: () => _scheduleService
                                          .deleteSchedule(_deviceId, s.id),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Online göstergesi
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? Colors.greenAccent.withOpacity(0.1)
                        : Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isOnline
                          ? Colors.greenAccent.withOpacity(0.4)
                          : Colors.redAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isOnline ? Colors.greenAccent : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (_isOnline
                                      ? Colors.greenAccent
                                      : Colors.redAccent)
                                  .withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? "ONLINE" : "OFFLINE",
                        style: TextStyle(
                          color:
                              _isOnline ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 1),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

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
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
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

class _ScheduleRow extends StatelessWidget {
  final Schedule schedule;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  const _ScheduleRow({
    required this.schedule,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(
            schedule.type == ScheduleType.time
                ? Icons.schedule_rounded
                : Icons.timer_rounded,
            color: Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              schedule.summary,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Switch(
            value: schedule.enabled,
            activeColor: const Color(0xFF00F5FF),
            onChanged: onEnabledChanged,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }
}
