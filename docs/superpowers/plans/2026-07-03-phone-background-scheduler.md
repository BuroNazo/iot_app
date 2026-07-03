# Telefon Arka Plan Zamanlayıcısı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android'de, telefon açıkken röle zamanlamalarını 15 dakikada bir kontrol edip tetikleyen bir arka plan görevi eklemek — GitHub Actions'ı kaldırmadan, ona ek/hızlandırıcı bir yedek katman olarak.

**Architecture:** `workmanager` paketiyle kayıtlı bir periyodik Android WorkManager görevi, ayrı bir Dart isolate'inde çalışan `callbackDispatcher()`'ı tetikler; bu da Firebase'i yeniden başlatıp `users/{uid}/devices/*/schedules/*` altındaki tüm zamanlamaları okur, saf bir Dart mantığıyla (`functions/src/scheduleLogic.ts`'nin birebir Dart portu) değerlendirir ve tetiklenmesi gerekenler için `command`/zamanlama alanlarını RTDB'ye yazar.

**Tech Stack:** Flutter/Dart, `workmanager` paketi (Android WorkManager sarmalayıcısı), mevcut `firebase_database`/`firebase_auth`/`firebase_core`, `flutter_test`.

---

## Dosya Yapısı

**Yeni dosyalar:**
- `lib/services/schedule_evaluator.dart` — saf Dart mantığı: `NowInfo`, `EvaluationResult`, `evaluateSchedule()`, `toggleCommand()`. Firebase'e bağımlılığı yok.
- `test/services/schedule_evaluator_test.dart` — `functions/src/scheduleLogic.test.ts` ile birebir aynı senaryoları kapsayan birim testleri.
- `lib/services/background_scheduler.dart` — `callbackDispatcher()` (WorkManager giriş noktası) ve `initializeBackgroundScheduler()` (kayıt fonksiyonu); Firebase okuma/yazma mantığı burada.

**Değişecek dosyalar:**
- `pubspec.yaml` — `workmanager` bağımlılığı eklenir.
- `lib/main.dart` — `runApp()` öncesi `initializeBackgroundScheduler()` çağrısı eklenir.

---

### Task 1: `workmanager` bağımlılığını ekle

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Bağımlılığı ekle**

`pubspec.yaml` dosyasındaki:

```yaml
  # Firebase için
  firebase_core: ^3.0.0
  firebase_database: ^11.0.0
  firebase_auth: ^5.0.0 
  google_sign_in: ^6.2.0
```

bloğunu şu şekilde değiştir:

```yaml
  # Firebase için
  firebase_core: ^3.0.0
  firebase_database: ^11.0.0
  firebase_auth: ^5.0.0 
  google_sign_in: ^6.2.0

  # Arka planda zamanlama kontrolu icin
  workmanager: ^0.9.0
```

- [ ] **Step 2: Bağımlılıkları indir**

