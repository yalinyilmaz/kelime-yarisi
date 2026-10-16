# Luna pilotu — kalite incelemesi

15 Ekim 2026. İncelenen dosya: [luna_pilot_001.exchange.json](/Users/yalinyilmaz/flutter_apps/kelime_yarisi/content/sets/luna_pilot_001.exchange.json).

## Karar

Kullanıcının beğendiği ilk seti 10 kabul eden öznel editör değerlendirmem: **bu parti yaklaşık 6/10**. Bu bir model benchmark'ı veya oyuncu testi değildir. 42 soru ve ek ipuçlarının tamamı okundu. Ham aday havuzu kullanılabilir; mevcut biçimiyle yayın onayı vermiyorum. Özellikle aşağıdaki sekiz kaydın içeriği düzeltilmeden kullanılmaması gerekir. Diğer kayıtlarda da üslup, ek ipucu ve yer yer anlam kesinliği üzerinde çalışılmalı.

İlk örnek set de kusursuzluğun ölçüsü değildir; burada kullanıcının sevdiği doğallık, kısa anlatım ve kelimenin farklı kullanımlarını buluşturma niteliği referans alındı.

## Doğrulanan sayılar

- Üç sette 14'er soru; her sette 4–10 harfin her birinden iki cevap var.
- 42 farklı cevap var; NFC harf sayıları ve `wordLengths` hesapları tutarlı. En fazla iki kelime koşulu sağlanıyor. İki kelimeli bir cevap var; bu sayı görevde zorunlu kota olmadığı için eksiklik sayılmadı.
- Yerel 140 soruluk ana havuz, 90 kaynak adayı ve ilk 14 soruluk set ile cevap tekrarı bulunmadı. Canlı ek havuz sorgulanmadı.
- 42 sorunun tamamı soru işaretiyle bitiyor; 23'ü “nedir?”, 9'u “ne denir?” kalıbıyla bitiyor. Sorun tek başına noktalama değil, bütün partinin benzer sözlük/sınav cümlesine dönüşmesi.
- 42 kayıt da `approve`; 41 kayıtta aynı genel editör gerekçesi var. Alternatif cevap açıklamaları farklı olsa da yalnız yedi soruda incelenen alternatiflerden en az biri hedefle aynı harf sayısında. Farklı uzunluktaki alternatifleri incelemek yararlı olabilir; aynı uzunluktaki gerçek rakipleri kaçırmak ciddi bir açık.
- Ortak kök açısından iki farklı sette aynı kök ailesinden kayıt bulunuyor. Bu, aynı sette kök tekrarı kuralını ihlal etmiyor; fakat 100 sete büyürken bağımsız cevap çeşitliliğini ayrıca izlemek gerekir.

## Öncelikli sekiz içerik düzeltmesi

1. **initial_002_q08:** “Tek tek gözlem ve deneylerden elde edilen şeylerin bütünü” ifadesi çok soyut. Aynı yedi harfli deneyim/tecrübe sözcükleriyle ayrımı yeterince güçlü değil. Kaydın konu etiketi de “duygular”; soru bu kategoriyi desteklemiyor. Ek ipucunda TDK maddesinin alanlarını saymak oyun içi yardım niteliğini zayıflatıyor.
2. **initial_002_q11:** Altta su kaynatıp üstte demlik taşıyan gereç tarifi, başka bir dokuz harfli yaygın gerece de uyuyor. İşletmede kullanılması ayrımı kesinleştirmiyor. Editörün reddettiği diğer gereç için “üstte ayrı demlik düzeni tarif edilmiyor” demesi, soru metnindeki “üstte demlik taşıyan” ifadesiyle de uyuşmuyor. Boyut, musluk veya kullanım düzeni gibi gerçekten doğrulanmış ayırt edici bir özellik gerekli.
3. **initial_003_q05:** Alternatifteki altı harfli taşın elenmesi için gerekçede kireç taşı bileşimi kullanılıyor; bu koşul asıl soruda yok. Damarlı, billurlaşmış, yontulup parlatılabilen doğal taş betimlemesi tek başına yeterince ayırt edici değil. Gerekçede düşünülen bilgi kullanıcıya soruda verilmedikçe alternatif elenmiş sayılmaz.
4. **initial_003_q06:** Soru, altı harfli yakın eş anlamlıyı kendi içinde açıkça kullanıyor. İncelemede ise yalnız üç harfli bir alternatif var. Aynı uzunlukta başka doğal cevap da uyuyorsa ana soru netleştirilmeli veya değiştirilmelidir. Ek ipucundaki başka anlamın doğru olması, temel sorunun belirsizliğini tek başına gidermez.
5. **initial_003_q08:** Fizik bağlamında “yer çekimi etkisindeki ölçüsü” yerine kuvveti açıkça tarif eden bir metin gerekli. Harf sayısı cevabı buldurabilse de bilimsel anlam belirsiz bırakılmamalı.
6. **initial_003_q11:** Kapıda ilk hoş geldin sözünü söyleme tarifi, başka bir dokuz harfli kabul/selamlama eylemine de açık. Dans anlamı şu anda sadece ücretli/isteğe bağlı ek ipucunda. Ana sorunun adil çözümü için ayırt edici bağlam ana metne taşınmalı; ardından ek ipucu yeniden yazılmalı.
7. **initial_004_q02:** Asıl soruda yüzey toprağını kabartma ve ot ayıklama soruluyor; ek ipucu ise “toprağı kazıp taşımada kullanılır; yüzey toprağını işleme görevi değildir” diyor. Bu, reddedilen alternatifin açıklamasının yanlışlıkla ipucuna taşınmış olmasına benziyor. Kaynak beyanıyla da çelişiyor. İpucu kesinlikle yeniden yazılmalı.
8. **initial_004_q05:** “Çerçeveye yerleştirilen optik araç” ifadesi bütünü/parçayı karıştırıyor. Ayrıca altı harfli alternatif tek gözlük olduğu için elenmiş; asıl soruda iki göz veya iki cam koşulu yok. Editörün zihnindeki koşul metne taşınmalı ve cümle düzeltilmeli.

