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

Step 3 oyun motoru eklendi. Android ve iOS uygulamaları seçilen `dev` veya `prod` flavor'ının Firebase projesine bağlıdır. Oyuncular anonim oturumla oda oluşturabilir veya oda koduyla katılabilir; oyuncu, bağlantı ve hazır bilgileri Realtime Database üzerinden tüm cihazlarda canlı güncellenir. Oda dolup herkes hazır olduğunda sunucu saatine bağlı ortak geri sayım başlar; lobi oyun ekranına geçer.

Klasik mod `classic-v1` ile 14 soru / 5 dakika 50 saniye, hızlı mod `quick-v1` ile 7 soru / 2 dakika 55 saniye oynatır. Her soru 25 saniyedir. Soru seti ve `gameplayVersion: sync-v1`, geri sayım başlatılırken odaya bağlanır. Soru bankası uygulamada bulunur; set içeriği değiştirilirse yeni bir soru seti sürümü kullanılmalıdır.

Aktif soru, Firebase sunucu saati ve odanın `startsAtMs` değerinden hesaplanır. Host her soruda geçiş yazmaz; tüm cihazlar aynı 25 saniyelik aralığı kullanır. Cevap göndermek veya “Bilemiyorum” seçmek oyuncuyu sonraki soruya geçirmez. Oyuncu ortak sürenin bitmesini bekler. Yanlış cevap veren oyuncunun kutuları kırmızı yanar ve kendi ekranında doğru kelime gösterilir; doğru cevapta kutular yeşil dalgayla vurgulanır. Süre dolunca önceki sorunun doğru cevabı 3 saniyelik bir panelde gösterilir; ortak saat ve sonraki soru bekletilmez. Süre dolunca cevapsız soru bilememiş sayılır. Pas yoktur.

Harf oylaması `rooms/$roomId/hints/$questionIndex` altında transaction ile tutulur. Odanın başlangıçtaki hedef oyuncu sayısı 2–3 ise bir oy harf açar; 4–6 ise iki farklı oyuncu gerekir. İlk oy kaydolur, aynı kişinin tekrar basması ikinci oy sayılmaz. Harf açılınca oylar sıfırlanır. Transaction tekrarları başka bir harfin oylamasına taşınmaz. Aynı oda/soru/harf sırası için bütün cihazlar aynı harf konumunu hesaplar. Son harf kapalı kalır. Cevabını gönderen oyuncunun o soruda yeni oy vermesi engellenir. Oyuncu ayrılması oy eşiğini değiştirmez.

Her kapalı harf 100 puandır. Ortak açılan her harf soru değerini herkes için 100 azaltır. Doğru cevap o anki soru değerini ekler; yanlış cevap, “Bilemiyorum” veya süre dolması soru değerini düşürür. Daha önce kabul edilmiş cevabın puanı sonraki harf açılışlarından etkilenmez. Eşit puanlı oyuncular aynı sırayı paylaşır.

Oyuncunun ilerlemesi `rooms/$roomId/progress/$uid` altında tutulur. Sunucu saati ve bağlantı alınmadan işlemler kapalıdır. İlerleme kaydı onaylanmadan yeni işlem yapılmaz. Geri bağlanan oyuncunun geçmiş cevapsız soruları, kapanmış ortak harf kayıtlarına göre sırayla timeout olarak kaydedilir. Toplam sürenin sonunda bağlı bir oda üyesi `results` durumuna geçirebilir. Tam oda geri yükleme ve sunucuda çevrimdışı oyuncuyu otomatik tamamlama Step 4 kapsamındadır.

Kurallar oyuncu sahipliğini, oy sayısını ve sırasını, soru başına zaman sınırını, ortak harf sayısına göre puan değişimini ve tamamlanmış sonuçların değiştirilememesini kontrol eder. **Doğru cevap olup olmadığı hâlâ istemcide doğrulanır; public matchmaking öncesi server-authoritative cevap doğrulaması gerekir.**