Run: `flutter pub get`
Expected: Hatasız biter, `pubspec.lock` güncellenir.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: workmanager bagimliligi eklendi"
```

---

### Task 2: `schedule_evaluator.dart` — saf tetikleme mantığı (TDD)

**Files:**
- Create: `lib/services/schedule_evaluator.dart`
- Test: `test/services/schedule_evaluator_test.dart`

Bu, `functions/src/scheduleLogic.ts`'nin (Cloud Functions/GitHub Actions tarafında kullanılan) birebir Dart portudur — aynı "yakalama" mantığı (tam dakika eşleşmesi değil, "zamanı geçti mi, bugün tetiklenmedi mi" kontrolü), `lib/models/schedule.dart`'taki mevcut `Schedule`/`ScheduleType` modelini kullanır.

- [ ] **Step 1: Başarısız testi yaz**

`test/services/schedule_evaluator_test.dart` dosyasını oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/schedule.dart';
import 'package:esp01_controller/services/schedule_evaluator.dart';

void main() {
  NowInfo now({
    int hour = 22,
    int minute = 30,
    int dayOfWeek = 3, // Çarşamba
    String dateStr = '2026-07-02',
    int? nowMs,
  }) {
    return NowInfo(
      hour: hour,
      minute: minute,
      dayOfWeek: dayOfWeek,
      dateStr: dateStr,
      nowMs: nowMs ?? 1751450000000,
    );
  }

  group('evaluateSchedule - time type', () {
    final base = Schedule(
      id: 's1',
      type: ScheduleType.time,
      enabled: true,
      hour: 22,
      minute: 30,
      days: const [3, 4, 5],
    );

    test('triggers when hour, minute and day match and not already triggered today', () {
      final result = evaluateSchedule(base, now());
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'lastTriggeredDate': '2026-07-02'});
    });

    test('does not trigger when current time is before the scheduled time', () {
      final result = evaluateSchedule(base, now(minute: 29));
      expect(result.shouldTrigger, false);
    });

    test('triggers (catch-up) when current time is after the scheduled time and not already triggered today', () {
      final result = evaluateSchedule(base, now(hour: 23, minute: 45));
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'lastTriggeredDate': '2026-07-02'});
    });

    test('does not trigger when day is not in days list', () {
      final result = evaluateSchedule(base, now(dayOfWeek: 1));
      expect(result.shouldTrigger, false);
    });

    test('does not trigger twice on the same day', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: true,
        hour: 22,
        minute: 30,
        days: const [3, 4, 5],
        lastTriggeredDate: '2026-07-02',
      );
      final result = evaluateSchedule(schedule, now());
      expect(result.shouldTrigger, false);
    });

    test('does not trigger when disabled', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: false,
        hour: 22,
        minute: 30,
        days: const [3, 4, 5],
      );
      final result = evaluateSchedule(schedule, now());
      expect(result.shouldTrigger, false);
    });
  });

  group('evaluateSchedule - countdown type', () {
    final base = Schedule(
      id: 's2',
      type: ScheduleType.countdown,
      enabled: true,
      minutes: 15,
      triggerAt: 1751450000000,
    );

    test('triggers and disables itself when triggerAt has passed', () {
      final result = evaluateSchedule(base, now(nowMs: 1751450000001));
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'enabled': false});
    });

    test('does not trigger when triggerAt is in the future', () {
      final result = evaluateSchedule(base, now(nowMs: 1751449999999));
      expect(result.shouldTrigger, false);
    });
  });

  group('toggleCommand', () {
    test('returns OFF when current state is ON', () {
      expect(toggleCommand('ON'), 'OFF');
    });

    test('returns ON when current state is OFF or null', () {
      expect(toggleCommand('OFF'), 'ON');
      expect(toggleCommand(null), 'ON');
    });
  });

  group('NowInfo.fromDateTime', () {
    test('maps DateTime fields to NowInfo correctly', () {
      final dt = DateTime(2026, 7, 2, 22, 30); // Persembe degil, gercek gun onemli degil burada
      final info = NowInfo.fromDateTime(dt);
      expect(info.hour, 22);
      expect(info.minute, 30);
      expect(info.dateStr, '2026-07-02');
      expect(info.dayOfWeek, dt.weekday);
      expect(info.nowMs, dt.millisecondsSinceEpoch);
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/services/schedule_evaluator_test.dart`
Expected: FAIL — `lib/services/schedule_evaluator.dart` bulunamadığı için derleme hatası.

- [ ] **Step 3: `schedule_evaluator.dart`'ı yaz**

`lib/services/schedule_evaluator.dart` dosyasını oluştur:

```dart
import '../models/schedule.dart';

class NowInfo {
  final int hour;
  final int minute;
  final int dayOfWeek; // 1=Pzt ... 7=Paz
  final String dateStr; // "yyyy-MM-dd"
  final int nowMs;

  NowInfo({
    required this.hour,
    required this.minute,
    required this.dayOfWeek,
    required this.dateStr,
    required this.nowMs,
  });

  factory NowInfo.fromDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return NowInfo(
      hour: dt.hour,
      minute: dt.minute,
      dayOfWeek: dt.weekday, // Dart: 1=Pazartesi ... 7=Pazar, bizim kurallmizla ayni
      dateStr: '$y-$m-$d',
      nowMs: dt.millisecondsSinceEpoch,
    );
  }
}

class EvaluationResult {
  final bool shouldTrigger;
  final Map<String, dynamic> scheduleUpdates;

  EvaluationResult({required this.shouldTrigger, required this.scheduleUpdates});
}

EvaluationResult evaluateSchedule(Schedule schedule, NowInfo now) {
  if (!schedule.enabled) {
    return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
  }

  if (schedule.type == ScheduleType.time) {
    final scheduledMinutes = (schedule.hour ?? 0) * 60 + (schedule.minute ?? 0);
    final nowMinutes = now.hour * 60 + now.minute;
    final timeHasPassed = nowMinutes >= scheduledMinutes;
    final matchesDay = (schedule.days ?? const []).contains(now.dayOfWeek);
    final alreadyTriggeredToday = schedule.lastTriggeredDate == now.dateStr;

    if (timeHasPassed && matchesDay && !alreadyTriggeredToday) {
      return EvaluationResult(
        shouldTrigger: true,
        scheduleUpdates: {'lastTriggeredDate': now.dateStr},
      );
    }
    return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
  }

  // countdown
  if ((schedule.triggerAt ?? 0) <= now.nowMs) {
    return EvaluationResult(
      shouldTrigger: true,
      scheduleUpdates: const {'enabled': false},
    );
  }
  return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
}

String toggleCommand(String? currentState) {
  return currentState == 'ON' ? 'OFF' : 'ON';
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/services/schedule_evaluator_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/schedule_evaluator.dart test/services/schedule_evaluator_test.dart
git commit -m "feat: schedule_evaluator.dart (Dart tetikleme mantigi) eklendi"
```

---

### Task 3: `background_scheduler.dart` — WorkManager entegrasyonu

