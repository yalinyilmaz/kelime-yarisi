# Kelime Yarışı

Flutter ile geliştirilen, 2–5 kişinin aynı odada eş zamanlı olarak aynı soru setini oynadığı mobil kelime yarışması.

## Ürün akışı

- Oyunculardan biri oda oluşturur ve oda kodunu paylaşır.
- Diğer oyuncular kendi telefonlarından odaya katılır.
- Oda dolup herkes hazır olduğunda ortak dört dakikalık sayaç başlar.
- Her oyuncu aynı soruları kendi hızında çözer; alınan harf yalnızca o oyuncunun ekranında açılır.
- Oyun sonunda puanlar ve sıralama birlikte gösterilir.

## Geliştirme adımları

1. **Temel proje ve oda akışı:** Clean Architecture klasörleri, tema, Bloc/Cubit, oda oluşturma/katılma ve lobi önizlemesi.
2. **Canlı oda altyapısı:** Firebase anonim oturum, Realtime Database oda/presence yapısı, hazır durumu ve senkron geri sayım. ✅
3. **Oyun motoru:** Ortak soru seti, kişisel ilerleme/harf alma, cevap doğrulama, puanlama, ortak süre ve canlı skor. ✅ (RTDB kuralları 14 Ekim 2026’da canlıya deploy edildi)
4. **Sonuç deneyimi:** Sıralama, yeniden oynama, bağlantı kopması ve oyuna geri dönme senaryoları.
5. **Online eşleşme:** Ev modu dışında herkese açık oda ve oyuncu eşleştirme.
6. **Turnuva modu:** Denk zorlukta farklı soru setleri ve 24 saatlik asenkron turlar.

## Mimari

Özellik bazlı sade Clean Architecture kullanılır:

```text
lib/
├── app/
├── core/
└── features/
    └── room/
        ├── data/
        ├── domain/
        └── presentation/
```

State management için `flutter_bloc` ve Cubit kullanılır. Yalnızca gerçek bir bağımlılık sınırı gerektiğinde soyutlama eklenecektir; bu nedenle başlangıçta boş repository/use-case katmanları bulunmaz.

## Şu anki durum

Step 3 oyun motoru eklendi. Android ve iOS uygulamaları `kelime-yarisi-yalin` Firebase projesine bağlıdır. Oyuncular anonim oturumla oda oluşturabilir veya oda koduyla katılabilir; oyuncu, bağlantı ve hazır bilgileri Realtime Database üzerinden tüm cihazlarda canlı güncellenir. Oda dolup herkes hazır olduğunda sunucu saatine bağlı ortak geri sayım başlar; lobi oyun ekranına geçer.

Klasik mod `classic-v1` ile 14 soru / 4 dakika, hızlı mod `quick-v1` ile 7 soru / 2 dakika oynatır. Soru seti geri sayım başlatılırken odaya bağlanır. İlk prototipte sürümlü soru bankası uygulamada bulunur; aynı moddaki tüm odalar aynı seti kullanır. Set içeriği değiştirilirse yeni bir sürüm kimliği kullanılmalıdır.

Her kapalı harf 100 puandır. Harf alma soru değerini 100 azaltır; son harf açılmaz. Doğru cevap soru değerini ekler. Yanlış cevap ve “Bilemiyorum” soru değerini düşürür ve sonraki soruya geçer. Pas yoktur. Süre bittiğinde yalnızca açık soru bilememiş sayılır; henüz açılmamış sorular puanı etkilemez. Tüm sorular erken tamamlanırsa oyuncu ortak sürenin bitmesini bekler. Eşit puanlı oyuncular aynı sırayı paylaşır.

Oyuncunun ilerlemesi `rooms/$roomId/progress/$uid` altında tutulur. İlerleme kaydı onaylanmadan yeni işlem yapılmaz; hata durumunda son onaylı durum korunur. Sunucu saati ve bağlantı alınmadan cevap/harf işlemleri kapalıdır. Süre bitince oyuncu kendi sonucunu kaydeder; herhangi bir oda üyesi `results` durumuna geçirebilir. Host bağlantısı kopsa da bağlı bir üye turu kapatabilir. Çevrimdışı oyuncuların eksik sonuçları “Sonuç bekleniyor” olarak görünür; sunucuda otomatik kapatma ve tam geri bağlanma Step 4 kapsamındadır.

Kurallar oyuncu sahipliğini, ilerleme sırasını, puan sınırlarını, zaman sınırını ve tamamlanmış sonuçların değiştirilememesini kontrol eder. **Cevaplar ve kesin puan hâlâ istemcide doğrulanır; bu yapı public matchmaking için hileye dayanıklı değildir.** Public oyun öncesi server-authoritative doğrulama gerekir.

Step 3 için güncellenen `database.rules.json`, 14 Ekim 2026’da `kelime-yarisi-yalin` projesine deploy edildi. Oyun testi için cihazlarda Step 3 içeren uygulama sürümü kullanılmalıdır; eski sürümler gerekli soru seti kimliğini yazmadığından geri sayımı başlatamaz. Kuralların sonraki güncellemelerinde deploy komutu:

```sh
firebase deploy --only database --project kelime-yarisi-yalin
```

Oyun/ekran testleri `flutter test` ile çalışır. Güvenlik testleri yalnızca `demo-kelime-yarisi` emulator projesini kullanır. Realtime Database emulator 127.0.0.1:9000 üzerinde çalışırken:

```sh
npm install --prefix /tmp/kelime-yarisi-rules-test @firebase/rules-unit-testing firebase
NODE_PATH=/tmp/kelime-yarisi-rules-test/node_modules node test/firebase/database_rules_test.cjs
```

Sıradaki adım Step 4: rövanş, yeniden oynama, bağlantı kaybı ve odaya geri dönme senaryoları. İki veya daha fazla fiziksel cihazla yarışma henüz doğrulanmadı.

## Güvenlik ve canlıya çıkış

- Firebase istemci yapılandırmaları yalnızca yerelde tutulur ve Git tarafından izlenmez.
- Realtime Database kuralları üretime gönderilmeden önce emulator üzerinde doğrulanmalıdır. Kurallar `firebase deploy --only database` komutu çalıştırılana kadar canlı projeyi değiştirmez.
- App Check kod tarafında etkindir. Android için Play Integrity, Apple platformları için App Attest + DeviceCheck fallback kullanılır. Debug token'ları Firebase Console'a elle kaydedilmeli ve repoya eklenmemelidir.
- Kısıtlı Android/iOS Firebase API anahtarlarının izin listesinde `firebaseappcheck.googleapis.com` bulunmalıdır; aksi durumda debug token değişimi `403 API_KEY_SERVICE_BLOCKED` ile reddedilir.
- App Check enforcement, geçerli istek metrikleri kontrol edildikten sonra Firebase Console'dan açılmalıdır.
- Store build alınmadan önce Android release/upload keystore yapılandırılmalıdır. Release sürümü bilerek debug anahtarıyla imzalanmaz.
- Skor ve cevap doğrulaması istemciye güvenmemeli; oyun motoru aşamasında güvenilir sunucu tarafında uygulanmalıdır.