Bu strateji değişikliğinin `sync-v1` kuralları, kullanıcı onayıyla 14 Ekim 2026’da `kelime-yarisi-yalin` projesine deploy edildi. Eski uygulama sürümleri oda başlatamaz; test için bütün cihazlar güncellenmeli ve yeni oda açılmalıdır. Sonraki kural güncellemelerinin deploy komutu:

```sh
npx -y firebase-tools@latest deploy --only database --project dev
```

## Dev ve prod ortamları

- **Dev:** `kelime-yarisi-yalin` / Firebase adı `Kelime Yarisi Dev`. Mevcut veriler ve kullanıcılar bu ortamda kalır. Telefon uygulamasının adı `Kelime Yarışı Dev`; Android kimliği `com.yalinyilmaz.kelime_yarisi.dev`, iOS kimliği `com.yalinyilmaz.kelimeYarisi.dev`.
- **Prod:** `kelime-yarisi-prod` / Firebase adı `Kelime Yarisi`. Telefon uygulamasının adı `Kelime Yarışı`; Android kimliği `com.yalinyilmaz.kelime_yarisi`, iOS kimliği `com.yalinyilmaz.kelimeYarisi`.

Firebase proje kimlikleri değiştirilemez; Console proje adlarında Türkçe karakter ve alt çizgi kabul edilmediği için yukarıdaki adlar kullanılır. İki ortam bağımsız anonim oturum ve Realtime Database kullanır. Prod veritabanı `europe-west1` bölgesindedir; anonim giriş ve mevcut `database.rules.json` kuralları prod'a deploy edilmiştir.

Tek giriş dosyası `lib/main.dart` kullanılır. Firebase seçenekleri Android flavor JSON'undan ve iOS scheme için seçilen plist'ten yüklenir. iOS derlemesi, dosyanın proje ve bundle kimliği ortamla eşleşmezse durur. Ayrı uygulama kimlikleri sayesinde dev ve prod aynı telefonda birlikte kurulabilir.

```sh
flutter run --flavor dev
flutter run --flavor prod
```

`flutter run` varsayılan olarak dev kullanır. VS Code Run and Debug menüsünde `Dev — Run`, `Prod — Run` ve `Prod — Release` seçenekleri vardır. Debug/release derleme modu ortamdan bağımsızdır; `Prod — Run` prod veritabanını debug modunda kullanır. Android release çalıştırması için release keystore yapılandırması gerekir.

Firebase istemci dosyaları Git tarafından izlenmez. Yeni checkout için dosyaları şu komutlarla indir:

```sh
mkdir -p android/app/src/dev android/app/src/prod ios/config/dev ios/config/prod
npx -y firebase-tools@latest apps:sdkconfig ANDROID 1:173227658652:android:12b605e7e0831485004c59 --project dev --out android/app/src/dev/google-services.json
npx -y firebase-tools@latest apps:sdkconfig ANDROID 1:817504723813:android:52f091edbb46b3c725f78c --project prod --out android/app/src/prod/google-services.json
npx -y firebase-tools@latest apps:sdkconfig IOS 1:173227658652:ios:c6e3ba382101755e004c59 --project dev --out ios/config/dev/GoogleService-Info.plist
npx -y firebase-tools@latest apps:sdkconfig IOS 1:817504723813:ios:139356a75102162925f78c --project prod --out ios/config/prod/GoogleService-Info.plist
```

Eski `lib/firebase_options.dart` ve kökteki native Firebase dosyaları kullanılmaz. Kuralların tek kaynağı `database.rules.json`'dır; her ortama açıkça deploy edilir:

```sh
npx -y firebase-tools@latest deploy --only database,auth --project dev
npx -y firebase-tools@latest deploy --only database,auth --project prod
```

Her iki ortamın Android uygulaması Play Integrity, iOS uygulaması App Attest ile App Check'e kayıtlıdır. Debug derlemeleri iki platformda da debug provider kullanır. Cihazın loglarında çıkan debug token'ını **seçtiğin ortamın ve uygulamanın** Firebase Console → App Check → Manage debug tokens bölümüne kaydet. Token'lar repoya eklenmez. Release Android için yayınlama sırasında gerçek upload/Play App Signing SHA-256 sertifikası Firebase'e eklenmelidir. App Check enforcement henüz açılmamıştır.

