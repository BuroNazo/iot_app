# Röle Zamanlama Modülü Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının uygulama içinden bir cihazın rölesi için saat bazlı (günlük tekrarlı) veya dakika sayaçlı (tek seferlik) zamanlamalar tanımlayabilmesini ve bu zamanlamaların telefon/uygulama kapalıyken de sunucu tarafında (Firebase Cloud Functions) çalışmasını sağlamak.

**Architecture:** Zamanlamalar Realtime Database'de `users/{uid}/devices/{deviceId}/schedules/{scheduleId}` altında tutulur. Dakikada bir çalışan tek bir Cloud Function (`runSchedules`) tüm zamanlamaları tarar; zamanı gelen bir zamanlama bulduğunda cihazın mevcut `state` alanının tersini `command` alanına yazar (toggle). Saat bazlı zamanlamalar günün/saatinin eşleşmesiyle ve `lastTriggeredDate` ile aynı gün tekrar tetiklenmeyi önler; dakika sayaçlı zamanlamalar bir kez tetiklendikten sonra `enabled: false` yapılır. Flutter tarafında yeni bir model, servis ve UI bileşeni (bottom sheet + liste) eklenir.

**Tech Stack:** Flutter/Dart (mevcut uygulama), Firebase Realtime Database, Firebase Cloud Functions v2 (Node.js 20 + TypeScript), Jest (Cloud Functions pure-logic testleri), Luxon (zaman dilimi hesaplama), flutter_test (Dart model testleri).

---

## Dosya Yapısı

**Yeni dosyalar:**
- `lib/models/schedule.dart` — `Schedule` modeli, `ScheduleType` enum, `fromMap`/`toMap`/`summary`
- `lib/services/schedule_service.dart` — Firebase RTDB CRUD (mevcut `EspService` deseniyle aynı)
- `lib/widgets/schedule_sheet.dart` — "Yeni Zamanlama" bottom sheet formu
- `test/models/schedule_test.dart` — `Schedule` modeli için birim testleri
- `functions/package.json`, `functions/tsconfig.json`, `functions/jest.config.js`, `functions/.gitignore` — Cloud Functions proje iskeleti
- `functions/src/scheduleLogic.ts` — saf (pure) tetikleme mantığı: `evaluateSchedule`, `toggleCommand`
- `functions/src/scheduleLogic.test.ts` — `scheduleLogic.ts` için Jest testleri
- `functions/src/index.ts` — `runSchedules` scheduled Cloud Function (Admin SDK ile Firebase'e bağlanır, `scheduleLogic.ts`'i kullanır)
- `.firebaserc` — Firebase CLI proje eşlemesi (`iot1-bdd00`)
- `database.rules.json` — Realtime Database güvenlik kuralları (uid-scoped)

