# Soru içeriği ve inceleme kaydı

`questions.json`: 336 bağımsız, kaynaklı ana cevap; 4–10 harfin her birinde 48 farklı cevap. İlk 140 soruya onaylı `initial_001`–`initial_014` setlerindeki 196 soru eklendi.
`../functions/content/published.json`: bunların yerel backend yayın artefaktı.
42 eski fixture `../functions/content/examples.json` içinde ayrı kalır; gerçek havuz sayısına eklenmez.

Bu ilk parti Codex tarafından kaynak verileri okunarak yazıldı, ardından ayrı bir Türkçe editör turunda kontrol edildi. Kullanıcının isteğiyle onay türü `ai-self-review` olarak kaydedildi. İnsan editör onayı değildir. `review` içinde alternatif cevaplar, elenme nedenleri, kaynak desteği ve içeriğe bağlı hash bulunur. Yazım/kök kontrollerinin ve bu editör turunun hatasızlık garantisi yoktur; sorunlu bir kayıt `rejected`/`unpublished` yapılarak düzeltilmeli, yeniden incelenip artefakt yeniden üretilmelidir.

İlk turda `OBOE → OBUA`, `TRANZİSTÖR → TRANSİSTÖR` düzeltildi. Çamaşırlık/kurutmalık, hidrometre/dansimetre ve diğer eş anlam karışıklığı taşıyan adaylar yerine farklı kelimeler seçildi. Barometre/manometre ayrımı kaynaklı tarihsel bilgiyle netleştirildi. Zorluk sözcük uzunluğuna göre verilmedi; Latince tür adı isteyen sorular zor olarak işaretlendi. Aynı köklü deniz/denizaltı/denizanası ve fotoğraf/fotoğrafçı aynı sette bulunamaz.

## Kaynak ve lisans bildirimi

- Wikidata etiket/açıklama verileri: **CC0**, <https://www.wikidata.org/wiki/Wikidata:Licensing>. Her kayıtta `entityId`, revizyon numarası ve erişim tarihi bulunur. Ansiklopedi başlıkları kelime doğrulaması için kullanılır; yarışma soru arşivi alınmaz.
- İngilizce Wikipedia kısa kaynak alıntıları: **Wikipedia contributors**, ilgili madde başlığı, **CC BY-SA 4.0**, <https://creativecommons.org/licenses/by-sa/4.0/>. Her kaydın `source.encyclopedia` alanında yazar atfı, başlık, kalıcı revizyon bağlantısı, erişim tarihi, lisans ve özgün İngilizce alıntı bulunur. Bu alıntı metinleri aynı lisans altında paylaşılır; kaynak/atfın kaldırılmaması gerekir. Kaynak alıntıları oyundaki soru olarak kullanılmaz ve telefona gönderilmez. Soru cümleleri proje için yeniden yazılmıştır.
- Barometre kaydında ek doğrulama: **OpenStax, University Physics Volume 1, §14.2**, CC BY 4.0; bağlantı ve özgün Türkçe olgu özeti kaydın `source.supplemental` alanındadır.

Bu içerik dosyaları backend ve editör araçlarınındır. Flutter asset listesine eklenmez.

## 005–014 partisi: yüklemeye hazırlanmış 140 ek soru

`sets/luna_sets_005_014_20261015.exchange.json` gerekli metin/ipucu düzeltmelerini içerir. 140 ana cevap korunmuştur. Kullanıcının güncel politikasıyla, anlamı ve görünür harf/kelime düzeni uyan 17 eş anlamlı `acceptedAnswers` içinde kabul edilir. Bu alan ayrı bir soru veya ek kapasite sayılmaz. Kaynakların önceki üreticide bildirilen doğrulama bilgileri korunmuştur; bu düzeltme turunda 140 TDK maddesinin yeniden indirildiği iddia edilmez. Güncel birincil kaynak kontrolleri kayıtlarda ayrıca işaretlidir.

