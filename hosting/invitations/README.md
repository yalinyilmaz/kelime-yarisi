# Oda davetleri

Dev adresi: `https://kelime-yarisi-yalin.web.app/invite/ABC-234`.
Kod paylaşılırken clipboard'a ham oda kodu kopyalanır; paylaşım mesajına bağlantı ve kod eklenir.
Uygulama bağlantıyı alınca doğrudan odaya katılır. Oyuncu adı yoksa adım tamamlandıktan sonra otomatik katılım devam eder. Katılım reddedilirse bilgilendirme ekranında aynı daveti tekrar deneme ve ana menüye dönme seçenekleri sunulur. Açık oyun/oda varken davet mevcut oyunu terk ettirmez.

## Dev kurulumu

- `public/config.js`: Android için Play Console'un test katılım URL'si; iOS için geçici olarak App Store ana sayfası.
- `public/.well-known/assetlinks.json`: dev Firebase Android uygulamasında kayıtlı SHA-256 sertifikaları. Play App Signing anahtarı değişirse burayı güncelle; upload ve Play dağıtım imzaları farklı olabilir.
- `public/.well-known/apple-app-site-association`: dev Team ID + Bundle ID eşleşmesi.
- Android manifest yalnız dev flavor'da bu HTTPS alan adını doğrular.
- iOS Runner'ın üç dev konfigürasyonu `Runner/Runner-dev.entitlements` kullanır. Apple Developer → Identifiers → `com.yalinyilmaz.kelimeYarisi.dev` → Associated Domains etkin olmalı. App Distribution Ad Hoc provisioning profili bu capability ile yeniden oluşturulmalı/indirilmeli; eski profil kullanılamaz.
- Yeni bir dev build kur. Eski build bu native ayarları içermez. Apple/Android alan adı doğrulaması ve önbellek nedeniyle bağlantı testi, mesaj/e-posta içindeki bağlantıya dokunularak yapılmalı; adresi Safari'ye yazmak aynı davranışı garantilemez.

Yalnız dev Hosting yayını:

```sh
firebase deploy --only hosting --project kelime-yarisi-yalin
```

`hosting.site` özellikle dev site kimliğine sabitlenmiştir. Prod yayını için ayrı site/yapılandırma gerekir.
HTTPS sayfa, OS uygulamayı açmazsa Android test sayfasına veya iOS App Store'a yönlendirir. Masaüstünde kodu gösterir. Bu bir deferred deep link hizmeti değildir: kurulumdan sonra davete tekrar dokunmak veya kodu girmek gerekir.

## Production

`production.example.json` içindeki üç adres ve Dart `RoomInvitation.prodBaseUrl` bilerek boş. Dev domaine prod uygulaması eklenmemeli. Gerçek domain, mağaza adresleri, prod sertifikaları, AASA ve native prod ayarları yayın öncesi birlikte hazırlanmalı.
Git dışında tutulan ana kontrol listesi: `.local/PRODUCTION_TODO.md`.

Resmî kaynaklar: [Flutter deep links](https://docs.flutter.dev/ui/navigation/deep-linking), [Android App Links](https://developer.android.com/training/app-links/configure-assetlinks), [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).
