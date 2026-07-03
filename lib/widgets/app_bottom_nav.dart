import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Ortak alt navigasyon: Tara / Cihazlar / Ayarlar.
/// [currentIndex]: 0=Tara, 1=Cihazlar. Ayarlar bir sekme degil, sheet acar.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.navBg,
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.wifi_find_rounded,
            label: 'Tara',
            selected: currentIndex == 0,
            onTap: () {
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/scan');
              }
            },
          ),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Cihazlar',
            selected: currentIndex == 1,
            onTap: () {
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Ayarlar',
            selected: false,
            onTap: () => _showSettingsSheet(context),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final authService = AuthService();
    final email = authService.currentUser?.email ?? '';
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
            const Text('Ayarlar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(email,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            ListTile(
              leading:
                  const Icon(Icons.add_rounded, color: AppTheme.accentStart),
              title: const Text('Yeni Cihaz Ekle',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/scan');
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppTheme.offline),
              title: const Text('Cikis Yap',
                  style: TextStyle(color: AppTheme.offline)),
              onTap: () async {
                Navigator.pop(ctx);
                await authService.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
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
    final color = selected ? AppTheme.accentStart : Colors.white24;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
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
