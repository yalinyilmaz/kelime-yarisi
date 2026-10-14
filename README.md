# Kelime Yarışı

Flutter ile geliştirilen, 2–6 kişinin aynı odada eş zamanlı olarak aynı soru setini oynadığı mobil kelime yarışması.

## Ürün akışı

- Oyunculardan biri oda oluşturur ve oda kodunu paylaşır.
- Diğer oyuncular kendi telefonlarından odaya katılır.
- Oda dolup herkes hazır olduğunda ortak geri sayım başlar; her soru 25 saniye oynanır.
- Herkes aynı soruyu aynı anda görür. 2–3 kişide bir, 4–6 kişide iki farklı oyuncunun oyuyla aynı harf herkesin ekranında açılır.
- Oyun sonunda puanlar ve sıralama birlikte gösterilir.

## Geliştirme adımları

1. **Temel proje ve oda akışı:** Clean Architecture klasörleri, tema, Bloc/Cubit, oda oluşturma/katılma ve lobi önizlemesi.
2. **Canlı oda altyapısı:** Firebase anonim oturum, Realtime Database oda/presence yapısı, hazır durumu ve senkron geri sayım. ✅
3. **Oyun motoru:** Ortak soru turları, ortak harf oylaması, cevap doğrulama, puanlama ve canlı skor. ✅ (sync-v1 RTDB kuralları 14 Ekim 2026’da canlıya deploy edildi)
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

Klasik mod `classic-v1` ile 14 soru / 5 dakika 50 saniye, hızlı mod `quick-v1` ile 7 soru / 2 dakika 55 saniye oynatır. Her soru 25 saniyedir. Soru seti ve `gameplayVersion: sync-v1`, geri sayım başlatılırken odaya bağlanır. Soru bankası uygulamada bulunur; set içeriği değiştirilirse yeni bir soru seti sürümü kullanılmalıdır.

Aktif soru, Firebase sunucu saati ve odanın `startsAtMs` değerinden hesaplanır. Host her soruda geçiş yazmaz; tüm cihazlar aynı 25 saniyelik aralığı kullanır. Cevap göndermek veya “Bilemiyorum” seçmek oyuncuyu sonraki soruya geçirmez. Oyuncu ortak sürenin bitmesini bekler. Yanlış cevapta doğru kelime soru devam ederken açıklanmaz. Süre dolunca cevapsız soru bilememiş sayılır. Pas yoktur.

Harf oylaması `rooms/$roomId/hints/$questionIndex` altında transaction ile tutulur. Odanın başlangıçtaki hedef oyuncu sayısı 2–3 ise bir oy harf açar; 4–6 ise iki farklı oyuncu gerekir. İlk oy kaydolur, aynı kişinin tekrar basması ikinci oy sayılmaz. Harf açılınca oylar sıfırlanır. Transaction tekrarları başka bir harfin oylamasına taşınmaz. Aynı oda/soru/harf sırası için bütün cihazlar aynı harf konumunu hesaplar. Son harf kapalı kalır. Cevabını gönderen oyuncunun o soruda yeni oy vermesi engellenir. Oyuncu ayrılması oy eşiğini değiştirmez.

Her kapalı harf 100 puandır. Ortak açılan her harf soru değerini herkes için 100 azaltır. Doğru cevap o anki soru değerini ekler; yanlış cevap, “Bilemiyorum” veya süre dolması soru değerini düşürür. Daha önce kabul edilmiş cevabın puanı sonraki harf açılışlarından etkilenmez. Eşit puanlı oyuncular aynı sırayı paylaşır.

Oyuncunun ilerlemesi `rooms/$roomId/progress/$uid` altında tutulur. Sunucu saati ve bağlantı alınmadan işlemler kapalıdır. İlerleme kaydı onaylanmadan yeni işlem yapılmaz. Geri bağlanan oyuncunun geçmiş cevapsız soruları, kapanmış ortak harf kayıtlarına göre sırayla timeout olarak kaydedilir. Toplam sürenin sonunda bağlı bir oda üyesi `results` durumuna geçirebilir. Tam oda geri yükleme ve sunucuda çevrimdışı oyuncuyu otomatik tamamlama Step 4 kapsamındadır.

Kurallar oyuncu sahipliğini, oy sayısını ve sırasını, soru başına zaman sınırını, ortak harf sayısına göre puan değişimini ve tamamlanmış sonuçların değiştirilememesini kontrol eder. **Doğru cevap olup olmadığı hâlâ istemcide doğrulanır; public matchmaking öncesi server-authoritative cevap doğrulaması gerekir.**