**Files:**
- Create: `lib/services/background_scheduler.dart`

Not: Bu dosya gerçek bir Firebase bağlamı ve WorkManager isolate ortamı gerektirdiği için (tıpkı `functions/src/index.ts` gibi) otomatik testi kapsam dışıdır. Doğrulama `flutter analyze` ve Task 5'teki manuel cihaz testiyle yapılır.

- [ ] **Step 1: Dosyayı oluştur**

`lib/services/background_scheduler.dart` dosyasını oluştur:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import '../models/schedule.dart';
import 'schedule_evaluator.dart';

const String _relaySchedulesTaskName = 'relaySchedulesCheck';
const String _relaySchedulesUniqueName = 'relay-schedule-check';

// WorkManager'in her tetiklemede cagirdigi giris noktasi. Uygulama obfuscated
// olsa da veya Flutter 3.1+ ile calisirken bu pragma zorunludur.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _relaySchedulesTaskName) {
      await _runScheduleCheck();
    }
    return Future.value(true);
  });
}

Future<void> _runScheduleCheck() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final devicesEvent =
      await FirebaseDatabase.instance.ref('users/$uid/devices').once();
  final devicesSnap = devicesEvent.snapshot;
  if (!devicesSnap.exists) return;

  final now = NowInfo.fromDateTime(DateTime.now());
  final updates = <String, dynamic>{};

  final devicesData = devicesSnap.value as Map<dynamic, dynamic>;
  devicesData.forEach((deviceId, deviceValue) {
    if (deviceValue is! Map) return;
    final currentState = deviceValue['state'] as String?;
    final schedulesData = deviceValue['schedules'];
    if (schedulesData is! Map) return;

    schedulesData.forEach((scheduleId, scheduleValue) {
      if (scheduleValue is! Map) return;
      final schedule = Schedule.fromMap(scheduleId.toString(), scheduleValue);
      final result = evaluateSchedule(schedule, now);
      if (result.shouldTrigger) {
        final newCommand = toggleCommand(currentState);
        updates['users/$uid/devices/$deviceId/command'] = newCommand;
        result.scheduleUpdates.forEach((field, value) {
          updates['users/$uid/devices/$deviceId/schedules/$scheduleId/$field'] =
              value;
        });
      }
    });
  });

  if (updates.isNotEmpty) {
    await FirebaseDatabase.instance.ref().update(updates);
  }
}

Future<void> initializeBackgroundScheduler() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _relaySchedulesUniqueName,
    _relaySchedulesTaskName,
    frequency: const Duration(minutes: 15),
  );
}
```

- [ ] **Step 2: Statik analiz ile doğrula**

Run: `flutter analyze lib/services/background_scheduler.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/background_scheduler.dart
git commit -m "feat: background_scheduler.dart (WorkManager entegrasyonu) eklendi"
```

---

### Task 4: `main.dart` entegrasyonu

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Import ekle**

`lib/main.dart` dosyasının başındaki:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/provision_screen.dart';
import 'screens/control_screen.dart';
import 'screens/home_screen.dart';
```

bloğunu şu şekilde değiştir:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/provision_screen.dart';
import 'screens/control_screen.dart';
import 'screens/home_screen.dart';
import 'services/background_scheduler.dart';
```

- [ ] **Step 2: Başlatma çağrısını ekle**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Esp01App());
}
```

bloğunu şu şekilde değiştir:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeBackgroundScheduler();
  runApp(const Esp01App());
}
```

- [ ] **Step 3: Statik analiz ile doğrula**

Run: `flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: main.dart'a arka plan zamanlayici baslatma eklendi"
```

---

### Task 5: Manuel doğrulama

Bu adımlar otomatik yürütülemez, gerçek bir Android cihaz/emülatör gerektirir.

- [ ] **Step 1: Uygulamayı derle ve yükle**

Run: `flutter run` (bağlı bir Android cihaza)

- [ ] **Step 2: Uygulamayı aç, giriş yap, en az bir cihaz için bir zamanlama oluştur**

Control ekranından "+" ile bir dakika sayaçlı zamanlama ekle (örn. 1 dakika).

- [ ] **Step 3: Uygulamayı arka plana al (kapatma, sadece home tuşuna bas)**

15 dakika kadar bekle (Android WorkManager'ın minimum periyodik aralığı budur; ilk çalıştırma daha erken de tetiklenebilir ama garanti değildir).

- [ ] **Step 4: Firebase Console'da doğrula**

Realtime Database'de `users/{uid}/devices/{deviceId}/command` ve ilgili zamanlamanın `enabled`/`lastTriggeredDate` alanlarının güncellendiğini kontrol et.

- [ ] **Step 5: Logcat ile arka plan görevinin çalıştığını doğrula (opsiyonel)**

Run: `adb logcat | grep -i workmanager`
Expected: WorkManager'ın periyodik görevi zamanladığına ve çalıştırdığına dair log satırları.
