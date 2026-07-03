# Telefon Arka Plan Zamanlayıcısı — Tasarım

## Amaç

Mevcut röle zamanlama modülü (bkz. [2026-07-02-relay-schedule-design.md](2026-07-02-relay-schedule-design.md)) GitHub Actions cron ile çalışıyor, ancak GitHub'ın ücretsiz planında zamanlanmış tetikleyicilerin gerçek çalışma sıklığı öngörülemez (gözlemlenen: dakikalar yerine saatler mertebesinde gecikme). Bu tasarım, telefon uygulamasının kendisine bir **arka plan görevi** ekleyerek, telefon açık/internete bağlıyken zamanlamaların çok daha hızlı (15 dakikada bir) değerlendirilmesini sağlar.

GitHub Actions mekanizması **kaldırılmaz**, yedek olarak kalır: telefon kapalı/uzakken veya uygulama tamamen durdurulmuşken zamanlamalar yine de (geç de olsa) GitHub Actions tarafından yakalanır. İki mekanizma da aynı idempotent değerlendirme mantığını kullandığı için (aynı zamanlamayı iki kez tetiklemez — `lastTriggeredDate`/`enabled` alanlarıyla korunur) birlikte çalışmaları güvenlidir.

**Kapsam:** Sadece Android. iOS'un arka plan görev API'si (BGTaskScheduler) çok daha kısıtlı/güvenilmez olduğu ve bu projede iOS kullanılmadığı için bu tasarıma dahil edilmemiştir — iOS kullanıcıları (varsa) yalnızca GitHub Actions yedeğinden yararlanır.

## Mimari

Uygulama ilk açıldığında (`main.dart`), `workmanager` paketi ile 15 dakikada bir çalışacak bir periyodik arka plan görevi kaydedilir (Android WorkManager'ın izin verdiği minimum periyodik aralık 15 dakikadır). Bu görev, uygulamanın ana isolate'inden **bağımsız** bir Dart isolate'inde çalışan `callbackDispatcher()` fonksiyonunu tetikler. Bu fonksiyon:

1. Firebase'i kendi isolate bağlamında yeniden başlatır (`Firebase.initializeApp()`).
2. `FirebaseAuth.instance.currentUser` üzerinden giriş yapmış kullanıcının uid'sini alır (Android'de native Firebase Auth SDK oturumu kalıcı olarak sakladığı için, ana uygulama kapalı olsa bile bu isolate'te de kullanıcı bilgisi mevcuttur — bu varsayım implementasyon sırasında doğrulanacaktır).
3. `users/{uid}/devices` altındaki tüm cihazları ve her cihazın `schedules` alt-koleksiyonunu okur.
4. Her zamanlama için `schedule_evaluator.dart`'taki `evaluateSchedule()` fonksiyonunu çağırır (Node.js tarafındaki `scheduleLogic.ts` ile birebir aynı mantık, Dart'a taşınmış).
5. Tetiklenmesi gereken zamanlamalar için `toggleCommand()` ile yeni komutu hesaplar, cihazın `command` alanını ve zamanlamanın `scheduleUpdates` alanlarını (örn. `lastTriggeredDate` veya `enabled: false`) tek bir toplu güncelleme ile yazar.

**Zaman dilimi:** Node.js tarafı `luxon` ile açıkça `Europe/Istanbul` dilimine çeviriyordu çünkü sunucunun kendi saat dilimi bilinmiyordu. Telefon tarafında `DateTime.now()` zaten cihazın yerel saatini (kullanıcının telefonu Türkiye saatinde olduğu için Europe/Istanbul) verir, bu yüzden ekstra bir dönüşüm gerekmez.

## Bileşenler

**`lib/services/schedule_evaluator.dart` (yeni):** Saf Dart fonksiyonları — `evaluateSchedule(ScheduleData, NowInfo)` ve `toggleCommand(String?)`. Firebase'e hiçbir bağımlılığı yoktur, `functions/src/scheduleLogic.ts` ile davranışsal olarak birebir eşdeğerdir (aynı "yakalama" mantığı: tam dakika eşleşmesi değil, "zamanı geçti mi ve bugün tetiklenmedi mi" kontrolü). `lib/models/schedule.dart`'taki mevcut `Schedule`/`ScheduleType` modelini kullanır, yeni bir veri tipi tanımlamaz.

**`lib/services/background_scheduler.dart` (yeni):** `@pragma('vm:entry-point')` ile işaretli top-level `callbackDispatcher()` fonksiyonu (WorkManager'ın gerektirdiği giriş noktası) ve `Future<void> initializeBackgroundScheduler()` fonksiyonu (WorkManager'ı başlatır ve periyodik görevi kaydeder). Firebase okuma/yazma mantığı burada, saf değerlendirme mantığından ayrı tutulur.

**`lib/main.dart` (değişecek):** `runApp()` çağrısından önce `await initializeBackgroundScheduler();` eklenir.

**`pubspec.yaml` (değişecek):** `workmanager` bağımlılığı eklenir.

**Android manifest:** `workmanager` paketi kendi gerekli izinlerini (`RECEIVE_BOOT_COMPLETED` vb.) genellikle otomatik ekler; implementasyon sırasında `android/app/src/main/AndroidManifest.xml`'in gözden geçirilmesi gerekebilir.

## Test

`schedule_evaluator.dart`, `functions/src/scheduleLogic.test.ts` ile birebir aynı senaryoları kapsayan bir Dart test dosyasıyla (`test/services/schedule_evaluator_test.dart`) TDD ile geliştirilir — saat bazlı tetikleme/yakalama, gün eşleşmesi, aynı gün tekrar tetiklenmeme, devre dışı zamanlamalar, countdown tetikleme/kendini kapatma, toggle mantığı.

`background_scheduler.dart` gerçek bir Firebase bağlamı ve WorkManager isolate ortamı gerektirdiği için otomatik testi kapsam dışıdır (tıpkı `functions/src/index.ts` gibi) — doğrulama `flutter analyze` ve manuel cihaz testiyle yapılır.

## Kapsam Dışı

- iOS arka plan görevi desteği.
- Pil optimizasyonundan muafiyet isteme akışı (kullanıcıya öneri olarak belirtilebilir ama otomatik istenmeyecek).
- GitHub Actions mekanizmasının kaldırılması — o mekanizma yedek olarak korunur, bu tasarım kapsamında değiştirilmez.
- Android WorkManager'ın 15 dakikadan daha sık çalışmasını zorlamak (Android'in kendi platform kısıtlaması, aşılamaz).