## Diğer kayıtlar dahil soru bazında notlar

Bu tablo yeni bir otomatik onay listesi değildir. “Üslup” notu, sözcüğün değiştirilmesi gerektiği anlamına gelmez; metnin yarışma dilinde iyileştirilmesini belirtir.

| Kayıt | Editör notu |
| --- | --- |
| initial_002_q01 | Geometrik tarif açık. İki anlamlı ek ipucu potansiyel olarak iyi; kart terimi hassaslaştırılmalı. Ana soru sınav dilinden çıkarılabilir. |
| initial_002_q02 | Temel soru anlaşılır; ek ipucu aynı bilgiyi neredeyse aynen tekrarlıyor. Alternatif ret gerekçesi de neden cevap olamayacağını açıklamıyor. |
| initial_002_q03 | Sos örneği somut ve iyi başlangıç. Son ek kalıbı kaldırılarak akıcı bir tanıma dönüştürülebilir. |
| initial_002_q04 | Araçtaki sesli uyarıcı için aynı beş harfli alternatif de bağlama uyabilir. Sıradan sürücü/olağan uyarı bağlamı veya başka ayırt edici özellik açıklaştırılmalı. |
| initial_002_q05 | “Örtü ve nevresimden ayrı” ifadesi yeterince somut değil. Başka altı harfli yatak eşyalarından ayrım, yatağa serilen katman üzerinden netleştirilmeli. |
| initial_002_q06 | Hedef duygu anlaşılır. Ek ipucu yeni bilgi sağlamıyor; kişinin hâlini sorma biçimi daha doğal yazılabilir. |
| initial_002_q07 | Hedef net; göreli zorluk 3 yüksek olabilir. Nişan/rütbe ipucunun seçilen anlamı kaynakla tekrar netleştirilmeli. |
| initial_002_q08 | Öncelikli içerik düzeltmesi; soyut toplam/deneyim ayrımı, konu etiketi ve sözlük odaklı ek ipucu. |
| initial_002_q09 | Anlam çoğunlukla anlaşılır. Tanım çok genel; somut ve kısa bir anlatım daha güçlü olur. |
| initial_002_q10 | Genel meslek sorusu kullanılabilir. Ek ipucu ana sorudaki besteleme/icra bilgisini tekrarlıyor. |
| initial_002_q11 | Öncelikli içerik düzeltmesi; aynı uzunluktaki başka gereç ve çelişkili alternatif gerekçesi. |
| initial_002_q12 | Ana hedef anlaşılır. Ek ipucu, zaten anlatım yapan kişiyi aradığımız bilgisini tekrar ediyor. |
| initial_002_q13 | İç tutarlılık fikri iyi. “Konusuyla bağdaşma” ifadesi gereksiz karmaşa yaratıyor; zor sınıfı yeniden değerlendirilmeli. |
| initial_002_q14 | Gündelik hedef ile teknik anlam arasında iyi ipucu fikri var. Teknik anlam yeniden doğrulanarak daha canlı bir ana metin kurulabilir. |
| initial_003_q01 | Sözcük uygun. Ana metin sözlük tanımına yakın; ek ipucu bahçe bilgisini tekrar ediyor. |
| initial_003_q02 | Somut nesne/durum iyi. Oluşma biçimini zorunlu tek yol gibi sunmadan daha doğal betimle. |
| initial_003_q03 | Fiziksel ve toplumsal anlam iki ayrı güçlü malzeme. Şu an ana soruda sadece basit tanım var; çift anlam ana metinde değerlendirilebilir. |
| initial_003_q04 | Hedef kolay ve açık. Ek ipucu sivrilik/batıcılık bilgisini tekrar ediyor. |
| initial_003_q05 | Öncelikli içerik düzeltmesi; ayırt edici bileşim bilgisi asıl soruda yok. |
| initial_003_q06 | Öncelikli içerik düzeltmesi; aynı uzunlukta yakın eş anlamlı. |
| initial_003_q07 | Üretim tekniği ve ürün örnekleri işlevli. Üslup düzeltmesiyle korunabilecek adaylardan. |
| initial_003_q08 | Öncelikli içerik düzeltmesi; fiziksel büyüklüğün tanımı kesinleştirilmeli. |
| initial_003_q09 | Temel anlam anlaşılır; ana soru çok geniş. Alanlar arası ek ipucu daha seçici kullanılabilir. |
| initial_003_q10 | Hedef anlaşılır. Ek ipucu döşeli yol bilgisini tekrar ediyor; başka doğrulanabilir özellik gerekli. |
| initial_003_q11 | Öncelikli içerik düzeltmesi; aynı uzunluktaki diğer eylem ve ana sorudan ayrı tutulan ayırt edici anlam. |
| initial_003_q12 | Farklı alanlardaki anlamları bağlamak için iyi malzeme var. Sıralama ile etkinlik hazırlama ilişkisi daha doğal yazılmalı. |
| initial_003_q13 | Temel anlam kullanılabilir. Ek ipucu karşı koyma bilgisini yeniden söylüyor; üslup ve yardım değeri geliştirilmeli. |
| initial_003_q14 | Bir başka soyut süreç tanımı. Ana soru ve ipucu aynı ilerletme/iyileştirme bilgisini tekrarlıyor. |
| initial_004_q01 | Gündelik nesne ile coğrafi anlamın birlikte kullanılması için iyi aday. Şu an ana soru düz parça tanımı. |
| initial_004_q02 | Öncelikli içerik düzeltmesi; ipucu asıl soruyla ters düşüyor. |
| initial_004_q03 | Ayırt edici havsız dokuma özelliği iyi. Küçük üslup düzeltmesiyle korunabilecek adaylardan. |
| initial_004_q04 | Hedef açık. Fırtınadan koruma ipucu, barınma bilgisinin ötesinde ne kattığı açısından iyileştirilmeli. |
| initial_004_q05 | Öncelikli içerik düzeltmesi; bütün/parça anlatımı ve eksik iki göz koşulu. |
| initial_004_q06 | Alan doğru hedeflenmiş. Ek ipucu yine doğru düşünme ifadesini tekrar ediyor. |
| initial_004_q07 | Harf sayısı hedefi daraltıyor; ikinci alan anlamı iyi potansiyel. Ek anlamı kaynakla doğrulayarak üslup geliştirilmeli. |
| initial_004_q08 | Aynı uzunlukta yakın anlamlıyla ayrım tekrar ele alınmalı. “Kuşaktan kuşağa” vurgusu için verilen ret gerekçesi tek başına güçlü değil. |
| initial_004_q09 | Süssüzlük, anlaşılabilirlik ve doğallık farklı anlatım nitelikleriyle karışıyor. Hedef anlam daraltılmalı, ek ipucu tekrardan çıkarılmalı. |
| initial_004_q10 | Sözcük mümkün; soru oldukça soyut, ek ipucu da zayıf. Somut bir kullanım daha iyi olur. |
| initial_004_q11 | Üretici adı açık. Önceki setteki kökle yakınlığı çeşitlilik açısından takip edilmeli; ipucu işlem aşamalarını tekrar ediyor. |
| initial_004_q12 | Hedef anlaşılır fakat genel bir etkinlik tanımı. Ek ipucundaki sunum olasılığı çok az yardım sağlıyor. |
| initial_004_q13 | Gündelik karşılığı kullanılabilir. Ek ipucu ağırlama ve sıcak davranma bilgisini yineliyor. |
| initial_004_q14 | Ana anlam makul. İçtenlik/açık davranma ek anlamı bu incelemede bağımsız biçimde doğrulanamadı; yeniden kaynak kontrolü gerekli. |