iOS `Debug`, `Debug-dev` ve `Debug-prod` yapılandırmalarında App Attest entitlement'ı yoktur; Personal Team ile fiziksel cihazda debug çalıştırılabilir. `Profile` ve `Release` yapılandırmalarında App Attest entitlement'ı production ortamını kullanır. Bunları fiziksel cihaz için imzalamak, App Attest destekleyen ücretli Apple Developer Program takımı ve bu yetkiyi içeren provisioning profile gerektirir. Firebase ortamı ile debug/release derleme modu birbirinden bağımsızdır; `Prod — Run` da Personal Team ile debug çalıştırılabilir.

Oyun/ekran testleri `flutter test` ile çalışır. Güvenlik testleri yalnızca `demo-kelime-yarisi` emulator projesini kullanır. Realtime Database emulator 127.0.0.1:9000 üzerinde çalışırken:

```sh
npm install --prefix /tmp/kelime-yarisi-rules-test @firebase/rules-unit-testing firebase
NODE_PATH=/tmp/kelime-yarisi-rules-test/node_modules node test/firebase/database_rules_test.cjs
```

Strateji değişikliği 1. adımı (ortak soru süresi ve harf oylaması), 2. adımı (autofocus ile PIN tarzı kelime girişi), 3. adımı (İngilizce/Türkçe karakter toleransı) ve 4. adımı (ses efektleri) tamamlandı. PIN görünümü, tek ve sabit bir standart Flutter TextField/FocusNode ile oluşturulur. iOS odak isteği sayfa geçişi tamamlandıktan sonra ve soru başına bir kez yapılır; harf oylaması giriş bağlantısını kilitlemez. Sayaç ayrı BlocSelector ile güncellenir; sesler GameAudioCubit üzerinden yönetilir. Oyuncu doğrudan kelime kutularında yalnızca boş harfleri yazar; ortak açılan harfler sabittir. Yeni harf açılırken diğer kutulara yazılanlar korunur. Firebase mapper, sayısal soru anahtarlarının hem map hem liste biçimini destekler; ortak harfler bütün cihazlara taşınır. Yeni soruda giriş temizlenip odaklanır. Cevap, “Cevapla” veya klavyedeki tamam tuşuyla gönderilir; eksik giriş puan kaybettirmez. Cevap doğrulaması büyük/küçük harf ile c/ç, g/ğ, i/ı/İ/I, o/ö, s/ş, u/ü ayrımı yapmaz. Örneğin kapi → KAPI, gokkusagi → GÖKKUŞAĞI doğru kabul edilir. PIN girişinde eşdeğer harfler kelimedeki konumuna göre gerçek Türkçe yazıma çevrilir; yanlış harfler otomatik düzeltilmez. Harf Al’a basınca hafif titreşim, harf gerçekten açıldığında kısa bir mekanik kasa açılışı ve zil efekti çalar; soru süresinin son 5 saniyesinde saniyede bir tik-tak çalar. Bekleyen oylar ve eski Firebase kayıtları ses çaldırmaz. Oyun ekranındaki hoparlör düğmesi oyuncunun sesini açar/kapatır; tercih o ekran oturumu boyunca geçerlidir. Arka plana geçişte ve odadan çıkışta sesler durur. Efektler `assets/audio/` altında projeye özel üretilmiş WAV dosyalarıdır ve `audioplayers` ile yerel olarak çalınır. Doğru cevap kabul edilince kısa bir çift zil sesi, yanlış cevap kabul edilince alçalan bir uyarı sesi ve sistem titreşimi tetiklenir. Doğru cevap titreşim yapmaz. Eksik giriş, başarısız kayıt ve süre dolması cevap efekti üretmez. Ses kapatma titreşimi kapatmaz; arka planda ikisi de çalışmaz. Eski cevaplar ve yinelenen snapshot’lar efektleri tekrar çaldırmaz. Ses veya titreşim hatası oyun akışını kesmez. Ardından Step 4: rövanş, yeniden oynama ve tam oda geri yükleme. Birden fazla fiziksel cihazla yeni strateji henüz doğrulanmadı.