Hazırlanmış dosyalar aynı dizindedir:

- `luna_sets_005_014_20261015.questions.json`: 140 onaylı, içerik hash'i bağlı ve henüz `unpublished` kanonik kayıt.
- `luna_sets_005_014_20261015.rtdb.json`: `/questionPool/published` altına **update** ile eklenecek JSON metinleri. `set` ile mevcut havuzun üstüne yazılmaz. Dosyadaki `published` yerel yayın artefaktı durumudur; buluta yüklenmiş olduğu anlamına gelmez.
- `luna_sets_005_014_20261015.ready.json`: set bazındaki kimlikler, kontrol sonucu ve dağıtım gereksinimleri.
- `luna_sets_005_014_20261015.preview.md`: cevap ve ipucu içermeyen güncel önizleme.

Bu 10 set, önce onaylanan dört setle birleştirilerek 14 set / 196 soru olarak ana/yayın havuzuna alındı; toplam **336 farklı ana cevap** var. `sets/initial_001_014.rtdb.json` bu 196 kaydın eklemeli dev yükleme artefaktıdır. `initial_001` özgün onay kaydıyla, `initial_002`–`initial_004` son metin ve eski kaynak doğrulama kökenleri açıkça korunarak aktarılmıştır. Yerel kod iki kelimeli cevapların boşluklarını korur, harf sayısına boşlukları katmaz ve onaylı alternatifleri doğru kabul eder. Bu nedenle yüklemeden önce güncel backend ve Flutter sürümü dev ortamında kullanılmalıdır. Dönüştürme aracı kendi başına deploy veya RTDB yazımı yapmaz; dev dağıtımı ayrıca yürütülür. `hint` verisi saklanır; ek ipucu butonu/kotası bu çalışmaya dahil değildir.

Sonraki partiler için API/anahtar kullanmadan, repository kökünden:

```sh
node functions/tools/prepare_exchange.js --input content/sets/YENI.exchange.json --out content/sets/YENI
```

Araç mevcut çıktı dosyasını ezmez. Kaynak/editör durumu eksikse, cevap tekrarı varsa veya gerçek set seçicisinin kök/konu/zorluk koşulları sağlanmıyorsa yükleme artefaktı üretmez. Eş anlamlılar ancak soruya gerçekten uyuyorsa kabul edilir; farklı anlamlar veya yanlış uzunluklar otomatik kabul edilmez.

## Yeni parti

`seed_words.tsv` seçilmiş cevapları, tek anlamlı ansiklopedi başlığını, konuyu ve başlangıç zorluğunu taşır. Yeni ve henüz kullanılmamış kelimeler eklenerek aşağıdaki akış yeniden çalıştırılır; aynı kelimeye yeni soru yazmak kapasiteyi artırmaz.

Komutları repository kökünden çalıştır:

```sh
npm run content:sources --prefix functions -- --out /tmp/new-sources.json
npm run content:enrich --prefix functions -- --file /tmp/new-sources.json --out /tmp/new-evidence.json
npm run content:replenish --prefix functions -- --sources /tmp/new-evidence.json --target-per-length 40 --limit 20 --dry-run
```

İlk iki komut yalnızca herkese açık kaynakları indirir. Başlık çözümlenmezse veya veri alınamazsa yayın dosyasına yazmaz. Ara çıktılar için yeni dosya adı gerekir. Hedef anlam kaynak açıklamasından gelir; gerekiyorsa üretim öncesinde daraltılır/düzeltilir.

Gerçek OpenAI Responses API çağrısı için anahtarı **yalnızca yerel ortam değişkenine** veya repo kökündeki ignore edilen `.local/question-generation.env` dosyasına koy. Model açıkça seçilir; araç otomatik model seçmez/değiştirmez. Anahtar Flutter'a, Functions kaynak koduna veya deploy paketine konmaz. Bulut üreticisi yalnızca kendisine bağlanan Secret Manager kaydını çalışma anında okur. Aşağıdaki komut API hesabında ücret doğurabilir; önce `--dry-run` çıktısını kontrol et.

