# Hata Düzeltmeleri + Aurora Glass Yeniden Tasarım Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanılmayan zamanlama özelliğini kaldırmak, denetimde bulunan hataları (dinleyici/Timer sızıntıları, sahte çevrimiçi göstergesi, mounted eksikleri, bozuk Settings navigasyonu, deprecated API'ler, bozuk test) düzeltmek ve 5 ekranın tamamını "Aurora Glass" görsel diline taşımak.

**Architecture:** Ortak tema sabitleri `lib/theme/app_theme.dart`'a, tekrar eden UI parçaları (`AuroraBackground`, `GlassCard`, `GradientButton`, `AppBottomNav`) `lib/widgets/` altına toplanır; her ekran bu ortak parçaları kullanarak yeniden yazılır. Gerçek çevrimiçi göstergesi için ESP firmware'i `lastSeen`'e Firebase sunucu zamanı (`.sv: timestamp`) yazar ve ~30 sn'de bir heartbeat gönderir; `Device` modeli bundan `isOnline` türetir.

**Tech Stack:** Flutter/Dart (mevcut uygulama), firebase_database/auth/core (mevcut), flutter_test. Yeni pub bağımlılığı YOK.

**Spec:** `docs/superpowers/specs/2026-07-03-redesign-and-fixes-design.md`

---

## Dosya Yapısı

**Silinecek:**
- `lib/models/schedule.dart`, `test/models/schedule_test.dart`
- `lib/services/schedule_service.dart`, `lib/widgets/schedule_sheet.dart`
- `functions/` (tüm dizin), `.github/workflows/relay-schedule.yml`
- `test/widget_test.dart`

**Yeni:**
- `lib/theme/app_theme.dart` — tüm renk/degrade sabitleri
- `lib/widgets/aurora_background.dart` — zemin + aurora ışık kümeleri
- `lib/widgets/glass_card.dart` — buzlu cam kart
- `lib/widgets/gradient_button.dart` — degrade buton (loading destekli)
- `lib/widgets/app_bottom_nav.dart` — ortak alt navigasyon + ayarlar sheet'i
- `test/models/device_test.dart` — Device modeli birim testleri

**Değişecek:**
- `lib/models/device.dart` — `isOnlineAt`/`isOnline`/`lastSeenText` eklenir
- `lib/screens/login_screen.dart`, `home_screen.dart`, `control_screen.dart`, `scan_screen.dart`, `provision_screen.dart` — Aurora Glass ile yeniden yazılır
- `firmware/esp01/esp01_firmware/esp01_firmware.ino` — lastSeen sunucu zamanı + heartbeat

**Değişmeyecek:** `lib/main.dart`, `lib/services/*` (auth/esp/wifi), `lib/firebase_options.dart`, `firebase.json`, `database.rules.json`, `lib/models/wifi_network.dart`.

---

### Task 1: Zamanlama özelliğini kaldır

**Files:**
- Delete: `lib/models/schedule.dart`, `test/models/schedule_test.dart`, `lib/services/schedule_service.dart`, `lib/widgets/schedule_sheet.dart`, `functions/` (dizin), `.github/workflows/relay-schedule.yml`
- Modify: `lib/screens/control_screen.dart`

- [ ] **Step 1: Dosyaları sil**

```bash
git rm -r lib/models/schedule.dart test/models/schedule_test.dart lib/services/schedule_service.dart lib/widgets/schedule_sheet.dart functions .github/workflows/relay-schedule.yml
```

Not: `functions/node_modules` git'te takip edilmiyor; `git rm` sonrası diskte kalırsa `rm -rf functions` ile temizle.

- [ ] **Step 2: control_screen.dart'tan zamanlama kodunu çıkar**

`lib/screens/control_screen.dart` içinde şu değişiklikleri yap (Edit tool ile, anchor bazlı):

(a) Import bloğundaki şu 3 satırı sil:

```dart
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_sheet.dart';
```

(b) Şu alanı sil:

```dart
  final ScheduleService _scheduleService = ScheduleService();
```

(c) `_showAddScheduleSheet` metodunun tamamını sil (`void _showAddScheduleSheet() {` satırından, metodu kapatan `}` satırına kadar — `dispose()` metodundan hemen önce biter).