## Soru havuzu — yerel/emulator aşaması

Çekirdek uygulandı: bağımsız soru kayıtları, kaynak/izin bilgisi, editör onayı, yayın artefaktı, cihaz geçmişi, kurallı ortak set seçimi, geçici rezervasyon ve kapasite raporu. Canlı Firebase projelerine bu çalışma için deploy yapılmadı. Mevcut `Dev — Run` ve `Prod — Run` sabit örnek soruları kullanır; havuz modu ayrı çalıştırılır.

Klasik mod 14 soru ve 4–10 harften ikişer cevap kullanır. Mevcut hızlı mod 7 soru ve her uzunluktan bir cevap olarak korundu. Her modda en az 3 konu ve 3 zorluk seviyesi bulunur; bir konu toplamın en fazla üçte birini yukarı yuvarlanmış olarak, bir zorluk seviyesi toplamın en fazla yarısını yukarı yuvarlanmış olarak kaplar. Harf uzunluğu zorluk yerine geçmez. Aynı cevap, aynı kök ailesi veya editörün ilişkili işaretlediği cevaplar aynı sete alınmaz. Seçim başarısız olduğunda bu sınırlar ve tekrar kuralı gevşetilmez.

**Yerel yayın kapasitesi: 336 kaynaklı, AI editör kontrolünden geçirilmiş farklı ana cevap; her uzunlukta 48.** İlk 140 soruya kullanıcının onayladığı 14 set / 196 soru eklendi. `content/questions.json` çalışma havuzu; `functions/content/published.json` backend yayın artefaktıdır. Kontrol türü `ai-self-review` olarak kaydedilir; insan editör onayı değildir. Teorik üst sınır 24 klasik oyundur; konu/zorluk/kök dengesi gerçek kapasiteyi azaltabilir. 90 gün × 3 oyun senaryosu için her uzunlukta en az 492 yeni cevap daha gerekir. Kaynaklar, atıflar, editör kararları ve yeni parti akışı [content/README.md](content/README.md) içinde açıklanır.

`functions/content/examples.json` içindeki 42 eski fixture ayrı kalır; 336 gerçek kayda eklenmez. Örnekler sadece demo emulator ortamında `QUESTION_POOL_EXAMPLES=true` ile seçilebilir ve deploy paketinden çıkarılır. Normal emulator profili artık gerçek yayın havuzunu kullanır. Prod ayrı kalır; dev havuzu yalnız açık proje hedefiyle dağıtılır.

### Cihaz geçmişi ve boyut

SQLite sadece cevap kimliği, soru kimliği ve ilk görülme zamanını saklar. Soru metni ve cevap metni bu geçmiş veritabanına yazılmaz; büyük soru havuzu mobil uygulamaya gömülmez. Aktif oyunun 14/7 sorusu oda verisinden alınır; Firebase SDK'sının mevcut sınırlı oda cache'i ayrı bir mekanizmadır.

Cevap kimliği Türkçe NFC yazımı ve I/ı–İ/i dönüşümü üzerinden üretilir. Soru metni/anlam varyantı değişince cevap kimliği değişmez. Oyuncunun ASCII karakterle cevap yazabilmesi ile kalıcı kelime kimliği birbirinden ayrıdır.

Geçmiş hesap bazında değildir; o telefonda/app kurulumunda kalır. Uygulama verisi silinirse sıfırlanır. Geçmiş dizini Android cloud backup/device transfer ve iOS yedeklerinden çıkarılır; OS cache temizliğinde kaybolmaması için kalıcı uygulama alanında tutulur. Kaydın cihazda commit edilmesi beklenmeden soru gösterilmez. Arka planda geçen ve sadece timeout ile atlanan sorular görülmüş sayılmaz. Bir çökme tam commit ile ekranın çizilmesi arasına denk gelirse tek bir gösterim niyeti konservatif biçimde görülmüş kalabilir; ayrılan setin tamamı geçmişe yazılmaz.