```sh
# OPENAI_API_KEY yerel terminal ortamında tanımlı olmalı; dosyaya/repoya yazma.
npm run content:replenish --prefix functions -- --sources /tmp/new-evidence.json --target-per-length 40 --limit 20 --ai-review
npm run content --prefix functions -- validate
npm run content --prefix functions -- publish
npm run content:quality --prefix functions -- --trials 20 --days 90 --games-per-day 3
```

API’ye yalnızca seçilmiş kelime, hedef anlam, adaylar ve açık kaynak kanıtının gerekli alanları gönderilir. Mevcut soru havuzu, editör arşivi ve oyuncu geçmişi gönderilmez; havuzdaki metin benzerliği yerelde kontrol edilir. Bu daraltma giriş token maliyetini de azaltır. Üretim ve inceleme ayrı model çağrılarıdır. Aynı model kullanıldığı için `ai-self-review` adı korunur. İnceleme şüphede reddetmelidir; altı kontrol, gerekçe, kaynak desteği ve alternatif cevap incelemesi olmadan onay yoktur. `--ai-review` yoksa kayıt `in-review` kalır. Uygun olmayan/boş/refusal/yarım API cevabı yayınlanmaz. Her tamamlanan kelime kaydedilir; tekrar çalıştırma mevcut cevapları atlar. Dosya kilidi eşzamanlı üreticilerin birbirinin kaydını ezmesini engeller; dışarıdan düzenleme saptanırsa işlem durur.

`publish` yerel artefakt oluşturur. Açık emulator Functions yeniden başlatıldığında yeni havuzu yükler. Başlangıç havuzu Functions dağıtımıyla yüklenir; bulut üreticisinin onayladığı ek kayıtlar özel RTDB havuzuna yazılır ve yeni oyunlarda yeniden deploy olmadan yüklenir. Yerel CLI kendiliğinden zamanlanmaz; bulut zamanlaması aşağıdadır. Oyun sırasında OpenAI çağrısı yapılmaz. Model/anahtar olmadan ilk 140 soru ve oyun backend'i çalışır; yeni API üretimi çalıştırılamaz. İlk 140 soru Codex oturumunda hazırlandı. 15 Ekim 2026 tarihinde `gpt-6-luna` ile gerçek üretim + editör denemesi yapıldı: iki çağrı, 1.306 giriş ve 1.875 çıktı token’ı. FLÜT için üç aday üretildi; editör kaynak metne yakın aktarım nedeniyle reddetti. Yayın havuzu 140 soruda kaldı. Bu, entegrasyon ve ret akışı kontrolüdür; genel model kalitesi veya kabul oranı ölçümü değildir. Standart, cache indirimsiz Luna fiyatıyla bu denemenin hesaplanan maliyeti yaklaşık 0,0010681 USD; gerçek fatura/vergiler farklı olabilir. Yerel makbuz `.local/question-trial-last-run.json` içindedir; anahtar içermez ve Git/deploy dışında kalır.

336 farklı ana cevap teorik olarak en fazla **24** tam klasik oyun sağlar; konu/zorluk/kök dengesi bu üst sınırı azaltabilir. 90 gün × 3 oyun hedefi için her uzunlukta en az 540 cevap gerekir; şu anda her grupta **492** cevap eksiği var. Kabul edilen eş anlamlılar ek soru veya kapasite sayılmaz. Yeni kelime/kaynak sağlanmadan araç sınırsız içerik oluşturamaz.

## Sınırlı günlük üretim (yerel CLI)

Günlük hedef **42 yeni onaylı soru**: 4–10 harfin her birinden altışar soru. Hedef tamamlanana kadar sınırsız deneme yapılmaz. Önce ücret doğurmayan önizleme:

```sh
npm run content:daily --prefix functions -- --sources /tmp/new-evidence.json --dry-run
# Gerçek ücretli çalışma; kendiliğinden zamanlanmaz:
npm run content:daily --prefix functions -- --sources /tmp/new-evidence.json
```

Tüm `daily`, `replenish` ve `trial` komutları aynı kalıcı yerel sayacı kullanır. Varsayılan sınırlar:

- İstanbul takvim gününde en fazla **60 kelime denemesi / 120 API isteği**.
- **5 art arda ret, incelemesiz veya başarısız sonuç** sonrasında o gün durma. HTTP/ağ hatasında mevcut çalışma ilk hatada durur; otomatik HTTP retry yoktur.
- Hesaplanan/rezerve edilen tutar için **0,50 USD/gün, 10 USD/takvim ayı** tavanı. Bunlar harcama hedefi değildir. Sayaç bu koruma üzerinden geçen yeni çağrıları kapsar; eski denemenin makbuzu ayrı kalır.
- Başlangıçtan **10 dakika** sonra yeni API isteği başlatılmaz. Devam eden isteğin ayrıca 90 saniyelik timeout'u vardır.
- Denenmiş kelimeler sonraki komutlarda ve günlerde otomatik tekrar denenmez. Yeni kaynaklı kelimeler gerekir. Önceki FLÜT reddi de atlanır.

Sayaç `.local/question-generation-ledger.json` içinde anahtarsız tutulur; Git/deploy dışındadır. Komutu yeniden çalıştırmak veya farklı çıktı dosyası seçmek sınırları sıfırlamaz. Eşzamanlı çalışmayı kilit engeller. Kesintiden kalan kilit otomatik silinmez; başka üretici çalışmadığını kontrol etmeden kilidi silme. Bozuk sayaçla üretim durur; harcama kaydını sıfırlamak için dosyayı silme. Gün değişince günlük limitler sıfırlanır; aynı ayın maliyeti ve denenmiş kelimeler korunur.

