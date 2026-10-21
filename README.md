# Kelime Yarışı

Dev mağaza release otomasyonu: [Fastlane kurulumu ve komutlar](fastlane/README.md).

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

Yeni odalar `gameplayVersion: race-v1` ile oynar. Klasik mod 14, hızlı mod 7 sorudur. Her sorunun süresi en fazla 25 saniyedir. İlk doğru cevabı sunucu transaction'ı kabul eder; sadece kazanan soru puanını alır. Diğer oyuncularda cevap kutulara yerleşir, **gerçek oyuncu adı** ile “<oyuncu> bildi 😔” bildirimi ve açılma sesi görünür. Cevap 2 saniye gösterildikten sonra herkes sonraki soruya geçer. Son sorudan sonra da 2 saniyelik gösterimle sonuçlar açılır. Yanlış cevap ve “Bilemiyorum” tek denemeyi tüketir ve soru değerini düşürür; başka birinin bilmesi ek ceza getirmez. Kimse bilemezse süre sonunda cevapsız oyunculara timeout cezası uygulanır ve cevap 2 saniye gösterilir. Toplam oyun süresi doğru cevapların hızına bağlıdır; sabit toplam süre kullanılmaz.

Cevap doğrulama (Türkçe/ASCII toleransı ve kabul edilmiş eş anlamlılar dahil), puanlama, ortak harf oyu ve geçişler `playRace` callable üzerinden sunucuda yönetilir. Oda snapshot'ı bütün cihazlarda aynı kazananı, puanı ve soru saatini taşır. Cevap/harf butonları klavyeyi kapatmaz. Ortak harf kuralları aynı: 2–3 kişide bir oy, 4–6 kişide iki farklı oy; son harf kapalı kalır. Eşzamanlı eski harf istekleri bir sonraki harfi açmaz.

Her bağlı istemci yalnızca soru süresi veya cevap gösterimi bittiğinde sunucudan senkronizasyon ister; host gerekli değildir. Bağlantı geri geldiğinde sunucu geçmiş süreleri aynı sabit son tarihlerle tamamlar. Geçiş hataları gecikmeli tekrar denenir. Yerel soru geçmişi görünür sorular için kaydedilmeye devam eder. Eski `sync-v1` odaları eski akışla bitirilebilir; yeni yarış için tüm cihazları güncelleyip yeni oda açın.

Örnek setli odaları artık `startDemoRaceGame`, havuz odalarını `startQuestionGame` başlatır. Her iki mod için Functions gerekir. Debug tek kişilik örnek oyun yalnızca dev/emulator sunucusunda açık olan izinle başlatılır; prod sunucusu bu isteği reddeder. Yarış alanı, puanlar ve harfler istemciden doğrudan değiştirilemez. Sorular mevcut mimaride oda üyelerine snapshot içinde gönderilir; sunucuda puanlama doğrulaması, değiştirilmiş istemcilerin cevabı önceden okumasını engellemez.

Bu değişiklik 16 Ekim 2026’da `kelime-yarisi-yalin` dev projesine deploy edildi. `playRace`, `startDemoRaceGame`, `startQuestionGame` ve RTDB kuralları birlikte yayımlandı; kurallar sunucudan geri okunarak yerel dosyayla birebir eşleştiği doğrulandı. Prod değiştirilmedi. Yeniden deploy için:

```sh
firebase deploy --only functions:question-pool:playRace,functions:question-pool:startDemoRaceGame,functions:question-pool:startQuestionGame,database --project kelime-yarisi-yalin
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

Android, debug dahil tüm derlemelerde Play Integrity kullanır; Android debug token kaydı kullanılmaz. iOS debug derlemeleri debug provider, diğer derlemeler App Attest kullanır. iOS debug token'ını ilgili Firebase uygulamasının App Check → Manage debug tokens bölümüne kaydet; token'lar repoya eklenmez. Android Play Integrity için kullanılan imzalama sertifikasının SHA-256 parmak izi ilgili Firebase uygulamasına kaydedilmelidir. Play üzerinden dağıtımda Play App Signing sertifikası kullanılır. Callable fonksiyonlar App Check doğrulamasını zorunlu tutar.

Android dev uygulaması `flutter run` ile Google Play dışından yüklenir. Firebase Console → App Check → dev Android uygulaması → Play Integrity gelişmiş ayarlarında bu dağıtım için `PLAY_RECOGNIZED` ve `LICENSED` zorunlu olmamalı, minimum cihaz bütünlüğü `Device integrity` olmalıdır. Play Integrity API'nin bağlı Cloud projesi `kelime-yarisi-yalin` olmalıdır. Bu ayarlar prod'a otomatik uygulanmaz. [Firebase Play Integrity kurulum rehberi](https://firebase.google.com/docs/app-check/android/play-integrity-provider).

iOS `Debug`, `Debug-dev` ve `Debug-prod` yapılandırmalarında App Attest entitlement'ı yoktur; Personal Team ile fiziksel cihazda debug çalıştırılabilir. `Profile` ve `Release` yapılandırmalarında App Attest entitlement'ı production ortamını kullanır. Bunları fiziksel cihaz için imzalamak, App Attest destekleyen ücretli Apple Developer Program takımı ve bu yetkiyi içeren provisioning profile gerektirir. Firebase ortamı ile debug/release derleme modu birbirinden bağımsızdır; `Prod — Run` da Personal Team ile debug çalıştırılabilir.

Oyun/ekran testleri `flutter test` ile çalışır. İzole güvenlik testleri teknik olarak gerekiyorsa gerekçesi açıklanır ve proje `AGENTS.md` kurallarına uyulur; bu testler yalnızca `demo-kelime-yarisi` projesini kullanır. Bu özel doğrulama için Realtime Database emulator 127.0.0.1:9000 üzerinde çalışırken:

```sh
npm install --prefix /tmp/kelime-yarisi-rules-test @firebase/rules-unit-testing firebase
NODE_PATH=/tmp/kelime-yarisi-rules-test/node_modules node test/firebase/database_rules_test.cjs
```

Strateji değişikliği 1. adımı (ortak soru süresi ve harf oylaması), 2. adımı (autofocus ile PIN tarzı kelime girişi), 3. adımı (İngilizce/Türkçe karakter toleransı) ve 4. adımı (ses efektleri) tamamlandı. PIN görünümü, tek ve sabit bir standart Flutter TextField/FocusNode ile oluşturulur. iOS odak isteği sayfa geçişi tamamlandıktan sonra ve soru başına bir kez yapılır; harf oylaması giriş bağlantısını kilitlemez. Sayaç ayrı BlocSelector ile güncellenir; sesler GameAudioCubit üzerinden yönetilir. Oyuncu doğrudan kelime kutularında yalnızca boş harfleri yazar; ortak açılan harfler sabittir. Yeni harf açılırken diğer kutulara yazılanlar korunur. Firebase mapper, sayısal soru anahtarlarının hem map hem liste biçimini destekler; ortak harfler bütün cihazlara taşınır. Yeni soruda giriş temizlenip odaklanır. Cevap, “Cevapla” veya klavyedeki tamam tuşuyla gönderilir; eksik giriş puan kaybettirmez. Cevap doğrulaması büyük/küçük harf ile c/ç, g/ğ, i/ı/İ/I, o/ö, s/ş, u/ü ayrımı yapmaz. Örneğin kapi → KAPI, gokkusagi → GÖKKUŞAĞI doğru kabul edilir. PIN girişinde eşdeğer harfler kelimedeki konumuna göre gerçek Türkçe yazıma çevrilir; yanlış harfler otomatik düzeltilmez. Harf Al’a basınca hafif titreşim, harf gerçekten açıldığında kısa bir mekanik kasa açılışı ve zil efekti çalar; soru süresinin son 5 saniyesinde saniyede bir tik-tak çalar. Bekleyen oylar ve eski Firebase kayıtları ses çaldırmaz. Oyun ekranındaki hoparlör düğmesi oyuncunun sesini açar/kapatır; tercih o ekran oturumu boyunca geçerlidir. Arka plana geçişte ve odadan çıkışta sesler durur. Efektler `assets/audio/` altında projeye özel üretilmiş WAV dosyalarıdır ve `audioplayers` ile yerel olarak çalınır. Doğru cevap kabul edilince kısa bir çift zil sesi, yanlış cevap kabul edilince alçalan bir uyarı sesi ve sistem titreşimi tetiklenir. Doğru cevap titreşim yapmaz. Eksik giriş, başarısız kayıt ve süre dolması cevap efekti üretmez. Ses kapatma titreşimi kapatmaz; arka planda ikisi de çalışmaz. Eski cevaplar ve yinelenen snapshot’lar efektleri tekrar çaldırmaz. Ses veya titreşim hatası oyun akışını kesmez. Ardından Step 4: rövanş, yeniden oynama ve tam oda geri yükleme. Birden fazla fiziksel cihazla yeni strateji henüz doğrulanmadı.

## Soru havuzu — dev bulut ve gerçek cihaz testi

Çekirdek ve dev bulut backend’i uygulandı: bağımsız soru kayıtları, kaynak/izin bilgisi, editör onayı, yayın artefaktı, cihaz geçmişi, kurallı ortak set seçimi, geçici rezervasyon ve kapasite raporu. Mevcut `Dev — Run` ve `Prod — Run` sabit örnek soruları kullanır; dev havuzu `Dev — Cloud Question Pool` profiliyle gerçek cihazlarda çalıştırılır. Prod ayrı kalır.

Klasik mod 14 soru ve 4–10 harften ikişer cevap kullanır. Mevcut hızlı mod 7 soru ve her uzunluktan bir cevap olarak korundu. Her modda en az 3 konu ve 3 zorluk seviyesi bulunur; bir konu toplamın en fazla üçte birini yukarı yuvarlanmış olarak, bir zorluk seviyesi toplamın en fazla yarısını yukarı yuvarlanmış olarak kaplar. Harf uzunluğu zorluk yerine geçmez. Aynı cevap, aynı kök ailesi veya editörün ilişkili işaretlediği cevaplar aynı sete alınmaz. Seçim başarısız olduğunda bu sınırlar ve tekrar kuralı gevşetilmez.

**Yerel yayın kapasitesi: 336 kaynaklı, AI editör kontrolünden geçirilmiş farklı ana cevap; her uzunlukta 48.** İlk 140 soruya kullanıcının onayladığı 14 set / 196 soru eklendi. `content/questions.json` çalışma havuzu; `functions/content/published.json` backend yayın artefaktıdır. Kontrol türü `ai-self-review` olarak kaydedilir; insan editör onayı değildir. Teorik üst sınır 24 klasik oyundur; konu/zorluk/kök dengesi gerçek kapasiteyi azaltabilir. 90 gün × 3 oyun senaryosu için her uzunlukta en az 492 yeni cevap daha gerekir. Kaynaklar, atıflar, editör kararları ve yeni parti akışı [content/README.md](content/README.md) içinde açıklanır.

`functions/content/examples.json` içindeki 42 eski fixture ayrı kalır; 336 gerçek kayda eklenmez. Örnekler sadece demo emulator ortamında `QUESTION_POOL_EXAMPLES=true` ile seçilebilir ve deploy paketinden çıkarılır. Mobil uygulamada emulator yönlendirmesi bulunmaz. Prod ayrı kalır; dev havuzu yalnız açık proje hedefiyle dağıtılır.

### Cihaz geçmişi ve boyut

SQLite yalnız tamamlanan setin kalıcı kimliğini ve tamamlanma zamanını `completed_sets` tablosunda saklar. Soru/cevap metinleri telefona havuz olarak indirilmez; oda snapshot'ı 14 soruyu taşır. Set, oyuncu 14 soruyu gördükten ve son sorunun sunucu sonucu alındıktan sonra tek kez kaydedilir. Üçüncü/dördüncü soruda odadan çıkmak geçmişe kayıt oluşturmaz; yarım set yeniden oynanabilir.

V2 geçmiş geçişi eski soru bazlı tabloları korur fakat bu satırlar tamamlanmış oyun kanıtı olmadığından yeni seçimde tüketilmiş set sayılmaz. Set kimlikleri uygulama güncellemesinde korunur. Uygulama verisi silinirse yerel geçmiş sıfırlanır; geçmiş dizini Android/iOS yedeklerinden çıkarılır. Soru gösterimi SQLite yazısına bağlı değildir. Tamamlanma yazısı başarısız olursa yeniden denenir ve sonuç ekranından normal çıkışta yazının tamamlanması beklenir.

### Gerçek cihaz ile çalıştırma

Uygulama flavor’ın yerel Firebase yapılandırmasıyla açılır. `main.dart` içinde named demo app, sahte anahtar, emulator adresi veya `USE_FIREBASE_EMULATORS` seçeneği yoktur. Android/iOS cihazını bağlayıp VS Code’da **Dev — Run** profilini seç veya cihaz kimliğini açıkça ver. Dev flavor gerçek havuzu varsayılan kullanır; prod otomatik etkinleşmez:

```sh
flutter run --flavor dev -d DEVICE_ID --dart-define=QUESTION_POOL_ENABLED=true
```

Android Play Integrity için dev imzasının SHA-256 parmak izi Firebase'de kayıtlı olmalı. Android API anahtarının uygulama izin listesinde ayrıca **dev paket adı ve cihazda kullanılan debug imzasının SHA-1’i** bulunmalı. iOS debug App Check tokenı ilgili dev Firebase uygulamasında kayıtlı olmalı. Prod için ayrı anahtar/uygulama ayarları korunur. API servis izin listesinde `firebaseappcheck.googleapis.com`, `identitytoolkit.googleapis.com` ve `securetoken.googleapis.com` tutulur. Token değerlerini repoya veya test loglarına yazma.

iOS debug tokenı cihazdaki uygulama kurulumuna aittir. Uygulama silinirse veya verileri temizlenirse token değişebilir; yeni token aynı dev uygulamasında yeniden kaydedilmelidir. Normal `flutter run` için uygulama verilerini temizleme. App Check ayarları tamamlandıktan sonra `Too many attempts` sürerse uygulamayı kapatıp yeniden aç; sürekli token yenileme/istek döngüsü ekleme.

Gerçek cihaz kabul testi gerçek callable doğrulamasıyla 14 soruluk seti bitirir, SQLite kaydını ve sonraki oyunda farklı set seçildiğini doğrular; yarıda bırakılan oyunun tüketilmediğini kontrol eder. Test kendine ait geçici SQLite dosyası kullanır ve kullanıcının geçmişine dokunmaz; oluşturduğu odaları kapatır. Testin oluşturduğu geçici `questionPreparations` kaydı da yalnız testteki kullanıcı/oda kimliği eşleşiyorsa iş sonunda yönetici erişimiyle temizlenmelidir:

```sh
flutter test integration_test/question_pool_device_test.dart --flavor dev -d DEVICE_ID --dart-define=QUESTION_POOL_ENABLED=true
```

Test/build sonunda bu çalışma için üretilen gereksiz APK/IPA, build çıktıları ve geçici logları temizle. Proje özelindeki ayrıntılar `AGENTS.md` içindedir. Backend’in izole güvenlik testleri saklanır; emulator kullanımı günlük cihaz akışının parçası değildir ve yalnız teknik olarak gerekli özel bir doğrulama için geçici olarak çalıştırılır.

Backend yalnız oda sahibinin başlatmasına ve oda üyelerinin geçmiş hazırlığına izin verir. Her cihaz tamamladığı set kimliklerini geçici hazırlık kaydına iletir. Tüm oyuncuların tamamladığı setler birleşik olarak elenir; kalan yayımlanmış setlerden biri, kendi 14 sorusu ve sırası korunarak seçilir. `contentSetId` kalıcı içerik kimliği, `questionSetId` ise oda oturum kimliğidir; içerik kimliğini istemci değiştiremez. Hiç uygun set kalmazsa örnek sete veya karma seçime dönülmez.

Hazırlık 25 saniye geçerlidir; başlamazsa hazır durumu yenilenir. Sunucuda kalıcı kullanıcı geçmişi tutulmaz. Aynı oda için eşzamanlı/tekrarlanan başlatma aynı ayrılmış seti kullanır. Yarıda bırakılan başka bir oda, seti sonraki oyuna kalıcı olarak kapatmaz. Yeni oyunlar yalnız 14 soruluk klasik moddur; hızlı mod oluşturma ekranından ve yeni oyun servisinden kaldırılmıştır. Eski snapshot'ları okuyabilmek için legacy enum/veri desteği korunur.

Başlangıç sürümünde aktif rezervasyonlar tek atomik RTDB transaction ile seçilir ve 300 eşzamanlı rezervasyonla sınırlandırılır; yoğunlukta açık hata döner. Bu seçim katmanı yük altında ölçülmeden büyük trafik garantisi verilmez. Set parmak izi sıralanmış cevap kimliklerinden üretilir; farklı kullanıcı gruplarında global set benzersizliği zorlanmaz. Aynı soru farklı kullanıcılarda kullanılabilir. Yerel geçmiş kullanıcı cihazından geldiği için hesabın tüm cihazlarında tekrar engeli veya hileye karşı sunucu geçmişi garantisi verilmez.

Lobide setlerdeki soru sayıları ve gerçekten oynanabilir tamamlanmış set sayısı görünür. Ortak set oluşturma hatasında bütün oyuncuların birleşik raporu gösterilir. Konu, zorluk ve kök sınırları kapasite üst sınırını düşürebilir; kombinasyon sayısı tekrarsız oyun sayısı olarak sunulmaz.

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

`review` altı kontrolün hepsini ve editör adını ister; onay içeriğin hash'ine bağlıdır. Onaydan sonra metin/kaynak/kök değişirse yeniden inceleme gerekir. `publish` yalnızca onaylı üretim kayıtlarından yerel backend artefaktını oluşturur; Firebase'e deploy etmez. Yeni partilerde kelime/kaynak tedariki devam eder. API üretimini çalıştırmak için yerel API anahtarı ve açık model seçimi gerekir. Yerel araç kontrollü parti komutuyla çalışır. Dev bulut üreticisi her gün İstanbul saatiyle 04.00’te yeni sorular hedefler; editörden geçen sorular özel taslakta birikir. Her uzunluktan iki soru, konu/zorluk/kök kontrolleri ve 14 soru tamamlanınca set ile soruları atomik yayımlanır. Eksik set ertesi gün kaldığı yerden devam eder; tamamlanmadan oynanamaz. Prod bu aşamada değiştirilmez.

### Kontroller

Dev bulut üreticisi günde 3 tamamlanmış 14’lü set hedefler. Çalışma sınırı 25 dakika, fonksiyon timeout’u 30 dakikadır; kaynak/ret/harcama sınırında kalan taslak silinmez. Kalıcı RTDB sayacı günde 60 deneme / 120 istek, beş art arda başarısız sonuç ve model maliyetinde 0,50 USD/gün, 10 USD/ay sınırları uygular. API anahtarı yalnızca üreticiye bağlı dev Secret Manager kaydındadır. Kaynak kuyruğu 90 önceki taslağa eklenen 16 karma cevap adayıyla 106 kayıttır; bunlar onaysızdır ve yayın sayısına dahil değildir. 18 Ekim geçiş planında 28 tamamlanmış set / 392 oynanabilir soru ve 9 özel taslak sorusu vardır; güncel sayı dev veritabanından doğrulanır. Üretici ve editör isimlerin yanında edat, bağlaç, mastar ve en fazla iki kelimeli ad/edat/fiil öbeklerini kabul eder. Boşluklar korunur; yalnız harfler 4–10 sınırına sayılır. Aynı harf/kelime düzenindeki doğru eşdeğerler `acceptedAnswers` içine alınır; eş anlamlı olması tek başına ret sebebi değildir. Stok tükenmesi/retler eksik hedef olarak raporlanır. Ayrıntılar [dev zamanlaması ve prod'a taşıma](content/README.md#dev-bulut-zamanlaması) bölümündedir. Yerel CLI ve bulut sayaçları ayrıdır.

```sh
flutter analyze
flutter test
npm test --prefix functions
```


Dev bulut havuzu cihaz kabul testi için **Dev — Cloud Question Pool** profilinden açılır. Android dev Play Integrity ayarları ve iOS dev App Check debug token kayıtları tamamlanmalıdır. Prod’a geçiş ayrı adımdır: dev’de test edilen yayımlanmış sorular kimlikleri korunarak taşınır; prod secret, sayaçlar, üretici hesabı ve zamanlama ayrı kurulur. Dev profilleri ve terminalde dev flavor gerçek havuzu kullanır; prod etkinleştirmesi bu değişikliğe dahil değildir. Yarış puan/cevap doğrulaması sunucudadır; mevcut oda snapshot’ında cevaplar üyelere gönderilmeye devam eder.

## Güvenlik ve canlıya çıkış

- Firebase istemci yapılandırmaları yalnızca yerelde tutulur ve Git tarafından izlenmez.
- Realtime Database kuralları üretime gönderilmeden önce kapsamına uygun kontrollerle doğrulanmalıdır. İzole emulator doğrulaması gerekiyorsa gerekçesi açıklanır ve kullanım sonrası süreç/çıktılar temizlenir. Kurallar `firebase deploy --only database` komutu çalıştırılana kadar canlı projeyi değiştirmez.
- App Check kod tarafında etkindir. Android tüm derlemelerde Play Integrity kullanır. iOS debug derlemelerinde debug provider, diğer derlemelerde App Attest kullanılır. Yalnız iOS debug token'ları ilgili ortamın Firebase Console'una elle kaydedilir; token'lar repoya eklenmez.
- Kısıtlı Android/iOS Firebase API anahtarlarının izin listesinde `firebaseappcheck.googleapis.com` bulunmalıdır; aksi durumda debug token değişimi `403 API_KEY_SERVICE_BLOCKED` ile reddedilir.
- App Check enforcement, geçerli istek metrikleri kontrol edildikten sonra Firebase Console'dan açılmalıdır.
- Store build alınmadan önce Android release/upload keystore yapılandırılmalıdır. Release sürümü bilerek debug anahtarıyla imzalanmaz.
- Skor ve cevap doğrulaması istemciye güvenmemeli; oyun motoru aşamasında güvenilir sunucu tarafında uygulanmalıdır.

Sayfa geçişleri GoRouter ile ana sayfa, oluştur/katıl formu, oda ve oyun rotalarından yönetilir. Oda/oyun verisi bulunmayan bir rota ana sayfaya döner. Presentation widget’ları kendi dosyalarındadır. `GameCubit` puan, harf oyu ve ortak soru senkronizasyonunu; `GameFeedbackCubit` sonuç gösterim süresini; `GameAudioCubit` ses tercihi ve ses yaşam döngüsünü yönetir. Harf Al ve Cevapla klavyeyi kapatmaz; diğer alanlara dokunma ve sayfayı kaydırma kapatır. Cevap kaydedilince giriş kilitlenir, odak bağlantısı yeni soruya kadar korunur.

## Sentry hata takibi

Tek organizasyon: `yalin-yilmaz`. Projeler: `kelime-yarisi-flutter` (Android/iOS) ve `kelime-yarisi-functions` (Firebase). Her projede ortam etiketi `dev` veya `prod` olur; ayrı Sentry hesabı gerekmez. Flutter ortamı flavor'dan, Functions ortamı Firebase proje kimliğinden belirlenir. Prod Firebase deploy'u ayrıca yapılmalıdır.

VS Code launch ayarları `.local/sentry.dev.json` / `.local/sentry.prod.json` dosyalarını okur. Bu dosyalar Git'e girmez. Yeni bilgisayarda ilgili dosyaları oluşturun: `{"SENTRY_DSN":"Sentry Client Keys ekranındaki DSN"}`. DSN, istemcide bulunması gereken bir olay gönderme adresidir; yönetim yetkisi veren `SENTRY_AUTH_TOKEN` değildir. Eksik DSN durumunda uygulama çalışır, Sentry devre dışı kalır ve geliştirme konsolunda uyarı görünür.

Terminalden çalıştırma:

```sh
flutter run --flavor dev --dart-define-from-file=.local/sentry.dev.json
flutter run --flavor prod --dart-define-from-file=.local/sentry.prod.json
```

Functions için hedefe özel, Git tarafından ignore edilen `functions/.env.kelime-yarisi-yalin` dosyasındaki `SENTRY_DSN` kullanılır. Prod karşılığı `functions/.env.kelime-yarisi-prod` dosyasıdır; hedef proje değiştirilmeden dev dosyasını prod'a taşımayın. Deploy koruması yalnızca Sentry'nin genel ingestion DSN adresine izin verir; API anahtarı ve upload auth tokenları reddedilir.

SDK, Flutter framework/async hatalarını ve desteklediği Android/iOS native crashlerini yakalar. Cubit hataları, yakalanan oyun/oda/stream, yerel kayıt ve ses hataları ortak `ErrorReporter` üzerinden raporlanır. Callable hataları ve zamanlanmış görev hataları backend'de ayrı kaydedilir; Functions yanıtı tamamlanmadan önce en fazla 2 saniye gönderim beklenir. Aynı işlem/tip/kod için yakalanan tekrarlı hatalar süreç başına dakikada bir gönderilir. Yanlış cevap ve normal oyun eylemleri hata kaydı oluşturmaz.

Hata tipi, kodu, işlem ve stack trace korunur. Ham exception mesajı, Firebase/OpenAI yanıtları, kullanıcı girdisi, cevap, oyuncu adı, oda ve geçmiş verileri gönderilmez. Breadcrumb, ekran görüntüsü, replay, performance ve genişletilmiş log toplama kapalıdır. Native SDK için sunucu tarafındaki varsayılan scrubber'lar ve ek hassas alan filtreleri de açık tutulmalıdır. İzleme bağlantısındaki bir hata oyunu kesmez.

Release öncesinde native sembolleri (iOS dSYM, Android mapping/native semboller, obfuscation varsa Dart sembolleri) ilgili Sentry projesine yükleyin: https://docs.sentry.io/platforms/flutter/upload-debug/ . Upload için gereken auth token yalnız yerel/CI secret olmalıdır; Flutter'a veya Functions paketine eklenmez. Debugger bağlıyken native crash yakalama davranışı farklı olabilir; son native crash doğrulamasını debugger olmadan gerçek cihazdaki profile/release sürümünde yapın. Bu çalışma cihazda crash testi yapmaz.

Panel: https://yalin-yilmaz.sentry.io/issues/ . Proje seçimiyle istemci/backend, ortam filtresiyle dev/prod ayrılır. Prod ortamı ilk gerçek prod kaydı geldiğinde listelenir.