64 karakterli hash kimlikleriyle iki `WITHOUT ROWID` tablo ölçümü: 3.780 cevap + 3.780 soru yaklaşık 0,68 MiB; 10.000 + 10.000 yaklaşık 1,75 MiB; 50.000 + 50.000 yaklaşık 8,71 MiB. Bunlar çalışma sırasında oluşan veri boyutlarıdır, indirme/bundle boyutu değildir. Soru havuzunu genişletmek uygulamanın içine ek metin eklemez.

### Emulator ile çalıştırma

Functions Node 22 kullanır; en güncel JavaScript test SDK'sı Node 24 gerektirir. Aşağıdaki `npx` komutları sistemdeki Node sürümünü değiştirmeden gerekli çalışma zamanlarını kullanır. Java 21+ gerekir.

```sh
npm ci --prefix functions
npx -y -p node@22 -p firebase-tools@latest firebase emulators:start --only auth,database,functions --project demo-kelime-yarisi
```

Emulator açıkken VS Code'da `Dev — Question Pool (iOS Simulator)` veya `Dev — Question Pool (Android Emulator)` seç. iOS simulator localhost'u; Android emulator `10.0.2.2` adresini kullanır. Bunlar simulator/emulator profilleridir; fiziksel telefonda localhost bilgisayarı göstermez. `functions/.env.local` içinde `QUESTION_POOL_EXAMPLES=false` ile 336 soruluk gerçek havuz açılır. Eski 42 fixture için açıkça `true` seçilebilir. Havuz değişince Functions emulator'ını yeniden başlat. Boş havuzun tükenme davranışı ayrı entegrasyon testinde kontrol edilir. Backend emulator, `demo-kelime-yarisi` dışındaki proje adlarını reddeder. Mobil emulator bağlantısı da yalnızca dev debug için kabul edilir; dev/prod native Firebase cache'inden ayrı bir named app kullanılır.

```sh
flutter run --flavor dev --dart-define=QUESTION_POOL_ENABLED=true --dart-define=USE_FIREBASE_EMULATORS=true
```

Backend sadece oda sahibinin başlatmasına ve oda üyelerinin geçmiş hazırlığına izin verir. Her cihaz kendi yerel kimlik listesini geçici olarak iletir; tüm oyuncuların görülmüş/ayrılmış cevapları ortak seçimden çıkarılır. Hazırlık 25 saniye geçerlidir; başlamazsa hazır durumu yenilenir. Kalıcı sunucu geçmişi tutulmaz. Aktif set rezervasyonu oyunun süresi + 30 saniye için geçerlidir; süresi dolan kayıtlar seçimden hemen çıkarılır ve periyodik temizlenir. Aynı oda/kurulum kimliği ile yinelenen başlatma istekleri aynı kaydedilmiş seti kullanır. Oda silinirse tamamlanmamış seçim odayı yeniden yaratmaz.

Başlangıç sürümünde aktif rezervasyonlar tek atomik RTDB transaction ile seçilir ve 300 eşzamanlı rezervasyonla sınırlandırılır; yoğunlukta açık hata döner. Bu seçim katmanı yük altında ölçülmeden büyük trafik garantisi verilmez. Set parmak izi sıralanmış cevap kimliklerinden üretilir; farklı kullanıcı gruplarında global set benzersizliği zorlanmaz. Aynı soru farklı kullanıcılarda kullanılabilir. Yerel geçmiş kullanıcı cihazından geldiği için hesabın tüm cihazlarında tekrar engeli veya hileye karşı sunucu geçmişi garantisi verilmez.

Lobide toplam/onaylı/yayındaki/kalan cevap sayıları, engelleyen uzunluklar ve günde 3 oyun için teorik süre görünür. Ortak set oluşturma hatasında bütün oyuncuların birleşik raporu gösterilir. Konu, zorluk ve kök sınırları kapasite üst sınırını düşürebilir; kombinasyon sayısı tekrarsız oyun sayısı olarak sunulmaz.

### İçerik hazırlama ve editörlük

```sh
npm run content --prefix functions -- draft --answer kapı --id kapi-giris-01
```