**Değişecek dosyalar:**
- `firebase.json` — `functions` ve `database` config anahtarları eklenir (mevcut `flutter` anahtarı korunur)
- `lib/screens/control_screen.dart` — "Zamanlama" bölümü (liste + ekleme butonu + `_ScheduleRow` widget'ı) eklenir

**Neden ayrı `scheduleLogic.ts` dosyası:** Firebase Admin SDK çağrıları (`admin.database()`) gerçek bir Firebase projesi/emulator olmadan test edilemez. Tetikleme kararını (saat/gün eşleşmesi, countdown süresi dolmuş mu, toggle yönü) Admin SDK'dan tamamen bağımsız, saf fonksiyonlara ayırarak bu mantığı gerçek bir Firebase bağlantısı olmadan Jest ile test edebiliyoruz. `index.ts` sadece veri okuma/yazma ve bu saf fonksiyonları çağırmakla sorumlu — bu kısım yalnızca `npm run build` (tip kontrolü) ile doğrulanır, deploy sonrası manuel test gerekir.

---

### Task 1: Schedule modeli (Flutter)

**Files:**
- Create: `lib/models/schedule.dart`
- Test: `test/models/schedule_test.dart`

- [ ] **Step 1: Test dizinini oluştur ve başarısız testi yaz**

`test/models/schedule_test.dart` dosyasını oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/schedule.dart';

void main() {
  group('Schedule.fromMap', () {
    test('parses a time schedule', () {
      final schedule = Schedule.fromMap('s1', {
        'type': 'time',
        'enabled': true,
        'hour': 22,
        'minute': 30,
        'days': [1, 2, 3, 4, 5],
        'lastTriggeredDate': '2026-07-01',
      });

      expect(schedule.id, 's1');
      expect(schedule.type, ScheduleType.time);
      expect(schedule.enabled, true);
      expect(schedule.hour, 22);
      expect(schedule.minute, 30);
      expect(schedule.days, [1, 2, 3, 4, 5]);
      expect(schedule.lastTriggeredDate, '2026-07-01');
    });

    test('parses a countdown schedule', () {
      final schedule = Schedule.fromMap('s2', {
        'type': 'countdown',
        'enabled': true,
        'minutes': 15,
        'triggerAt': 1751450000000,
      });

      expect(schedule.type, ScheduleType.countdown);
      expect(schedule.minutes, 15);
      expect(schedule.triggerAt, 1751450000000);
    });

    test('defaults enabled to true when missing', () {
      final schedule = Schedule.fromMap('s3', {'type': 'time'});
      expect(schedule.enabled, true);
    });
  });

  group('Schedule.toMap', () {
    test('round trips a time schedule', () {
      final original = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: false,
        hour: 7,
        minute: 5,
        days: [6, 7],
        lastTriggeredDate: '2026-07-01',
      );

      final rebuilt = Schedule.fromMap('s1', original.toMap());

      expect(rebuilt.hour, 7);
      expect(rebuilt.minute, 5);
      expect(rebuilt.days, [6, 7]);
      expect(rebuilt.enabled, false);
    });

    test('round trips a countdown schedule', () {
      final original = Schedule(
        id: 's2',
        type: ScheduleType.countdown,
        enabled: true,
        minutes: 20,
        triggerAt: 123456,
      );

      final rebuilt = Schedule.fromMap('s2', original.toMap());

      expect(rebuilt.minutes, 20);
      expect(rebuilt.triggerAt, 123456);
    });
  });

  group('Schedule.summary', () {
    test('formats a time schedule with days', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: true,
        hour: 9,
        minute: 5,
        days: [1, 3, 5],
      );

      expect(schedule.summary, 'Pzt, Çar, Cum 09:05');
    });

    test('formats a countdown schedule', () {
      final schedule = Schedule(
        id: 's2',
        type: ScheduleType.countdown,
        enabled: true,
        minutes: 15,
      );

      expect(schedule.summary, '15 dk sonra');
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/models/schedule_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/models/schedule.dart': No such file or directory` (veya benzer "package:esp01_controller/models/schedule.dart" bulunamadı hatası)

- [ ] **Step 3: Schedule modelini oluştur**

`lib/models/schedule.dart` dosyasını oluştur:

```dart
enum ScheduleType { time, countdown }

class Schedule {
  final String id;
  final ScheduleType type;
  final bool enabled;

  // type == ScheduleType.time için
  final int? hour;
  final int? minute;
  final List<int>? days; // 1=Pzt ... 7=Paz
  final String? lastTriggeredDate; // "yyyy-MM-dd"

  // type == ScheduleType.countdown için
  final int? minutes;
  final int? triggerAt; // epoch ms

  Schedule({
    required this.id,
    required this.type,
    required this.enabled,
    this.hour,
    this.minute,
    this.days,
    this.lastTriggeredDate,
    this.minutes,
    this.triggerAt,
  });

  factory Schedule.fromMap(String id, Map<dynamic, dynamic> map) {
    final type =
        map['type'] == 'countdown' ? ScheduleType.countdown : ScheduleType.time;
    return Schedule(
      id: id,
      type: type,
      enabled: map['enabled'] ?? true,
      hour: map['hour'] as int?,
      minute: map['minute'] as int?,
      days: (map['days'] as List?)?.map((e) => e as int).toList(),
      lastTriggeredDate: map['lastTriggeredDate'] as String?,
      minutes: map['minutes'] as int?,
      triggerAt: map['triggerAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    if (type == ScheduleType.time) {
      return {
        'type': 'time',
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'days': days,
        'lastTriggeredDate': lastTriggeredDate,
      };
    }
    return {
      'type': 'countdown',
      'enabled': enabled,
      'minutes': minutes,
      'triggerAt': triggerAt,
    };
  }

  static const Map<int, String> _dayLabels = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çar',
    4: 'Per',
    5: 'Cum',
    6: 'Cmt',
    7: 'Paz',
  };

  String get summary {
    if (type == ScheduleType.time) {
      final dayText = (days ?? []).map((d) => _dayLabels[d] ?? '?').join(', ');
      final h = (hour ?? 0).toString().padLeft(2, '0');
      final m = (minute ?? 0).toString().padLeft(2, '0');
      return '$dayText $h:$m';
    }
    return '${minutes ?? 0} dk sonra';
  }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/models/schedule_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/schedule.dart test/models/schedule_test.dart
git commit -m "feat: Schedule modeli eklendi"
```

---

### Task 2: ScheduleService (Flutter, Firebase CRUD)

**Files:**
- Create: `lib/services/schedule_service.dart`

Not: `EspService` (`lib/services/esp_service.dart`) gibi bu servis de doğrudan Firebase'e bağlandığı için gerçek bir Firebase projesi/emulator olmadan birim testi yazılamaz — mevcut kod tabanında `EspService` için de test yoktur, aynı konvansiyon izlenir. Doğrulama `flutter analyze` ile (derleme/tip hatası yok) ve Task 8 sonundaki manuel test adımıyla yapılır.

- [ ] **Step 1: Servisi oluştur**

`lib/services/schedule_service.dart` dosyasını oluştur:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/schedule.dart';

class ScheduleService {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DatabaseReference _schedulesRef(String deviceId) => FirebaseDatabase.instance
      .ref("users/$_uid/devices/$deviceId/schedules");

  Stream<List<Schedule>> schedulesStream(String deviceId) {
    return _schedulesRef(deviceId).onValue.map((event) {
      if (!event.snapshot.exists) return <Schedule>[];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final schedules = <Schedule>[];
      data.forEach((key, value) {
        if (value is Map) {
          schedules.add(Schedule.fromMap(key.toString(), value));
        }
      });
      return schedules;
    });
  }

  Future<void> addTimeSchedule(
    String deviceId, {
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    final ref = _schedulesRef(deviceId).push();
    await ref.set({
      'type': 'time',
      'enabled': true,
      'hour': hour,
      'minute': minute,
      'days': days,
      'lastTriggeredDate': '',
    });
  }

  Future<void> addCountdownSchedule(
    String deviceId, {
    required int minutes,
  }) async {
    final ref = _schedulesRef(deviceId).push();
    final triggerAt =
        DateTime.now().millisecondsSinceEpoch + minutes * 60 * 1000;
    await ref.set({
      'type': 'countdown',
      'enabled': true,
      'minutes': minutes,
      'triggerAt': triggerAt,
    });
  }

  Future<void> setEnabled(
      String deviceId, String scheduleId, bool enabled) async {
    await _schedulesRef(deviceId).child(scheduleId).update({'enabled': enabled});
  }

  Future<void> deleteSchedule(String deviceId, String scheduleId) async {
    await _schedulesRef(deviceId).child(scheduleId).remove();
  }
}
```

- [ ] **Step 2: Statik analiz ile doğrula**

Run: `flutter analyze lib/services/schedule_service.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/schedule_service.dart
git commit -m "feat: ScheduleService eklendi (Firebase CRUD)"
```

---

### Task 3: Cloud Functions proje iskeleti

**Files:**
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/jest.config.js`
- Create: `functions/.gitignore`

- [ ] **Step 1: `functions/package.json` oluştur**

```json
{
  "name": "functions",
  "private": true,
  "main": "lib/index.js",
  "engines": {
    "node": "20"
  },
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "deploy": "firebase deploy --only functions"
  },
  "dependencies": {
    "firebase-admin": "^12.1.0",
    "firebase-functions": "^5.0.0",
    "luxon": "^3.4.4"
  },
  "devDependencies": {
    "typescript": "^5.4.5",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.2",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.12.7",
    "@types/luxon": "^3.4.2"
  }
}
```

- [ ] **Step 2: `functions/tsconfig.json` oluştur**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2020",
    "lib": ["es2020"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: `functions/jest.config.js` oluştur**

```js
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
};
```

- [ ] **Step 4: `functions/.gitignore` oluştur**

```
node_modules/
lib/
```

- [ ] **Step 5: Bağımlılıkları kur**

Run: `cd functions && npm install`
Expected: `added N packages` ile başarıyla biter (internet erişimi gerekir; erişim yoksa bu adımı atlayıp Task 4/5'te `npx tsc`/`npx jest` çalıştırılamayabilir — bu durumda dependency kurulumu kullanıcı tarafından sonradan yapılmalıdır).

- [ ] **Step 6: Commit**

```bash
git add functions/package.json functions/tsconfig.json functions/jest.config.js functions/.gitignore
git commit -m "chore: Cloud Functions proje iskeleti eklendi"
```

---

### Task 4: scheduleLogic.ts — saf tetikleme mantığı (TDD)

**Files:**
- Create: `functions/src/scheduleLogic.ts`
- Test: `functions/src/scheduleLogic.test.ts`

- [ ] **Step 1: Başarısız testi yaz**

`functions/src/scheduleLogic.test.ts` dosyasını oluştur:

```ts
import {
  evaluateSchedule,
  toggleCommand,
  NowInfo,
  TimeSchedule,
  CountdownSchedule,
} from "./scheduleLogic";

const now = (overrides: Partial<NowInfo> = {}): NowInfo => ({
  hour: 22,
  minute: 30,
  dayOfWeek: 3, // Çarşamba
  dateStr: "2026-07-02",
  nowMs: 1751450000000,
  ...overrides,
});

describe("evaluateSchedule - time type", () => {
  const base: TimeSchedule = {
    type: "time",
    enabled: true,
    hour: 22,
    minute: 30,
    days: [3, 4, 5],
  };

  test("triggers when hour, minute and day match and not already triggered today", () => {
    const result = evaluateSchedule(base, now());
    expect(result.shouldTrigger).toBe(true);
    expect(result.scheduleUpdates).toEqual({ lastTriggeredDate: "2026-07-02" });
  });

  test("does not trigger when minute does not match", () => {
    const result = evaluateSchedule(base, now({ minute: 31 }));
    expect(result.shouldTrigger).toBe(false);
  });

  test("does not trigger when day is not in days list", () => {
    const result = evaluateSchedule(base, now({ dayOfWeek: 1 }));
    expect(result.shouldTrigger).toBe(false);
  });

  test("does not trigger twice on the same day", () => {
    const schedule: TimeSchedule = { ...base, lastTriggeredDate: "2026-07-02" };
    const result = evaluateSchedule(schedule, now());
    expect(result.shouldTrigger).toBe(false);
  });

  test("does not trigger when disabled", () => {
    const schedule: TimeSchedule = { ...base, enabled: false };
    const result = evaluateSchedule(schedule, now());
    expect(result.shouldTrigger).toBe(false);
  });
});

describe("evaluateSchedule - countdown type", () => {
  const base: CountdownSchedule = {
    type: "countdown",
    enabled: true,
    minutes: 15,
    triggerAt: 1751450000000,
  };

  test("triggers and disables itself when triggerAt has passed", () => {
    const result = evaluateSchedule(base, now({ nowMs: 1751450000001 }));
    expect(result.shouldTrigger).toBe(true);
    expect(result.scheduleUpdates).toEqual({ enabled: false });
  });

  test("does not trigger when triggerAt is in the future", () => {
    const result = evaluateSchedule(base, now({ nowMs: 1751449999999 }));
    expect(result.shouldTrigger).toBe(false);
  });
});

describe("toggleCommand", () => {
  test("returns OFF when current state is ON", () => {
    expect(toggleCommand("ON")).toBe("OFF");
  });

  test("returns ON when current state is OFF or undefined", () => {
    expect(toggleCommand("OFF")).toBe("ON");
    expect(toggleCommand(undefined)).toBe("ON");
  });
});
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `cd functions && npx jest scheduleLogic.test.ts`
Expected: FAIL — `Cannot find module './scheduleLogic'`

- [ ] **Step 3: scheduleLogic.ts'i yaz**

`functions/src/scheduleLogic.ts` dosyasını oluştur:

```ts
export interface TimeSchedule {
  type: "time";
  enabled: boolean;
  hour: number;
  minute: number;
  days: number[]; // 1=Pzt ... 7=Paz
  lastTriggeredDate?: string; // "yyyy-MM-dd"
}

export interface CountdownSchedule {
  type: "countdown";
  enabled: boolean;
  minutes: number;
  triggerAt: number; // epoch ms
}

export type ScheduleData = TimeSchedule | CountdownSchedule;

export interface NowInfo {
  hour: number;
  minute: number;
  dayOfWeek: number; // 1=Pzt ... 7=Paz
  dateStr: string; // "yyyy-MM-dd"
  nowMs: number;
}

export interface EvaluationResult {
  shouldTrigger: boolean;
  scheduleUpdates: Record<string, unknown>;
}

export function evaluateSchedule(
  schedule: ScheduleData,
  now: NowInfo
): EvaluationResult {
  if (!schedule.enabled) {
    return { shouldTrigger: false, scheduleUpdates: {} };
  }

  if (schedule.type === "time") {
    const matchesTime =
      schedule.hour === now.hour && schedule.minute === now.minute;
    const matchesDay = schedule.days.includes(now.dayOfWeek);
    const alreadyTriggeredToday = schedule.lastTriggeredDate === now.dateStr;

    if (matchesTime && matchesDay && !alreadyTriggeredToday) {
      return {
        shouldTrigger: true,
        scheduleUpdates: { lastTriggeredDate: now.dateStr },
      };
    }
    return { shouldTrigger: false, scheduleUpdates: {} };
  }

  if (schedule.triggerAt <= now.nowMs) {
    return {
      shouldTrigger: true,
      scheduleUpdates: { enabled: false },
    };
  }
  return { shouldTrigger: false, scheduleUpdates: {} };
}

export function toggleCommand(currentState: string | undefined): "ON" | "OFF" {
  return currentState === "ON" ? "OFF" : "ON";
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `cd functions && npx jest scheduleLogic.test.ts`
Expected: PASS — `Tests: 9 passed, 9 total`

- [ ] **Step 5: Commit**

```bash
git add functions/src/scheduleLogic.ts functions/src/scheduleLogic.test.ts
git commit -m "feat: schedule tetikleme mantığı (evaluateSchedule, toggleCommand) eklendi"
```

---

### Task 5: index.ts — runSchedules Cloud Function

**Files:**
- Create: `functions/src/index.ts`

Not: Bu dosya Firebase Admin SDK'ya bağlıdır ve gerçek kimlik bilgileri/emulator olmadan çalıştırılamaz; bu yüzden birim testi yoktur. Doğrulama `npm run build` (TypeScript tip kontrolü) ile ve deploy sonrası Task 9'daki manuel adımla yapılır.

- [ ] **Step 1: index.ts'i yaz**

`functions/src/index.ts` dosyasını oluştur:

```ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { DateTime } from "luxon";
import {
  evaluateSchedule,
  toggleCommand,
  ScheduleData,
  NowInfo,
} from "./scheduleLogic";

admin.initializeApp();

function buildNowInfo(): NowInfo {
  const now = DateTime.now().setZone("Europe/Istanbul");
  return {
    hour: now.hour,
    minute: now.minute,
    dayOfWeek: now.weekday, // luxon: 1=Pazartesi ... 7=Pazar
    dateStr: now.toFormat("yyyy-MM-dd"),
    nowMs: Date.now(),
  };
}

export const runSchedules = onSchedule("every 1 minutes", async () => {
  const db = admin.database();
  const usersSnap = await db.ref("users").once("value");
  if (!usersSnap.exists()) return;

  const nowInfo = buildNowInfo();
  const updates: Record<string, unknown> = {};

  usersSnap.forEach((userSnap) => {
    const uid = userSnap.key;
    const devices = userSnap.child("devices");
    devices.forEach((deviceSnap) => {
      const deviceId = deviceSnap.key;
      const currentState = deviceSnap.child("state").val() as
        | string
        | undefined;
      const schedules = deviceSnap.child("schedules");
      schedules.forEach((scheduleSnap) => {
        const scheduleId = scheduleSnap.key;
        const schedule = scheduleSnap.val() as ScheduleData;
        const result = evaluateSchedule(schedule, nowInfo);
        if (result.shouldTrigger) {
          const newCommand = toggleCommand(currentState);
          updates[`users/${uid}/devices/${deviceId}/command`] = newCommand;
          for (const [field, value] of Object.entries(result.scheduleUpdates)) {
            updates[
              `users/${uid}/devices/${deviceId}/schedules/${scheduleId}/${field}`
            ] = value;
          }
        }
        return false;
      });
      return false;
    });
    return false;
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
  }
});
```

- [ ] **Step 2: Derlemenin geçtiğini doğrula**

Run: `cd functions && npm run build`
Expected: Hatasız biter, `functions/lib/index.js` ve `functions/lib/scheduleLogic.js` üretilir.

- [ ] **Step 3: Commit**

```bash
git add functions/src/index.ts
git commit -m "feat: runSchedules scheduled Cloud Function eklendi"
```

---

### Task 6: Firebase proje konfigürasyonu (functions + database rules)

**Files:**
- Modify: `firebase.json`
- Create: `.firebaserc`
- Create: `database.rules.json`

- [ ] **Step 1: `firebase.json`'a `functions` ve `database` anahtarlarını ekle**

Mevcut `firebase.json` içeriği (tek satır, FlutterFire CLI tarafından üretilmiş):

```json
{"flutter":{"platforms":{"android":{"default":{"projectId":"iot1-bdd00","appId":"1:863208259989:android:a062148cfb19106573f69c","fileOutput":"android/app/google-services.json"}},"dart":{"lib/firebase_options.dart":{"projectId":"iot1-bdd00","configurations":{"android":"1:863208259989:android:a062148cfb19106573f69c"}}}}}}
```

Bunu şu şekilde değiştir (formatlanmış, `flutter` anahtarı aynen korunur, `functions` ve `database` eklenir):

```json
{
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "iot1-bdd00",
          "appId": "1:863208259989:android:a062148cfb19106573f69c",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "iot1-bdd00",
          "configurations": {
            "android": "1:863208259989:android:a062148cfb19106573f69c"
          }
        }
      }
    }
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log",
        "*.local"
      ],
      "predeploy": [
        "npm --prefix \"$RESOURCE_DIR\" run build"
      ]
    }
  ],
  "database": {
    "rules": "database.rules.json"
  }
}
```

Bu değişikliği Edit tool ile yap (eski tek satırlık içeriği yukarıdaki formatlanmış JSON ile değiştir).

- [ ] **Step 2: `.firebaserc` oluştur**

```json
{
  "projects": {
    "default": "iot1-bdd00"
  }
}
```

- [ ] **Step 3: `database.rules.json` oluştur**

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid"
      }
    }
  }
}
```

- [ ] **Step 4: JSON dosyalarının geçerli olduğunu doğrula**

Run: `node -e "JSON.parse(require('fs').readFileSync('firebase.json', 'utf8')); JSON.parse(require('fs').readFileSync('.firebaserc', 'utf8')); JSON.parse(require('fs').readFileSync('database.rules.json', 'utf8')); console.log('OK')"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add firebase.json .firebaserc database.rules.json
git commit -m "chore: Firebase Functions ve Database rules konfigürasyonu eklendi"
```

---

### Task 7: ScheduleSheet — "Yeni Zamanlama" formu (Flutter UI)

**Files:**
- Create: `lib/widgets/schedule_sheet.dart`

- [ ] **Step 1: Widget'ı oluştur**

`lib/widgets/schedule_sheet.dart` dosyasını oluştur:

```dart
import 'package:flutter/material.dart';
import '../services/schedule_service.dart';

class ScheduleSheet extends StatefulWidget {
  final String deviceId;

  const ScheduleSheet({super.key, required this.deviceId});

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  final ScheduleService _scheduleService = ScheduleService();
  bool _isTimeMode = true;
  bool _isSaving = false;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 22, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  final TextEditingController _minutesController =
      TextEditingController(text: '15');

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const List<String> _dayLabels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz'
  ];

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_isTimeMode && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir gun secmelisiniz')),
      );
      return;
    }
    if (!_isTimeMode) {
      final minutes = int.tryParse(_minutesController.text);
      if (minutes == null || minutes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gecerli bir dakika girin')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    if (_isTimeMode) {
      await _scheduleService.addTimeSchedule(
        widget.deviceId,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        days: _selectedDays.toList()..sort(),
      );
    } else {
      await _scheduleService.addCountdownSchedule(
        widget.deviceId,
        minutes: int.parse(_minutesController.text),
      );
    }
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yeni Zamanlama',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Saat')),
              ButtonSegment(value: false, label: Text('Dakika Sayaci')),
            ],
            selected: {_isTimeMode},
            onSelectionChanged: (selection) =>
                setState(() => _isTimeMode = selection.first),
          ),
          const SizedBox(height: 20),
          if (_isTimeMode) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Saat', style: TextStyle(color: Colors.white70)),
              trailing: Text(
                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: _neonCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(_dayLabels[i]),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
          ] else ...[
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Dakika',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Statik analiz ile doğrula**

Run: `flutter analyze lib/widgets/schedule_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/schedule_sheet.dart
git commit -m "feat: ScheduleSheet (yeni zamanlama formu) eklendi"
```

---

### Task 8: ControlScreen entegrasyonu

**Files:**
- Modify: `lib/screens/control_screen.dart`

- [ ] **Step 1: Import'ları ekle**

`lib/screens/control_screen.dart` dosyasının başındaki:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/esp_service.dart';
```

bloğunu şu şekilde değiştir:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/esp_service.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_sheet.dart';
```

- [ ] **Step 2: ScheduleService alanını ekle**

```dart
  final EspService _espService = EspService();
  bool _relayStatus = false;
```

bloğunu şu şekilde değiştir:

```dart
  final EspService _espService = EspService();
  final ScheduleService _scheduleService = ScheduleService();
  bool _relayStatus = false;
```

- [ ] **Step 3: `_showAddScheduleSheet` metodunu ekle**

`_showResetDialog` metodunun bitişindeki (`);` ile biten kapanıştan hemen sonraki) şu bloğu:

```dart
  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }
```

şu şekilde değiştir:

```dart
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
```

- [ ] **Step 4: Zamanlama bölümünü Cihaz Bilgisi kartından sonra ekle**

Şu bloğu:

```dart
                const SizedBox(height: 16),

                // Online göstergesi
```

şu şekilde değiştir:

```dart
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
```

- [ ] **Step 5: `_ScheduleRow` widget sınıfını dosyanın sonuna ekle**

Dosyanın en sonuna (son `}` satırından sonra) şu sınıfı ekle:

```dart

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
```

- [ ] **Step 6: Statik analiz ile doğrula**

Run: `flutter analyze lib/screens/control_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/screens/control_screen.dart
git commit -m "feat: ControlScreen'e zamanlama bolumu eklendi"
```

---

### Task 9: Manuel doğrulama ve deploy (kullanıcı işlemi gerektirir)

Bu adımlar otomatik yürütülemez çünkü Firebase Console'da billing planı değişikliği ve `firebase login` ile kullanıcı kimlik doğrulaması gerektirir.

- [ ] **Step 1: Firebase projesini Blaze plana yükselt**

Firebase Console > `iot1-bdd00` projesi > Faturalandırma (Usage and billing) > Blaze planına geç.

- [ ] **Step 2: Flutter uygulamasını çalıştır ve UI'ı test et**

Run: `flutter run`

- Bir cihazın Control ekranını aç, "Zamanlama" bölümünde "Henuz zamanlama yok" yazısını gör.
- "+" butonuna bas, "Saat" sekmesinde bir saat seç, en az bir gün seç, "Kaydet"e bas → listede yeni satır görünmeli.
- Yeni satırdaki switch'i kapat/aç, "enabled" alanının Firebase Console > Realtime Database'de değiştiğini doğrula.
- Çöp kutusu ikonuna bas, satırın silindiğini doğrula.
- "Dakika Sayaci" sekmesinde "1" gir, "Kaydet"e bas → listede "1 dk sonra" satırı görünmeli.

- [ ] **Step 3: Cloud Functions'ı deploy et**

```bash
firebase login
firebase use --add   # iot1-bdd00 projesini "default" olarak seç
cd functions
npm install
npm run build
npm test
cd ..
firebase deploy --only functions,database
```

Expected: `runSchedules` fonksiyonu ve `database.rules.json` başarıyla deploy edilir; Firebase Console > Functions altında `runSchedules` scheduled function olarak listelenir.

- [ ] **Step 4: Uçtan uca doğrulama**

- Uygulamada bir cihaz için 1 dakika sonrasına bir dakika sayaçlı zamanlama ekle (örn. mevcut saatin 1 dakika sonrası için "Saat" tipi bir zamanlama, tüm günler seçili).
- Uygulamayı tamamen kapat (arka planda da çalışmasın).
- 1-2 dakika bekle, Firebase Console > Realtime Database'de cihazın `command`/`state` alanının değiştiğini doğrula.
- Uygulamayı tekrar aç, Control ekranında rölenin yeni durumda göründüğünü doğrula.
