# Hata Düzeltmeleri + Aurora Glass Yeniden Tasarım — Tasarım

## Amaç

İki iş tek pakette:

1. **Hata/eksik düzeltmeleri:** Kod denetiminde bulunan bellek sızıntıları, sahte çevrimiçi göstergesi, çökme riskleri ve kullanımdan kalkmış API'ler giderilir; kullanılmayan zamanlama özelliği tamamen kaldırılır.
2. **Görsel yeniden tasarım:** Tüm ekranlar "Aurora Glass" görsel diline taşınır — koyu lacivert zemin üzerinde aurora ışık kümeleri, buzlu cam kartlar, mavi-mor degrade vurgular. Kontrol ekranında merkezde büyük dairesel güç düğmesi (kullanıcı tarafından mockup üzerinden seçildi: "Varyant 1 — hero buton").

## Bölüm 1: Kaldırılacaklar — Zamanlama Özelliği

Kullanıcı kararı: zamanlama özelliği kullanılmayacak, komple kaldırılacak.

**Silinecek dosyalar:**
- `lib/models/schedule.dart`, `test/models/schedule_test.dart`
- `lib/services/schedule_service.dart`
- `lib/widgets/schedule_sheet.dart`
- `functions/` dizini (package.json, tsconfig, jest config, src/*)
- `.github/workflows/relay-schedule.yml`

**Temizlenecek kod:**
- `lib/screens/control_screen.dart`: Zamanlama bölümü, `_ScheduleRow`, `_showAddScheduleSheet`, `ScheduleService` alanı ve ilgili import'lar (bu ekran zaten yeniden yazılacağı için yeni sürümde hiç yer almaz).

**Korunacaklar:**
- `firebase.json`, `.firebaserc`, `database.rules.json` (güvenlik kuralları hâlâ gerekli)
- `docs/superpowers/` altındaki eski spec/plan dosyaları (tarihsel kayıt)

**Kullanıcının manuel yapacakları (opsiyonel):** GitHub repo ayarlarından `FIREBASE_SERVICE_ACCOUNT_KEY` secret'ını silme; Firebase RTDB'deki mevcut `schedules` düğümlerini temizleme (zararsızdır, silinmese de olur).

## Bölüm 2: Hata Düzeltmeleri

1. **RTDB dinleyici sızıntısı:** `control_screen.dart` (`_listenDevice`) ve `home_screen.dart` (`_listenDevices`) `.onValue.listen()` aboneliklerini `StreamSubscription` olarak saklayıp `dispose()` içinde iptal edecek. Ayrıca callback'lerde `setState` öncesi `mounted` kontrolü yapılacak.
2. **Gerçek çevrimiçi göstergesi:**
   - **Firmware tarafı:** `firebaseSetState()` gövdesindeki `lastSeen` alanı `{".sv": "timestamp"}` (Firebase sunucu epoch'u) olarak yazılır. Ek olarak `pollFirebase()` döngüsünde ~30 saniyede bir salt `lastSeen` heartbeat PATCH'i gönderilir (cihaz durum değiştirmese de "yaşıyorum" sinyali).
   - **Uygulama tarafı:** `Device.lastSeen` epoch-ms olarak yorumlanır; `now - lastSeen < 90 saniye` ise çevrimiçi kabul edilir. Home kartlarında yeşil/kırmızı durum noktası + "X dk önce görüldü" metni; kontrol ekranında başlık altında aynı bilgi. `lastSeen == 0` veya eski-format küçük değerler "Bilinmiyor/Çevrimdışı" sayılır (geriye dönük uyumlu).
3. **`mounted` kontrolleri:** Tüm ekranlarda `await` sonrası `setState`/`Navigator` çağrıları `mounted` guard'ı ile korunur (eski schedule_sheet örneği siliniyor ama aynı hata deseni diğer ekranlarda da taranıp düzeltilir — örn. provision/scan akışları).
4. **Timer sızıntısı:** `scan_screen.dart` `_pollForEspConnection` Timer'ı state alanında saklanıp `dispose()` içinde iptal edilir.
5. **Bozuk Settings navigasyonu:** Yeni ortak alt navigasyon bileşeni Settings'e basıldığında her ekranda aynı ayar bottom-sheet'ini açar ('/home'a yönlendirme hatası ortadan kalkar).
6. **Kullanımdan kalkmış API'ler:** `withOpacity` → `withValues(alpha:)`, `Switch.activeColor` → `activeThumbColor`. Yeniden yazılan ekranlarda sıfır deprecation uyarısı hedeflenir.
7. **Test:** `test/widget_test.dart` silinir; yerine tema sabitleri ve `Device` modeli için anlamlı birim testleri konur (`test/models/device_test.dart`: `fromMap` varsayılanları + yeni `isOnline` hesabı). Firebase'e bağımlı ekranlar widget-test edilmez (mevcut konvansiyon).

## Bölüm 3: Aurora Glass Görsel Dili

**Palet ve sabitler** (`lib/theme/app_theme.dart` — yeni dosya, tüm ekranlardaki kopya renk sabitlerinin yerini alır):
- Zemin: radyal degrade `#1B2743 → #0D1321 → #090D18`
- Aurora kümeleri: mor `#7C3AED` (sağ üst), gök mavisi `#38BDF8` (sol alt) — düşük opaklıkta radyal degradeler
- Vurgu degradesi: `#38BDF8 → #818CF8` (butonlar, aktif anahtarlar, ikon arka planları)
- Cam kart: `Colors.white` %7 opaklık + `BackdropFilter(blur: 12-14)` + %14 beyaz kenarlık, 16-20px köşe yarıçapı
- Durum: çevrimiçi/açık `#34D399` (yeşil), çevrimdışı/hata `#F87171` (mercan), pasif metin `#8B96B5`
- Ortak widget'lar `lib/widgets/` altına: `aurora_background.dart` (zemin + ışık kümeleri), `glass_card.dart`, `app_bottom_nav.dart` (şu an 3 ekranda kopyalanan `_BottomNav`/`_NavItem`), `gradient_button.dart`

**Ekranlar:**

1. **Login:** Aurora zemin; logo yuvarlak degrade rozette; form cam kartta; "Giriş Yap" degrade buton; Google butonu cam kart. Yapı/akış değişmez.
2. **Home (Cihazlarım):** Cam cihaz kartları — sol tarafta degrade daire ikon, cihaz adı + durum satırı (yeşil/kırmızı nokta + "Açık · şimdi görüldü" / "Çevrimdışı · 5 dk önce"), sağda degrade anahtar. Karta ⋮ menü düğmesi eklenir (Yeniden adlandır kapsam dışı; sadece "Cihazı Sil" — mevcut uzun basma da korunur). Boş durum ekranı aynı dile çevrilir.
3. **Kontrol ekranı (Varyant 1 — hero güç düğmesi):** Üstte geri ok + "CİHAZ KONTROL" başlığı + ayar (reset) düğmesi; cihaz adı büyük, altında çevrimiçi durumu; merkezde ~150px dairesel güç düğmesi — dış halka cam, iç daire kapalıyken soluk cam, açıkken mavi-mor degrade + dış parlama (glow) animasyonu; dokunma anında hafif ölçek animasyonu; altında "RÖLE AKTİF"/"RÖLE KAPALI" durum hapı; en altta bilgi çipleri satırı (Cihaz ID, Son görülme). Zamanlama bölümü YOK.
4. **Scan:** Radar animasyonu korunur, renkler Aurora paletine çevrilir; ağ listesi cam kartta; ESP cihazı satırı degrade vurgulu; "Scan Again" degrade buton. Başlıklar Türkçeleştirilir ("Yakındaki Ağlar").
5. **Provision:** Mevcut yapı korunur, renk/kart/buton dili Aurora Glass'a çevrilir.

**Etkileşim detayları:**
- Güç düğmesi: `AnimatedContainer`/`AnimatedScale` ile 250-300ms durum geçişi; bekleyen komut sırasında (command != state) düğme ortasında küçük spinner
- Kartlar: basılınca hafif opaklık geri bildirimi (`InkWell` splash yerine custom pressed-state, cam görünümü bozulmasın diye)
- Tüm ekran geçişleri mevcut route yapısıyla aynı kalır

## Kapsam Dışı

- ESP provision akışının işlevsel değişikliği (sadece görsel)
- Cihaz yeniden adlandırma, çoklu röle, tema seçimi (açık tema yok — tek koyu tema)
- iOS'a özgü uyarlamalar
- Firebase veri şeması değişikliği (`lastSeen` formatı hariç — o da geriye dönük uyumlu)

## Doğrulama

- `flutter analyze` temiz (yeni/değişen dosyalarda 0 uyarı)
- `flutter test` yeşil (yeni device testi dahil)
- Manuel: gerçek cihazla aç/kapat, çevrimiçi göstergesinin cihaz fişten çekilince ~90 sn içinde "Çevrimdışı"a düşmesi, her ekranın görsel kontrolü