Taslakta hedef anlam, soru, konu, gerçek zorluk, kök ailesi/ilişkili cevaplar ve `source` alanlarını doldur. `source.reference` doğrulama kaynağını, `meaningEvidence` seçilen anlamın kanıtını, `termsReference` kullanım koşullarını gösterir. İzin durumu `original`, `licensed` veya `public-domain` olarak doğrulanmadan yayın onayı verilemez. İzin gerektiğinde `permission-required`, bilinmiyorsa `unknown` kullan. Yarışma arşivleri izin varmış gibi kopyalanmaz.

```sh
npm run content --prefix functions -- validate
npm run content --prefix functions -- prompt --id kapi-giris-01
npm run content --prefix functions -- review --id kapi-giris-01 --editor EDITOR_ADI --checks spelling,meaning,uniqueAnswer,noLeak,originality,sourceRights
npm run content --prefix functions -- publish
npm run content --prefix functions -- report --file functions/content/published.json
```

`prompt` sadece istem yazar. Gerçek toplu API adaptörü `content:replenish` komutudur: kaynaklı kelimelerden üç soru adayı üretir; `--ai-review` ile ayrı bir Türkçe editör çağrısı yapar. Anahtar sadece yerel `OPENAI_API_KEY`, model açık `--model`/`OPENAI_MODEL` üzerinden verilir. API adaptörü kontrollü HTTP yanıtlarının yanında gerçek `gpt-6-luna` üretim/editör denemesiyle de test edildi: iki çağrıda 1.306 giriş ve 1.875 çıktı token’ı. FLÜT adayı editörce kaynak metne yakın olduğu için reddedildi; 140 soruluk yayın havuzu değiştirilmedi. API’ye mevcut havuz gönderilmez; yalnızca seçili kelime ve açık kaynak kanıtı gönderilir, benzerlik kontrolü yerelde kalır. İlk 140 soru Codex oturumunda kaynaklar okunup ayrı editör turundan geçirilerek hazırlandı. İnsan onayı varmış gibi işaretlenmez.

Otomatik kontroller Türkçe normalizasyonu/uzunluğu, kimliği, açık cevap/kök sızıntısını ve çok benzer soru metinlerini yakalar. Anlam, doğal Türkçe ve aynı uzunluktaki alternatif cevaplar editör turunda incelenir. Kullanıcının tercihiyle AI kendi ürettiği metni ayrı bir turda inceleyebilir; gerekçe, kaynak desteği ve alternatif cevap kaydı şarttır. Bu yöntem hatasızlık garantisi değildir. Yeni kaynak toplama, eksik grupları besleme, API üretimi, inceleme ve kalite ölçüm komutları [content/README.md](content/README.md) içindedir.

`review` altı kontrolün hepsini ve editör adını ister; onay içeriğin hash'ine bağlıdır. Onaydan sonra metin/kaynak/kök değişirse yeniden inceleme gerekir. `publish` yalnızca onaylı üretim kayıtlarından yerel backend artefaktını oluşturur; Firebase'e deploy etmez. Yeni partilerde kelime/kaynak tedariki devam eder. API üretimini çalıştırmak için yerel API anahtarı ve açık model seçimi gerekir. Yerel araç kontrollü parti komutuyla çalışır. Dev bulut üreticisi her gün İstanbul saatiyle 04.00’te yeni sorular hedefler; editörden geçenler özel RTDB havuzuna eklenir ve yeni oyunlarda yeniden deploy olmadan kullanılır. Prod bu aşamada değiştirilmez.

### Kontroller