## Kaynak ve inceleme sınırı

Bu, bütün kaynak maddelerinin baştan doğrulandığı bir olgu/lisans denetimi değildir. JSON'daki `verified` etiketleri, kendi başına bağımsız doğrulama sayılmadı. Üç örnek `/kelime/` bağlantısı web aracından açılamadı; bu durum tek başına bağlantıların uydurma olduğu anlamına gelmez. Bazı URL'lerde Türkçe büyük/küçük harf dönüşümünden kalmış birleşik nokta ve i/ı sorunları da var.

TDK API'sinde altı maddelik sınırlı kontrol yapıldı. Dört istek zaman aşımı/ağ hatasıyla tamamlanamadı; yeniden döngüye sokulmadı. [Çapa kaydı](https://sozluk.gov.tr/gts?ara=%C3%A7apa) ve [yüreklilik kaydı](https://sozluk.gov.tr/gts?ara=y%C3%BCreklilik) okunabildi. İlkinde toprağı işleme aracı anlamı doğrulandı. İkincisi “yürekli olma durumu” ve o kişiye yakışır davranış biçiminde tanımlanıyor; pilotun ek ipucundaki içtenlik anlamını tek başına bu madde kanıtlamıyor. Bu nedenle o ipucu için ek kaynak kontrolü istendi.