İstek öncesinde olası çıktı ve muhafazakâr giriş tahmini için bütçe ayrılır. Usage dönerse tutar gerçek token sayısıyla güncellenir; timeout/eksik usage durumunda rezervasyon harcanmış sayılır. İstek gövdesi en fazla 32.000 UTF-8 byte, çıktı 512–12.000 token olabilir; medya/harici araç eklenmez. Fiyat kontrolü seçili **`gpt-6-luna`**, `service_tier: default` ve [15 Ekim 2026 standart kısa bağlam fiyatlarına](https://developers.openai.com/api/docs/models/gpt-6-luna) dayanır: giriş 0,10 / çıktı 0,50 USD/milyon token; cache indirimi hesaba katılmaz. Farklı model için fiyat tanımı güncellenmeden istek gönderilmez, model otomatik değiştirilmez. Bu yerel kontrol OpenAI hesabının genel faturası veya vergiler için garanti değildir. Fiyat değişirse kod güncellenmelidir.

Günlük komut ana çalışma havuzuna kaydedilmiş yeni onayları sayar; `trial` onayları kotayı doldurmaz. Eksik harf grupları, durma nedeni ve maliyet çıktıda görünür. 42'ye ulaşılamazsa eksik sayı raporlanır; editör gevşetilmez. Onaylar `unpublished` kalır; konu/zorluk/kök dengesi ve set kapasitesi ayrıca `content:quality` ile kontrol edilip `publish` yapılır. 42 soru tek başına üç dengeli set garantisi değildir.

`trial_sources.json` içinde FLÜT çıkarılınca altı denenmemiş kelime kalır. Bulut başlangıç kuyruğu `functions/content/source_queue.json` içinde **106 onaysız kaynak taslağı** içerir: önceki 90 kayda 16 karma tür adayı eklendi. Önceki 90 kayıt dört harfte 12, diğer uzunluklarda 13 aday içeriyordu. Yeni 84 kelimenin listesi `daily_words.tsv` içindedir. Bunlar yayın sayısına dahil değildir. Stok sonludur; retler ve önceki denemeler düşüldükten sonra kaynakların yenilenmesi gerekir. Yazar istemi kaynak cümlesini çevirmek yerine kanıtlı olgulardan özgün Türkçe ipucu kuracak şekilde güncellendi. İyileşme henüz gerçek API örnekleriyle ölçülmedi; tek ret Luna'nın genel kabul oranını belirlemez.

## Dev bulut zamanlaması

`generateDailyQuestions`, [Firebase onSchedule](https://firebase.google.com/docs/functions/schedule-functions) ile **her gün 04.00 Europe/Istanbul** saatinde çalışır. Hedef her uzunluktan altı onaylı soru; sonuçta yeni sorulardan kurulabilen en fazla üç dengeli klasik set de doğrulanır (`classicSetsVerified`). Eksik kalan hedef tamamlanmış gösterilmez. `retryCount: 0`, tek instance/concurrency ve 15 dakika fonksiyon timeout'u vardır. Paylaşılan politika 10 dakikadan sonra yeni API isteğini durdurur.

Dev projesi `kelime-yarisi-yalin`; prod `kelime-yarisi-prod` bu adımda değiştirilmez. Fiziksel cihazda dev bulut havuzu için **Dev — Cloud Question Pool** launch profilini kullan. Yeni bir oda aç; iki cihazdaki debug App Check token'ları dev Firebase Console'da kayıtlı olmalıdır. Backend callables App Check ve üyelik denetimini korur. Testler emulator'da mock sağlayıcıyla çalışır; zamanlanmış ücretli handler emulator'da devre dışıdır.

[Secret Manager](https://firebase.google.com/docs/functions/config-env#secret_parameters) kaydı `OPENAI_API_KEY`, yalnızca `generateDailyQuestions` fonksiyonuna bağlanır. Üretici ayrı `question-generator@PROJECT_ID.iam.gserviceaccount.com` hesabını kullanır. Yerel dosya, anahtar değeri ve diğer CLI araçları deploy paketine girmez. Anahtar `.env` içine taşınmaz. Onaylı dev kurulumu için `node functions/tools/provision_generation.js --project kelime-yarisi-yalin --set-secret` kullanılır; stdin ile aktarır, değerleri loglamaz. Bu araç prod kurulumu yapmayı reddeder. Functions/Scheduler için Blaze gereklidir; yerel model bütçesi Firebase/Secret Manager/Cloud Scheduler giderlerini kapsamaz.

Kalıcı özel yollar:

- `questionGeneration/control`: `{enabled: true, projectId: "kelime-yarisi-yalin"}`. Alanlardan biri uyuşmazsa iş API çağrısı yapmaz. `enabled: false` sonraki API isteği öncesinde üretimi durdurur.
- `questionGeneration/ledger`: günlük/aylık sayaçlar ve daha önce denenmiş cevaplar. Yerel CLI sayacından ayrıdır; iki üreticiyi aynı anahtarla paralel çalıştırırsan hesap genelindeki harcama toplamını ayrıca takip et.
- `questionGeneration/lease`: RTDB transaction ile alınan süreli kilit. Tekrar teslim edilen aynı günün işi ikinci bir üretim turu açmaz. Kesinti sonrası bilinmeyen ücret rezervasyonları korunur.
- `questionGeneration/outbox`: editör onayından sonra kalıcı yayın kuyruğu. Yayın ve outbox silme atomiktir; kesinti sonrası tekrar tetikleme yeni ücret harcamadan yayını tamamlar.
- `questionGeneration/rejections`: reddedilen metinler ve editör gerekçesi. Oyun havuzuna katılmaz.
- `questionGeneration/lastRun`: durma nedeni, çağrı/maliyet ve eksik uzunluklar. Durum ayrıca Cloud Logging'e anahtarsız yazılır.
- `questionPool/published`: yalnızca doğrulanmış onaylı ek sorular. `questionSources`: stok eklemek için opsiyonel özel kaynak kuyruğu. Bu üç kök mobil istemcilerin okuma/yazmasına kapalıdır.

Kaynak/soru kayıtları RTDB'de JSON metni olarak korunur. RTDB'nin boş dizileri kaldırması editör hash'ini değiştirebildiği için bu biçim kullanılır. Oyun servisi JSON'u çözüp onay hash'ini, yayın koşullarını ve havuz benzerliğini yeniden doğrular; istemciye yalnızca o oyunun sorularını gönderir. 336 soruluk paket havuzu ve özel ek havuz kimlikle birleştirilir; iki yerde bulunan aynı kayıt iki kez sayılmaz.

Yeni kaynak stoku eklemek için seed listesi → `content:sources` → `content:enrich` akışını kullan. `node functions/tools/build_queue.js --sources /tmp/new-evidence.json --out /tmp/new-queue.json` kaynakları kontrol edip RTDB biçimine çevirir. Ardından `firebase database:update /questionSources /tmp/new-queue.json --project kelime-yarisi-yalin --force` ile yeni adaylar eklenebilir; mevcut denemeler sayaçta korunur. Bu işlem soru onayı değildir. Başlangıç stoğu sınırsız bir kelime keşif sistemi değildir; stok tükenirse iş ücretli döngüye girmez, eksik raporlar.

### Prod'a taşıma

Dev'de kabul testinden geçen **yalnızca yayımlanmış soru içeriğini**, başlangıç artefaktı ve `questionPool/published` kayıtlarıyla birlikte dışarı al. Kimlikleri ve editör kayıtlarını değiştirmeden prod'a taşı; prod'daki oyuncu geçmişleri böylece aynı cevap kimliklerini kullanabilir. Dev oda/oyuncu geçmişleri, harcama sayacı, lease, kontrol bayrağı, red/outbox kayıtları ve secret kopyalanmaz. Prod için ayrı Secret Manager kaydı, üretici hesabı, Blaze/Scheduler kurulumu ve prod projectId'li kontrol gerekir. Aynı kod deploy edilebilir; prod kontrolü ayrıca açılana kadar ücretli üretim başlamaz. Dev ve prod üreticilerini bağımsız bırakmak iki ortamda ayrı API maliyeti doğurur; dev artık gerekmiyorsa kontrol bayrağını kapat.

## Yerel API kurulumu ve tek soruluk deneme

```sh
npm run content:setup --prefix functions
```

Bu komut `.local/question-generation.env` dosyasını boş alanlarla oluşturur; mevcut dosyayı ezmez. Dizin `700`, yeni dosya `600` izniyle oluşturulur. Dosyada yalnızca `OPENAI_API_KEY=` ve `OPENAI_MODEL=` alanlarını doldur. Anahtar sohbet, terminal komutu, `functions/.env*`, Dart, launch.json veya Git içinde tutulmaz. Shell ortam değişkenleri tanımlıysa dosyadan önce gelir; dosyanın içeriği shell olarak çalıştırılmaz. Kurulum çıktısı yalnızca alanların dolu olup olmadığını bildirir. Anahtar [OpenAI Platform API Keys](https://platform.openai.com/api-keys), model kimliği [resmî model kataloğu](https://developers.openai.com/api/docs/models) üzerinden alınır. Kod varsayılan model seçmez.

`content/trial_sources.json` her uzunluktan bir yeni cevap için **onaysız kaynak taslağıdır**; 140 soruluk yayın sayısına dahil değildir. `trial_words.tsv` kaynak başlıklarını taşır. Önce ücretsiz önizleme:

```sh
npm run content:trial --prefix functions -- --dry-run
```

Anahtar/model hazır olduğunda tek deneme:

```sh
npm run content:trial --prefix functions
```

Her çalıştırma en fazla **1 soru, 2 API isteği**, istek başına varsayılan **6.000 çıktı token'ı** ile sınırlıdır; otomatik yeniden deneme yoktur. Yukarıdaki ortak günlük/aylık bütçe ve ret sınırları da geçerlidir. `--max-output-tokens` ile 512–12.000 arası çıktı sınırı seçilebilir; model değiştirilmez. Üretim ve editör kontrolü ayrı isteklerdir. Ham HTTP hataları/cevapları veya Authorization başlığı loglanmaz. Yönlendirmeler reddedilir; tek hedef OpenAI Responses API'dir. Anahtarın cevapta geri dönmesi veya üretilen kayda yazılması saptanırsa kayıt reddedilir.

Deneme `.local/question-trial.json` içinde bir çalışma kopyası oluşturur. Mevcut yayın havuzu değiştirilmez. Sonuç onaylansa bile önce soru/kaynak/alternatif gerekçeleri kontrol edilir, sonra normal çalışma havuzuna alınarak `publish` çalıştırılır. Reddedilen soru yayınlanmaz. Aynı denemeyi yeniden çalıştırmak yeni bir kelime ve yeni API isteği demektir; kelimeler çalışma kopyasında biriktirilir. Denemeyi yeniden başlatmadan önce önceki sonucu incele.

```sh
npm run check:deploy --prefix functions
```

Bu salt okunur kontrol `firebase.json` Functions predeploy kancasına da bağlıdır. Yerel config'in Git'ten dışlandığını, zorla izlemeye alınmadığını, env dosyalarının ve üretim araçlarının upload'dan çıkarıldığını denetler. Functions env dosyalarında yalnızca `QUESTION_POOL_EXAMPLES=true/false` kabul edilir; anahtarlar `.local` altında kalmalıdır. Runtime dosyalarında anahtar/özel anahtar veya Flutter asset listesinde yerel config tespit edilirse kontrol başarısız olur. Kontrol herhangi bir deploy yapmaz. Yerel CLI/provisioning ve kalite araçları sunucu paketine dahil edilmez. Paylaşılan üretim adaptörü ve bütçe politikası bulut fonksiyonunun parçasıdır; anahtar dosyası paket dışında kalır.

## Karma cevap üretimi — 15 Ekim 2026

Günlük üretici `tr-clue-v4-mixed-answers` istemiyle çalışır. Kaynak kuyruğu yalnız isimlerden oluşmaz: edat, bağlaç, mastar, iki kelimeli ad ve fiil öbeği ile edat öbeği adayları da vardır. `content/mixed_answer_sources.json` eklenen 16 taslağı taşır; bunlar hazır soru veya editör onayı değildir. Kaynak özeti ve hedef anlam üretici/editör tarafından kontrol edilmeden yayımlanmaz. Sözlük bağlantısı verilmiş olması yeni bir canlı sözlük okuması yapıldığı anlamına gelmez.

Cevaplar en fazla iki kelime ve boşluk hariç 4–10 harftir. Doğru yazımdaki boşluklar korunur; `wordLengths` gerçek bölünmeyi taşır. Editör, soruya uyan ve aynı kelime bölünmesine sahip eş anlamlıları `acceptedAnswers` alanına kaydeder. Bu eşdeğerler tek başına ret sebebi değildir; yanlış anlam, kök sızıntısı, yanlış kelime türü ve yetersiz kaynak yine reddedilir.

Günlük hedef, zamanlama, model, çağrı/deneme sınırları ve maliyet tavanları değiştirilmedi. Bu düzenleme yeni API denemesi veya ücretli handler çağrısı başlatmaz. Gerçek üretim, etkin dev zamanlamasında her gün 04.00 Europe/Istanbul saatinde yürür; 42 onaya ulaşılması stok ve editör sonuçlarına bağlıdır. Kuyruk sonludur ve yenilenmesi gerekir.
