// lib/screens/provision_screen.dart
//
// DEGISIKLIK: Sadece _provision() fonksiyonu guncellendi.
// Tum UI kodu (dark tema, glass fields, bottom nav) aynen korundu.

import 'package:flutter/material.dart';
import '../services/esp_service.dart';

class ProvisionScreen extends StatefulWidget {
  const ProvisionScreen({super.key});

  @override
  State<ProvisionScreen> createState() => _ProvisionScreenState();
}

class _ProvisionScreenState extends State<ProvisionScreen> {
  final _espService = EspService();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Kullaniciya gosterilen ilerleme mesaji
  String _loadingMsg = 'Baglaniliyor...';

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _darkBg = Color(0xFF060A0F);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ssid = ModalRoute.of(context)?.settings.arguments as String?;
    if (ssid != null) _ssidController.text = ssid;
  }

  // ── GUNCELLENEN KISIM ────────────────────────────────────────
  Future<void> _provision() async {
    if (_ssidController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMsg = 'ESP-01\'e WiFi bilgisi gonderiliyor...';
    });

    // Adim 1: Bilgiyi gonder
    // provision() icinde: gonder → bekle → otomatik IP tara → kaydet
    // Bu islem ~20-30 saniye surebilir, bu yuzden mesaji guncelliyoruz.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _loadingMsg = 'ESP-01 eve WiFi\'ina baglanıyor...');
      }
    });
    Future.delayed(const Duration(seconds: 14), () {
      if (mounted && _isLoading) {
        setState(() => _loadingMsg = 'Cihaz aranıyor, lutfen bekle...');
      }
    });

    final success = await _espService.provision(
      _ssidController.text,
      _passwordController.text,
      _nameController.text.isEmpty ? 'ESP Cihaz' : _nameController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Baglanti Basarili!',
            style: TextStyle(
                color: Color(0xFF00F5FF), fontWeight: FontWeight.bold),
          ),
          content: Text(
            'ESP-01 basariyla aga baglandi ve kaydedildi.\nAna sayfadan roleni kontrol edebilirsin.',
            style: const TextStyle(color: Colors.white70, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              child: const Text(
                'Ana Sayfaya Git →',
                style: TextStyle(
                    color: Color(0xFF00F5FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cihaz bulunamadi. ESP_Setup agina bagli misin? Tekrar dene.',
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
  // ── GUNCELLENEN KISIM SONU ───────────────────────────────────

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // Arka plan glow
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _neonCyan.withOpacity(0.06),
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
                // AppBar
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
                          'Enter Credentials',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Connect to Network',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _ssidController.text.isNotEmpty
                              ? _ssidController.text
                              : 'Home WiFi Network',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                        ),
                        const SizedBox(height: 40),

                        // Form kartı
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: _neonCyan.withOpacity(0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _GlassTextField(
                                controller: _nameController,
                                label: 'Cihaz Adi',
                                hint: 'Salon Lambasi, Yatak Odasi...',
                                icon: Icons.devices_rounded,
                              ),
                              const SizedBox(height: 20),
                              _GlassTextField(
                                controller: _ssidController,
                                label: 'WiFi SSID',
                                hint: 'Network Name',
                                icon: Icons.wifi_rounded,
                              ),
                              const SizedBox(height: 20),
                              _GlassTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Enter password',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              const SizedBox(height: 32),

                              // Bağlan butonu
                              GestureDetector(
                                onTap: _isLoading ? null : _provision,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isLoading
                                          ? [Colors.white12, Colors.white12]
                                          : [
                                              const Color(0xFF00D4E8),
                                              const Color(0xFF00F5FF),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _isLoading
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: _neonCyan.withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _loadingMsg,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Text(
                                            'Connect',
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
    );
  }
}

// ── Glass TextField (degismedi) ──────────────────────────────
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF00F5FF), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    )
                  : null,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bottom Nav (degismedi) ───────────────────────────────────
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
            label: 'Scan',
            selected: currentIndex == 0,
            onTap: () => Navigator.pushReplacementNamed(context, '/scan'),
          ),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: currentIndex == 1,
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: currentIndex == 2,
            onTap: () {},
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