Dev bulut üreticisi günde 42 onaylı soru, her uzunluktan altı adet hedefler. Kalıcı RTDB sayacı günde 60 deneme / 120 istek, beş art arda başarısız sonuç ve model maliyetinde 0,50 USD/gün, 10 USD/ay sınırları uygular. API anahtarı yalnızca üreticiye bağlı dev Secret Manager kaydındadır. Kaynak kuyruğu 90 önceki taslağa eklenen 16 karma cevap adayıyla 106 kayıttır; bunlar onaysızdır ve yayın sayısına dahil değildir. Güncel yayın havuzu 336 ana cevaptır. Üretici ve editör isimlerin yanında edat, bağlaç, mastar ve en fazla iki kelimeli ad/edat/fiil öbeklerini kabul eder. Boşluklar korunur; yalnız harfler 4–10 sınırına sayılır. Aynı harf/kelime düzenindeki doğru eşdeğerler `acceptedAnswers` içine alınır; eş anlamlı olması tek başına ret sebebi değildir. Stok tükenmesi/retler eksik hedef olarak raporlanır. Ayrıntılar [dev zamanlaması ve prod'a taşıma](content/README.md#dev-bulut-zamanlaması) bölümündedir. Yerel CLI ve bulut sayaçları ayrıdır.

```sh
flutter analyze
flutter test
npm test --prefix functions
npx -y -p node@22 -p firebase-tools@latest firebase emulators:exec --only auth,database,functions --project demo-kelime-yarisi 'npx -y -p node@24 node --test --test-force-exit functions/test/emulator.integration.js && NODE_PATH=functions/node_modules npx -y -p node@24 node test/firebase/database_rules_test.cjs'
```

Mobil entegrasyon testi de aynı emulator oturumunda çalıştırılabilir:

```sh
flutter test integration_test/question_pool_emulator_test.dart --flavor dev -d IOS_SIMULATOR_ID --dart-define=QUESTION_POOL_ENABLED=true --dart-define=USE_FIREBASE_EMULATORS=true
```

Dev bulut havuzu cihaz kabul testi için **Dev — Cloud Question Pool** profilinden açılır. Dev App Check debug token’ları Firebase Console’da kayıtlı olmalıdır. Prod’a geçiş ayrı adımdır: dev’de test edilen yayımlanmış sorular kimlikleri korunarak taşınır; prod secret, sayaçlar, üretici hesabı ve zamanlama ayrı kurulur. Normal Dev/Prod profillerinin havuz bayrağı korunur. Mevcut puan/cevap doğrulamasının istemciye güvenme sınırı devam eder.

## Güvenlik ve canlıya çıkış

- Firebase istemci yapılandırmaları yalnızca yerelde tutulur ve Git tarafından izlenmez.
- Realtime Database kuralları üretime gönderilmeden önce emulator üzerinde doğrulanmalıdır. Kurallar `firebase deploy --only database` komutu çalıştırılana kadar canlı projeyi değiştirmez.
- App Check kod tarafında etkindir. Release Android için Play Integrity, iOS için App Attest; debug derlemelerinde iki platformda da debug provider kullanılır. Debug token'ları ilgili ortamın Firebase Console'una elle kaydedilmeli ve repoya eklenmemelidir.
- Kısıtlı Android/iOS Firebase API anahtarlarının izin listesinde `firebaseappcheck.googleapis.com` bulunmalıdır; aksi durumda debug token değişimi `403 API_KEY_SERVICE_BLOCKED` ile reddedilir.
- App Check enforcement, geçerli istek metrikleri kontrol edildikten sonra Firebase Console'dan açılmalıdır.
- Store build alınmadan önce Android release/upload keystore yapılandırılmalıdır. Release sürümü bilerek debug anahtarıyla imzalanmaz.
- Skor ve cevap doğrulaması istemciye güvenmemeli; oyun motoru aşamasında güvenilir sunucu tarafında uygulanmalıdır.

Sayfa geçişleri GoRouter ile ana sayfa, oluştur/katıl formu, oda ve oyun rotalarından yönetilir. Oda/oyun verisi bulunmayan bir rota ana sayfaya döner. Presentation widget’ları kendi dosyalarındadır. `GameCubit` puan, harf oyu ve ortak soru senkronizasyonunu; `GameFeedbackCubit` sonuç gösterim süresini; `GameAudioCubit` ses tercihi ve ses yaşam döngüsünü yönetir. Harf Al ve Cevapla klavyeyi kapatmaz; diğer alanlara dokunma ve sayfayı kaydırma kapatır. Cevap kaydedilince giriş kilitlenir, odak bağlantısı yeni soruya kadar korunur.
