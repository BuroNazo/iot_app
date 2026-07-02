# Röle Zamanlama Modülü — Tasarım

> **Güncelleme (2026-07-03):** Kullanıcı ücretsiz bir çözüm istediği için tetikleme mekanizması
> Firebase Cloud Functions (Blaze plan gerektirir) yerine **GitHub Actions scheduled workflow**
> olarak değiştirildi. `functions/src/scheduleLogic.ts` aynen korunur; `functions/src/index.ts`
> artık bir Firebase Functions `onSchedule` yerine bağımsız bir Node script'i (`runSchedulesOnce`)
> olarak çalışır ve `.github/workflows/relay-schedule.yml` içinde 5 dakikada bir GitHub'ın ücretsiz
> cron altyapısıyla tetiklenir. Kimlik doğrulama, bir Firebase servis hesabı anahtarının GitHub
> repo secret'ı (`FIREBASE_SERVICE_ACCOUNT_KEY`) olarak eklenmesiyle yapılır. `database.rules.json`
> deploy'u (`firebase deploy --only database`) hâlâ geçerlidir ve Blaze gerektirmez — sadece
> Cloud Functions deploy adımı tamamen kaldırılmıştır.

## Amaç

Kullanıcı, uygulama içinden bir cihazın rölesi için zaman bazlı otomasyon kuralları tanımlayabilsin. İki tür kural desteklenir:

1. **Saat bazlı (time)**: Belirli bir saat:dakikada, seçilen günlerde tekrar eder. Tetiklendiğinde rölenin mevcut durumunu tersine çevirir (ON→OFF, OFF→ON).
2. **Dakika sayaçlı (countdown)**: Kullanıcının belirlediği N dakika sonra bir kez tetiklenir, rölenin durumunu tersine çevirir, sonra kendini pasif hale getirir (tek seferlik).

Zamanlamalar, telefon veya uygulama kapalı olsa dahi çalışmalıdır. Bu nedenle tetikleme mantığı istemci (Flutter) tarafında değil, sunucu tarafında (Firebase Cloud Functions, scheduled trigger) çalışır.

## Ön Koşul

Zamanlanmış (`pubsub.schedule`) Cloud Functions çalıştırmak için Firebase projesinin **Blaze (kullandıkça öde)** planına geçmesi gerekir. Kullanıcı şu an Spark (ücretsiz) planda; deploy öncesi bu geçiş yapılmalıdır. Aylık kullanım, dakikada bir çalışan hafif bir fonksiyon için genelde ücretsiz kotanın içinde kalır.

## Veri Modeli

Realtime Database, mevcut cihaz yapısına ek olarak:

```
users/{uid}/devices/{deviceId}/schedules/{scheduleId}
{
  "type": "time" | "countdown",
  "enabled": true,

  // type == "time" için:
  "hour": 22,              // 0-23
  "minute": 30,             // 0-59
  "days": [1,2,3,4,5],      // 1=Pzt ... 7=Paz, en az 1 gün
  "lastTriggeredDate": "2026-07-02",  // "yyyy-MM-dd", aynı gün tekrar tetiklenmeyi önler

  // type == "countdown" için:
  "minutes": 15,            // kullanıcının girdiği süre
  "triggerAt": 1751450000000 // epoch ms, oluşturulduğu an + minutes*60*1000
}
```

- `scheduleId`: Firebase `push()` ile üretilen otomatik anahtar.
- Bir cihaz için sınırsız sayıda zamanlama olabilir (hem time hem countdown karışık).
- `enabled: false` olan kayıtlar Cloud Function tarafından atlanır ama silinmez (kullanıcı tekrar açabilir).
- Countdown tetiklendikten sonra Cloud Function `enabled: false` yazar; silme işlemi kullanıcıya bırakılır (geçmişi görebilsin diye).

## Cloud Function

Yeni `functions/` dizini (Node.js + TypeScript, Firebase Functions v2), tek bir zamanlanmış fonksiyon:

```
export const runSchedules = onSchedule("every 1 minutes", async () => { ... })
```

Mantık:
1. `users` düğümünü tamamen okur (tüm kullanıcılar/cihazlar/schedules).
2. Her `schedule` için:
   - `enabled == false` ise atla.
   - `type == "time"`: şu anki yerel saat/dakika (Türkiye saat dilimi, `Europe/Istanbul`) `hour`/`minute` ile eşleşiyor mu, bugünün gün numarası `days` içinde mi, ve `lastTriggeredDate` bugüne eşit değil mi kontrol et. Eşleşiyorsa: cihazın `state` alanının tersini `command` alanına yaz, `lastTriggeredDate`'i bugüne güncelle.
   - `type == "countdown"`: `triggerAt <= Date.now()` ise: `state`'in tersini `command`'a yaz, `enabled: false` yap.
3. Tüm yazmalar `Promise.all` ile toplu yapılır.

Not: Fonksiyon dakikada bir çalıştığı için zamanlama hassasiyeti ±1 dakikadır; bu, kullanıcı tarafından kabul edilen bir sınırlamadır.

## Flutter Tarafı

**Yeni dosya `lib/models/schedule.dart`**: `Schedule` modeli (`fromMap`/`toMap`), `ScheduleType` enum (`time`, `countdown`).

**Yeni dosya `lib/services/schedule_service.dart`**: `ScheduleService` — mevcut `EspService` ile aynı desende (`users/{uid}/devices/{deviceId}/schedules` altında CRUD):
- `Stream<List<Schedule>> schedulesStream(String deviceId)`
- `Future<void> addTimeSchedule(deviceId, hour, minute, days)`
- `Future<void> addCountdownSchedule(deviceId, minutes)`
- `Future<void> toggleEnabled(deviceId, scheduleId, bool enabled)`
- `Future<void> deleteSchedule(deviceId, scheduleId)`

**UI**: `ControlScreen`'e yeni bir "Zamanlama" bölümü eklenir (kart listesi + "+ Yeni Zamanlama" butonu). Yeni zamanlama eklerken bottom sheet açılır:
- Üstte iki sekme/segment: "Saat" / "Dakika Sayacı"
- **Saat** sekmesi: `TimePicker` (saat:dakika) + 7 günlük gün seçici (Pzt-Paz toggle chip'leri)
- **Dakika Sayacı** sekmesi: sayısal giriş (dakika)
- Her zamanlama satırında: tip ikonu, özet metin (örn. "Her Pzt-Cum 22:30" veya "15 dk sonra"), enabled switch'i, silme ikonu.

Mevcut neon/dark tema stiline (`_neonCyan`, `_darkBg`, `Color(0xFF0D1117)` vb.) uyumlu olacak şekilde tasarlanır.

## Kapsam Dışı

- Cloud Functions deploy işlemi ve Blaze plan geçişi kullanıcı tarafından yapılacak (bu tasarım kapsamında sadece kod/talimat sağlanır).
- Zaman dilimi ayarı (sabit `Europe/Istanbul` kullanılır, kullanıcı ayarı yok).
- Bildirim/push notification (tetiklendiğinde kullanıcıya bildirim gönderme) bu kapsamda yok.