## Süre ve kullanım

Dosyada bildirilen süre **1.413 saniye = 23 dakika 33 saniye**; set başına ortalama **7 dakika 51 saniye**. Bunlar dosyanın raporladığı değerler; bu incelemede başlangıç/bitiş olayları bağımsız olarak ölçülmedi.

Beş saatlik kota %28'den %31'e, haftalık kota %13'ten %14'e çıkmış: sırasıyla **3 ve 1 yüzde puan** fark. Hesap geneli ve yuvarlanmış ölçüler olduğundan kesin görev maliyetine veya 100 setin garantili tüketimine dönüştürülemez. Token ve USD alanlarının `null` bırakılması doğru. `model=null` olması da arayüzden seçilen modelin bu dosyadan bağımsız doğrulanamadığını gösterir; kullanıcının Luna ile çalıştırdığı beyanı esas alındı.

## Önerilen devam

Yeni 99 seti başlatmadan önce **mevcut 14 soruluk tek set üzerinde ikinci editör turu** yap. Kelimeleri ve geçerli kaynak emeğini koru; sorunlu birkaç cevabı gerekirse değiştir. Daha fazla kaynak taramak yerine, öncelikle cümleleri ve gerçekten yeni bilgi veren ipuçlarını düzelt.

Revizyon görevine şu somut kabul koşullarını ekle:

- Soruları varsayılan olarak kısa tanım/çağrışım cümlesiyle yaz. Yalnız “nedir?” sözcüğünü silmek editör düzeltmesi sayılmaz. 14 soruda otomatik “nedir/ne denir/ne ad verilir” bitişleri olmasın.
- Uygun adaylarda farklı anlamları birleştir; her soruya zorla mecaz veya kelime oyunu ekleme. Sayı kotası yerine doğallık ve ayırt edicilik değerlendirilsin.
- Ana soru, ek ipucu kullanılmadan da adil biçimde çözülebilsin. Kelime bölünmesi ve harf sayısı veriliyorsa ayrım bunlarla birlikte değerlendirilsin.
- Editör, gerçekten aynı harf sayısında uyabilen cevabı arayıp son soru metninden hareketle değerlendirsin. Soruya yazılmamış koşullarla alternatif elemesin.
- Ek ipucu yeni ve doğru bilgi katsın; başka alana veya kullanım biçimine ilişkin somut bir özellik tercih edilsin. “TDK maddesinde ... vardır” gibi sözlük inceleme notları oyun metni olmasın. Bilgi bulunamazsa başka soru seçilsin.
- Soru bazındaki editör gerekçesi, o sorunun ayırt edici unsurunu ve varsa kalan belirsizliği anlatsın. Bütün kayıtlara aynı onay cümlesi yazılmasın; ret kararı normal kabul edilsin.
- Düzeltilen soru değişince eski onay otomatik geçerli sayılmasın. Revize metin, ipucu ve kaynak desteği tekrar incelensin.
- Önce bir set kullanıcı tarafından değerlendirilsin; hedef kaliteye ulaşıyorsa aynı düzen kalan iki sete, ardından daha büyük partilere uygulansın. Bu inceleme mevcut JSON'u veya yayın havuzunu değiştirmedi.