Bu strateji değişikliğinin `sync-v1` kuralları, kullanıcı onayıyla 14 Ekim 2026’da `kelime-yarisi-yalin` projesine deploy edildi. Eski uygulama sürümleri oda başlatamaz; test için bütün cihazlar güncellenmeli ve yeni oda açılmalıdır. Sonraki kural güncellemelerinin deploy komutu:

```sh
firebase deploy --only database --project kelime-yarisi-yalin
```

Oyun/ekran testleri `flutter test` ile çalışır. Güvenlik testleri yalnızca `demo-kelime-yarisi` emulator projesini kullanır. Realtime Database emulator 127.0.0.1:9000 üzerinde çalışırken:

```sh
npm install --prefix /tmp/kelime-yarisi-rules-test @firebase/rules-unit-testing firebase
NODE_PATH=/tmp/kelime-yarisi-rules-test/node_modules node test/firebase/database_rules_test.cjs
```

Strateji değişikliği 1. adımı (ortak soru süresi ve harf oylaması), 2. adımı (autofocus ile PIN tarzı kelime girişi), 3. adımı (İngilizce/Türkçe karakter toleransı) ve 4. adımı (ses efektleri) tamamlandı. PIN görünümü, tek ve sabit bir standart Flutter TextField/FocusNode ile oluşturulur. iOS odak isteği sayfa geçişi tamamlandıktan sonra ve soru başına bir kez yapılır; harf oylaması giriş bağlantısını kilitlemez. Sayaç ayrı BlocSelector ile güncellenir; sesler BlocListener üzerinden yönetilir. Oyuncu doğrudan kelime kutularında yalnızca boş harfleri yazar; ortak açılan harfler sabittir. Yeni harf açılırken diğer kutulara yazılanlar korunur. Firebase mapper, sayısal soru anahtarlarının hem map hem liste biçimini destekler; ortak harfler bütün cihazlara taşınır. Yeni soruda giriş temizlenip odaklanır. Cevap, “Cevapla” veya klavyedeki tamam tuşuyla gönderilir; eksik giriş puan kaybettirmez. Cevap doğrulaması büyük/küçük harf ile c/ç, g/ğ, i/ı/İ/I, o/ö, s/ş, u/ü ayrımı yapmaz. Örneğin kapi → KAPI, gokkusagi → GÖKKUŞAĞI doğru kabul edilir. PIN girişinde eşdeğer harfler kelimedeki konumuna göre gerçek Türkçe yazıma çevrilir; yanlış harfler otomatik düzeltilmez. Harf gerçekten açıldığında kısa bir elektronik efekt çalar; soru süresinin son 5 saniyesinde saniyede bir tik-tak çalar. Bekleyen oylar ve eski Firebase kayıtları ses çaldırmaz. Oyun ekranındaki hoparlör düğmesi oyuncunun sesini açar/kapatır; tercih o ekran oturumu boyunca geçerlidir. Arka plana geçişte ve odadan çıkışta sesler durur. Efektler `assets/audio/` altında projeye özel üretilmiş WAV dosyalarıdır ve `audioplayers` ile yerel olarak çalınır. Ses hatası oyun akışını kesmez. Ardından Step 4: rövanş, yeniden oynama ve tam oda geri yükleme. Birden fazla fiziksel cihazla yeni strateji henüz doğrulanmadı.

## Güvenlik ve canlıya çıkış

- Firebase istemci yapılandırmaları yalnızca yerelde tutulur ve Git tarafından izlenmez.
- Realtime Database kuralları üretime gönderilmeden önce emulator üzerinde doğrulanmalıdır. Kurallar `firebase deploy --only database` komutu çalıştırılana kadar canlı projeyi değiştirmez.
- App Check kod tarafında etkindir. Android için Play Integrity, Apple platformları için App Attest + DeviceCheck fallback kullanılır. Debug token'ları Firebase Console'a elle kaydedilmeli ve repoya eklenmemelidir.
- Kısıtlı Android/iOS Firebase API anahtarlarının izin listesinde `firebaseappcheck.googleapis.com` bulunmalıdır; aksi durumda debug token değişimi `403 API_KEY_SERVICE_BLOCKED` ile reddedilir.
- App Check enforcement, geçerli istek metrikleri kontrol edildikten sonra Firebase Console'dan açılmalıdır.
- Store build alınmadan önce Android release/upload keystore yapılandırılmalıdır. Release sürümü bilerek debug anahtarıyla imzalanmaz.
- Skor ve cevap doğrulaması istemciye güvenmemeli; oyun motoru aşamasında güvenilir sunucu tarafında uygulanmalıdır.