(d) `// Zamanlama` yorumuyla başlayan `Padding(...)` bloğunun tamamını ve hemen ardından gelen `const SizedBox(height: 16),` satırını sil (blok `// Cihaz Bilgisi` kartından sonraki `const SizedBox(height: 16),` ile `// Online göstergesi` arasında yer alır — yani araya eklenmiş "Zamanlama" `Padding` + bir `SizedBox` çifti kalkar, `Cihaz Bilgisi` kartı ile `Online göstergesi` arasında tek `SizedBox(height: 16)` kalır).

(e) Dosyanın sonundaki `class _ScheduleRow extends StatelessWidget { ... }` sınıfının tamamını sil.

- [ ] **Step 3: Derleme/analiz doğrulaması**

Run: `flutter analyze lib/screens/control_screen.dart`
Expected: Yeni hata YOK (dosyanın mevcut info-level `withOpacity` uyarıları kalabilir — onlar Task 6'da temizlenecek). `Undefined name` benzeri error seviyesinde hiçbir şey olmamalı.

Run: `flutter test`
Expected: `test/widget_test.dart` başarısızlığı BİLİNEN ve bu görevden bağımsız (Task 8'de kaldırılacak); onun dışında kalan testler geçmeli.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat!: zamanlama ozelligi tamamen kaldirildi"
```

---

### Task 2: Tema ve ortak widget altyapısı

**Files:**
- Create: `lib/theme/app_theme.dart`
- Create: `lib/widgets/aurora_background.dart`
- Create: `lib/widgets/glass_card.dart`
- Create: `lib/widgets/gradient_button.dart`
- Create: `lib/widgets/app_bottom_nav.dart`

Bu görev saf UI altyapısıdır; widget testleri yazılmaz (mevcut konvansiyon: Firebase'siz saf model mantığı test edilir, UI manuel doğrulanır). Doğrulama `flutter analyze` ile.

- [ ] **Step 1: `lib/theme/app_theme.dart` oluştur**

```dart
import 'package:flutter/material.dart';

/// Aurora Glass tema sabitleri — tum ekranlar renkleri buradan alir.
abstract final class AppTheme {
  // Zemin degradesi
  static const Color bgTop = Color(0xFF1B2743);
  static const Color bgMid = Color(0xFF0D1321);
  static const Color bgBottom = Color(0xFF090D18);

  // Aurora isik kumeleri
  static const Color auroraPurple = Color(0xFF7C3AED);
  static const Color auroraBlue = Color(0xFF38BDF8);

  // Vurgu degradesi
  static const Color accentStart = Color(0xFF38BDF8);
  static const Color accentEnd = Color(0xFF818CF8);
  static const LinearGradient accentGradient =
      LinearGradient(colors: [accentStart, accentEnd]);

  // Durum renkleri
  static const Color online = Color(0xFF34D399);
  static const Color offline = Color(0xFFF87171);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF8B96B5);

  // Cam yuzeyler (withValues const olamadigi icin final)
  static final Color glassFill = Colors.white.withValues(alpha: 0.07);
  static final Color glassBorder = Colors.white.withValues(alpha: 0.14);
  static final Color glassFillSubtle = Colors.white.withValues(alpha: 0.05);

  // Alt navigasyon zemini
  static const Color navBg = Color(0xFF0D1321);
}
```

- [ ] **Step 2: `lib/widgets/aurora_background.dart` oluştur**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Koyu lacivert zemin + iki aurora isik kumesi. Ekran icerigi [child]
/// olarak verilir; SafeArea'yi ekranin kendisi ekler.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -1.0),
          radius: 1.8,
          colors: [AppTheme.bgTop, AppTheme.bgMid, AppTheme.bgBottom],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _AuroraBlob(color: AppTheme.auroraPurple, size: 320),
          ),
          Positioned(
            bottom: -60,
            left: -70,
            child: _AuroraBlob(color: AppTheme.auroraBlue, size: 280),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AuroraBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: `lib/widgets/glass_card.dart` oluştur**

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Buzlu cam kart: blur + yari saydam dolgu + ince kenarlik.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null && onLongPress == null) return card;
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
```

- [ ] **Step 4: `lib/widgets/gradient_button.dart` oluştur**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mavi-mor degrade ana eylem butonu; [isLoading] iken spinner gosterir
/// ve dokunmalari yoksayar.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: isLoading ? null : AppTheme.accentGradient,
          color: isLoading ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.accentStart.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `lib/widgets/app_bottom_nav.dart` oluştur**

Ortak alt navigasyon. Settings artik HER ekranda ayni ayar sheet'ini acar (bozuk '/home' yonlendirmesi hatasi burada kalici olarak cozulur).

```dart
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
```

- [ ] **Step 6: Analiz doğrulaması**

Run: `flutter analyze lib/theme lib/widgets`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/theme lib/widgets
git commit -m "feat: Aurora Glass tema sabitleri ve ortak widget altyapisi"
```

---

### Task 3: Device modeli — gerçek çevrimiçi durumu (TDD)

**Files:**
- Modify: `lib/models/device.dart`
- Create: `test/models/device_test.dart`

- [ ] **Step 1: Başarısız testi yaz**

`test/models/device_test.dart` oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/device.dart';

void main() {
  // 2026-07-03 civari gercekci bir epoch-ms
  const nowMs = 1783100000000;

  Device device({int lastSeen = 0, String state = 'OFF'}) {
    return Device.fromMap('dev1', {
      'name': 'Test Cihaz',
      'state': state,
      'command': state,
      'lastSeen': lastSeen,
    });
  }

  group('Device.fromMap', () {
    test('parses fields with defaults', () {
      final d = Device.fromMap('abc', {});
      expect(d.id, 'abc');
      expect(d.name, 'ESP Cihaz');
      expect(d.state, 'OFF');
      expect(d.command, 'OFF');
      expect(d.lastSeen, 0);
    });
  });

  group('Device.isOnlineAt', () {
    test('online when lastSeen is within 90 seconds', () {
      final d = device(lastSeen: nowMs - 30 * 1000);
      expect(d.isOnlineAt(nowMs), true);
    });

    test('offline when lastSeen is older than 90 seconds', () {
      final d = device(lastSeen: nowMs - 120 * 1000);
      expect(d.isOnlineAt(nowMs), false);
    });

    test('offline when lastSeen is 0 (never seen)', () {
      final d = device(lastSeen: 0);
      expect(d.isOnlineAt(nowMs), false);
    });

    test('offline for legacy uptime-millis values (not epoch)', () {
      // Eski firmware millis() yazar: kucuk sayilar (< ~2001 epochu)
      final d = device(lastSeen: 393660);
      expect(d.isOnlineAt(nowMs), false);
    });
  });

  group('Device.lastSeenTextAt', () {
    test('reports unknown for 0 or legacy values', () {
      expect(device(lastSeen: 0).lastSeenTextAt(nowMs), 'Bilinmiyor');
      expect(device(lastSeen: 393660).lastSeenTextAt(nowMs), 'Bilinmiyor');
    });

    test('reports simdi within a minute', () {
      final d = device(lastSeen: nowMs - 20 * 1000);
      expect(d.lastSeenTextAt(nowMs), 'Simdi');
    });

    test('reports minutes ago', () {
      final d = device(lastSeen: nowMs - 5 * 60 * 1000);
      expect(d.lastSeenTextAt(nowMs), '5 dk once');
    });

    test('reports hours ago', () {
      final d = device(lastSeen: nowMs - 3 * 60 * 60 * 1000);
      expect(d.lastSeenTextAt(nowMs), '3 sa once');
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/models/device_test.dart`
Expected: FAIL — `isOnlineAt`/`lastSeenTextAt` tanımlı değil (derleme hatası).

- [ ] **Step 3: `lib/models/device.dart`'ı güncelle**

Dosyanın tam yeni içeriği:

```dart
class Device {
  final String id;
  final String name;
  final String state;
  final String command;
  final int lastSeen; // epoch ms (yeni firmware) veya 0/legacy-millis (eski)

  /// Bu sureden daha eski gorulen cihaz cevrimdisi sayilir.
  static const int onlineThresholdMs = 90 * 1000;

  /// Bundan kucuk lastSeen degerleri epoch olamaz (eski firmware millis()
  /// yazardi) — "hic gorulmedi" kabul edilir. 2001-09-09 epochu.
  static const int _minValidEpochMs = 1000000000000;

  Device({
    required this.id,
    required this.name,
    required this.state,
    required this.command,
    required this.lastSeen,
  });

  factory Device.fromMap(String id, Map<dynamic, dynamic> map) {
    return Device(
      id: id,
      name: map['name'] ?? 'ESP Cihaz',
      state: map['state'] ?? 'OFF',
      command: map['command'] ?? 'OFF',
      lastSeen: map['lastSeen'] ?? 0,
    );
  }

  bool get hasValidLastSeen => lastSeen >= _minValidEpochMs;

  bool isOnlineAt(int nowMs) =>
      hasValidLastSeen && nowMs - lastSeen < onlineThresholdMs;

  bool get isOnline => isOnlineAt(DateTime.now().millisecondsSinceEpoch);

  String lastSeenTextAt(int nowMs) {
    if (!hasValidLastSeen) return 'Bilinmiyor';
    final diff = nowMs - lastSeen;
    if (diff < 60 * 1000) return 'Simdi';
    if (diff < 60 * 60 * 1000) return '${diff ~/ (60 * 1000)} dk once';
    if (diff < 24 * 60 * 60 * 1000) {
      return '${diff ~/ (60 * 60 * 1000)} sa once';
    }
    return '${diff ~/ (24 * 60 * 60 * 1000)} gun once';
  }

  String get lastSeenText =>
      lastSeenTextAt(DateTime.now().millisecondsSinceEpoch);
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/models/device_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/device.dart test/models/device_test.dart
git commit -m "feat: Device modeline gercek cevrimici durumu (isOnline/lastSeenText) eklendi"
```

---

### Task 4: Login ekranı — Aurora Glass

**Files:**
- Modify: `lib/screens/login_screen.dart` (tamamen yeniden yazılır)

- [ ] **Step 1: Dosyayı yeniden yaz**

`lib/screens/login_screen.dart` tam yeni içerik:

```dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email ve sifre bos birakilamaz.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = _isRegister
        ? await _authService.register(
            _emailController.text.trim(), _passwordController.text)
        : await _authService.signInWithEmail(
            _emailController.text.trim(), _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      body: AuroraBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.accentStart.withValues(alpha: 0.35),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.electrical_services_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      _isRegister ? 'Hesap Olustur' : 'Hosgeldiniz',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isRegister
                          ? 'Akilli evine katil'
                          : 'Akilli evine giris yap',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 36),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      children: [
                        _GlassTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'ornek@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _GlassTextField(
                          controller: _passwordController,
                          label: 'Sifre',
                          hint: 'En az 6 karakter',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.offline.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.offline
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.offline, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: AppTheme.offline,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GradientButton(
                          label: _isRegister ? 'Kayit Ol' : 'Giris Yap',
                          isLoading: _isLoading,
                          onTap: _handleEmailAuth,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isRegister = !_isRegister;
                        _errorMessage = null;
                      }),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                          children: [
                            TextSpan(
                                text: _isRegister
                                    ? 'Zaten hesabin var mi? '
                                    : 'Hesabin yok mu? '),
                            TextSpan(
                              text: _isRegister ? 'Giris Yap' : 'Kayit Ol',
                              style: const TextStyle(
                                  color: AppTheme.accentStart,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('veya',
                            style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 16,
                    onTap: _isLoading ? null : _handleGoogleSignIn,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white),
                            child: const Center(
                              child: Text('G',
                                  style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Google ile Giris Yap',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassFillSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.accentStart, size: 20),
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
```

- [ ] **Step 2: Analiz doğrulaması**

Run: `flutter analyze lib/screens/login_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "feat: login ekrani Aurora Glass tasarimina tasindi"
```

---

### Task 5: Home ekranı — Aurora Glass + dinleyici düzeltmesi + gerçek durum

**Files:**
- Modify: `lib/screens/home_screen.dart` (tamamen yeniden yazılır)

Düzeltilen hatalar: RTDB dinleyici sızıntısı (StreamSubscription + dispose), sahte durum yerine `Device.isOnline`, keşfedilemeyen uzun-basma yerine ⋮ menü (uzun basma da korunur), kopya `_BottomNav` yerine ortak `AppBottomNav`.

- [ ] **Step 1: Dosyayı yeniden yaz**

`lib/screens/home_screen.dart` tam yeni içerik:

```dart
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
```

- [ ] **Step 2: Analiz doğrulaması**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: home ekrani Aurora Glass'a tasindi; dinleyici sizintisi ve sahte durum duzeltildi"
```

---

### Task 6: Kontrol ekranı — hero güç düğmesi + dinleyici düzeltmesi

**Files:**
- Modify: `lib/screens/control_screen.dart` (tamamen yeniden yazılır)

Düzeltilen hatalar: dinleyici sızıntısı, sahte ONLINE göstergesi, bozuk Settings navigasyonu (ortak `AppBottomNav`), deprecated API'ler. Kullanıcının seçtiği "Varyant 1": merkezde büyük dairesel güç düğmesi. `command != state` iken bekleme animasyonu gösterilir.

- [ ] **Step 1: Dosyayı yeniden yaz**

`lib/screens/control_screen.dart` tam yeni içerik:

```dart
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
```

- [ ] **Step 2: Analiz doğrulaması**

Run: `flutter analyze lib/screens/control_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/control_screen.dart
git commit -m "feat: kontrol ekrani hero guc dugmesiyle Aurora Glass'a tasindi; dinleyici ve durum hatalari duzeltildi"
```

---

### Task 7: Scan ve Provision ekranları — Aurora Glass + Timer düzeltmesi

**Files:**
- Modify: `lib/screens/scan_screen.dart`
- Modify: `lib/screens/provision_screen.dart`

Bu görev iki ekranı da mevcut yapıları koruyarak yeni görsel dile taşır. `scan_screen.dart`'ta ayrıca `_pollForEspConnection` Timer sızıntısı düzeltilir. Her iki ekranda kopya `_BottomNav`/`_NavItem` sınıfları silinip ortak `AppBottomNav` kullanılır.

- [ ] **Step 1: `scan_screen.dart`'ı güncelle**

Yapılacak değişiklikler (mevcut dosya üzerinde Edit ile; radar animasyonu ve tarama mantığı korunur):

(a) Import bloğunu şu hale getir:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wifi_service.dart';
import '../models/wifi_network.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/aurora_background.dart';
import '../widgets/gradient_button.dart';
```

(b) State sınıfına Timer alanı ekle ve `_pollForEspConnection`'ı düzelt:

```dart
  Timer? _espPollTimer;
```

```dart
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
```

`dispose()` içine `_espPollTimer?.cancel();` ekle (`_radarController.dispose();` satırından önce).

(c) Renk sabitlerini değiştir: sınıf içindeki `_neonCyan`, `_neonPurple`, `_cardBg`, `_darkBg` static const'larını sil; dosya genelinde:
- `_neonCyan` → `AppTheme.accentStart`
- `_neonPurple` → `AppTheme.accentEnd`
- `_cardBg` → `AppTheme.glassFill` kullanan `GlassCard`'a geçilmediği yerlerde `AppTheme.bgMid`
- `_darkBg` → `AppTheme.bgBottom`
- Tüm `withOpacity(x)` → `withValues(alpha: x)`
- Hard-coded `Color(0xFF00F5FF)` kullanılan yerler (dialog başlıkları, `_NetworkTile._neonCyan`, `_SignalBars`, `CircularProgressIndicator`) → `AppTheme.accentStart`
- Dialog `backgroundColor: const Color(0xFF111827)` → `AppTheme.bgMid`

(d) `build()` gövdesini `AuroraBackground` ile sar: `Scaffold(backgroundColor: AppTheme.bgBottom, body: AuroraBackground(child: SafeArea(child: <mevcut Column>)))`. Başlıkları Türkçeleştir: `"Device Provisioning"` → `"CIHAZ KURULUMU"`, `"Nearby Networks"` → `"Yakindaki Aglar"`, `"Scanning for Devices..."` → `"Cihazlar araniyor..."`, `"N networks found"` → `"N ag bulundu"`, `"No networks found"` → `"Ag bulunamadi"`.

(e) Ağ listesi kabındaki `Container(decoration: BoxDecoration(color: _cardBg, ...))` yerine cam görünüm: `color: AppTheme.glassFill, border: Border.all(color: AppTheme.glassBorder)` (blur olmadan da kabul edilebilir — liste kaydırma performansı için BackdropFilter'dan kaçınılır).

(f) `_NeonButton` sınıfını sil; "Scan Again" yerine `GradientButton(label: 'Tekrar Tara', icon: Icons.wifi_rounded, onTap: _startScan)` kullan.

(g) Dosyanın sonundaki `_BottomNav`, `_NavItem` sınıflarını ve `_showSettings` metodunu tamamen sil; `bottomNavigationBar: const AppBottomNav(currentIndex: 0)` kullan.

- [ ] **Step 2: Scan analiz doğrulaması**

Run: `flutter analyze lib/screens/scan_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: `provision_screen.dart`'ı güncelle**

Aynı desen:

(a) Import bloğuna ekle:

```dart
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
```

(b) `_neonCyan`/`_darkBg` static const'larını sil; tüm kullanımlar `AppTheme.accentStart`/`AppTheme.bgBottom`; tüm `withOpacity(x)` → `withValues(alpha: x)`; dialog arka planı `AppTheme.bgMid`; dialog/başarı başlığı rengi `AppTheme.accentStart`.

(c) `build()` gövdesini `AuroraBackground` ile sar (Task 7 Step 1-d ile aynı desen). Başlıkları Türkçeleştir: `'Enter Credentials'` → `'BILGILERI GIRIN'`, `'Connect to Network'` → `'Aga Baglan'`, `'Home WiFi Network'` → `'Ev WiFi Agi'`, `'Connect'` → `'Baglan'`, `'Password'` → `'Sifre'`, `'Network Name'` → `'Ag adi'`, `'Enter password'` → `'Sifreyi girin'`.

(d) Form kartı `Container(...)` yerine `GlassCard(padding: const EdgeInsets.all(24), borderRadius: 24, child: ...)`.

(e) Bağlan butonu: mevcut `GestureDetector`+`AnimatedContainer` bloğu korunur AMA degrade `AppTheme.accentGradient` olur ve loading yazı/spinner düzeni aynı kalır (çok satırlı loading mesajı `GradientButton`'da olmadığı için buton bu ekranda yerinde özelleştirilmiş kalır); renkler: yazı `Colors.white`, gölge `AppTheme.accentStart.withValues(alpha: 0.4)`.

(f) `_GlassTextField` içindeki `Color(0xFF00F5FF)` → `AppTheme.accentStart`, `withOpacity` → `withValues`.

(g) Dosyanın sonundaki `_BottomNav`/`_NavItem` sınıflarını sil; `bottomNavigationBar: const AppBottomNav(currentIndex: 0)`.

- [ ] **Step 4: Provision analiz doğrulaması**

Run: `flutter analyze lib/screens/provision_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/scan_screen.dart lib/screens/provision_screen.dart
git commit -m "feat: tarama ve kurulum ekranlari Aurora Glass'a tasindi; Timer sizintisi duzeltildi"
```

---

### Task 8: Bozuk widget testini değiştir + tüm proje doğrulaması

**Files:**
- Delete: `test/widget_test.dart`
- (Testler zaten Task 3'te eklendi: `test/models/device_test.dart`)

- [ ] **Step 1: Bozuk testi sil**

```bash
git rm test/widget_test.dart
```

Gerekçe: test, uygulamanın gerçek akışıyla eşleşmiyor (var olmayan "Searching for ESP" metnini arıyor) ve `Esp01App` Firebase başlatma gerektirdiği için gerçek bir widget smoke testi emulator olmadan yazılamaz. Modelin gerçek birim testleri `test/models/device_test.dart`'ta.

- [ ] **Step 2: Tüm proje analizi**

Run: `flutter analyze`
Expected: `No issues found!` — hiçbir error/warning/info kalmamalı (tüm `withOpacity`/`activeColor` kullanımları önceki görevlerde temizlendi).

- [ ] **Step 3: Tüm testler**

Run: `flutter test`
Expected: Tüm testler geçer (`device_test.dart`), başarısız test yok.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: bozuk widget_test kaldirildi; analiz ve testler temiz"
```

---

### Task 9: ESP firmware — lastSeen sunucu zamanı + heartbeat

**Files:**
- Modify: `firmware/esp01/esp01_firmware/esp01_firmware.ino`

Uygulamadaki gerçek çevrimiçi göstergesi bu firmware değişikliğine bağlıdır: `lastSeen` artık Firebase'in kendi sunucu saati (`{".sv":"timestamp"}` → epoch ms) ile yazılır ve cihaz ~30 saniyede bir "yaşıyorum" sinyali gönderir.

- [ ] **Step 1: `firebaseSetState`'i güncelle**

Şu bloğu:

```cpp
  String body = "{\"state\":\"" + state +
                "\",\"lastSeen\":" + String(millis()) + "}";
  http.PATCH(body);
```

şu şekilde değiştir:

```cpp
  String body = "{\"state\":\"" + state +
                "\",\"lastSeen\":{\".sv\":\"timestamp\"}}";
  http.PATCH(body);
```

- [ ] **Step 2: Heartbeat fonksiyonu ekle**

`firebaseSetState` fonksiyonunun kapanışından hemen sonra şu fonksiyonu ekle:

```cpp
// ~30 saniyede bir "yasiyorum" sinyali: lastSeen'e Firebase sunucu
// zamanini yazar. Uygulama bununla gercek cevrimici durumu gosterir.
void firebaseHeartbeat() {
  if (firebaseUid.isEmpty()) return;

  BearSSL::WiFiClientSecure* client = createSecureClient();
  HTTPClient http;
  String url = "https://" + String(FIREBASE_HOST) +
               getFirebasePath() + ".json";

  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(8000);
  http.PATCH("{\"lastSeen\":{\".sv\":\"timestamp\"}}");
  http.end();
  delete client;
}
```

- [ ] **Step 3: Heartbeat'i döngüye bağla**

Global değişkenler bölümüne (`unsigned long lastPoll = 0;` satırından sonra) ekle:

```cpp
unsigned long lastHeartbeat = 0;
#define HEARTBEAT_INTERVAL 30000
```

`pollFirebase()` fonksiyonunun başındaki `lastPoll = millis();` satırından hemen sonra ekle:

```cpp
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    firebaseHeartbeat();
  }
```

- [ ] **Step 4: `firebaseRegisterDevice` gövdesini güncelle**

Şu bloğu:

```cpp
  String body = "{\"name\":\"" + deviceName +
                "\",\"command\":\"OFF\",\"state\":\"OFF\",\"lastSeen\":0}";
```

şu şekilde değiştir:

```cpp
  String body = "{\"name\":\"" + deviceName +
                "\",\"command\":\"OFF\",\"state\":\"OFF\"," 
                "\"lastSeen\":{\".sv\":\"timestamp\"}}";
```

- [ ] **Step 5: Commit**

```bash
git add firmware/esp01/esp01_firmware/esp01_firmware.ino
git commit -m "feat(firmware): lastSeen sunucu zamani + 30sn heartbeat eklendi"
```

Not: Bu dosya Arduino IDE ile derlenir, CI'da doğrulanamaz — kullanıcı flaşlarken derlemede doğrulanır. C++ sözdizimi görsel olarak dikkatle kontrol edilmeli (özellikle string birleştirmedeki kaçış karakterleri).

---

### Task 10: Manuel doğrulama (kullanıcı işlemi gerektirir)

- [ ] **Step 1: Uygulamayı derle ve cihaza yükle**

Run: `flutter run`

- [ ] **Step 2: Görsel tur**

Login → Cihazlarım → Kontrol → Tara → Kurulum ekranlarının her birinde: Aurora zemin, cam kartlar, degrade butonlar görünmeli; hiçbir ekranda eski neon-cyan (`#00F5FF`) kalmamalı.

- [ ] **Step 3: Firmware'i flaşla ve gerçek çevrimiçi durumunu test et**

1. Güncellenmiş `.ino` dosyasını Arduino IDE ile ESP-01'e yükle.
2. Cihaz bağlandıktan sonra uygulamada cihaz kartında yeşil nokta + "Acik/Kapali" görünmeli.
3. Kontrol ekranında güç düğmesine bas: düğme önce spinner (KOMUT GONDERILDI), ~5 sn içinde yeni duruma geçmeli, röle fiziksel tepki vermeli.
4. ESP'nin fişini çek: ~90 saniye içinde kartta kırmızı nokta + "Cevrimdisi · X dk once" görünmeli.
5. Fişi tak: cihaz WiFi'a bağlanınca gösterge yeşile dönmeli.

- [ ] **Step 4: Regresyon turu**

- Yeni cihaz ekleme akışı (Tara → ESP bul → Kurulum → başarı) çalışmalı.
- Cihaz silme (⋮ menü veya uzun basma) çalışmalı, ESP sıfırlanmalı.
- Çıkış yap → login ekranına dönmeli; tekrar giriş çalışmalı.
- Alt navigasyondaki "Ayarlar" her ekranda ayar sheet'ini açmalı (artık '/home'a gitmemeli).
