# Luna pilotu — revizyon incelemesi

15 Ekim 2026. [Revize JSON](/Users/yalinyilmaz/flutter_apps/kelime_yarisi/content/sets/luna_pilot_001.exchange.json), [önceki inceleme](/Users/yalinyilmaz/flutter_apps/kelime_yarisi/content/sets/luna_pilot_001.review.md).

## Sonuç

İlk beğenilen set 10 kabul edildiğinde öznel editör puanım **7,5/10**; önceki partiye verdiğim puan 6/10 idi. Bu bir benchmark veya oyuncu testi değil, 42 soru ve 42 ipucunu okuyarak yaptığım karşılaştırmalı değerlendirme. Metinler daha doğal ve alternatif cevap gerekçeleri daha ciddi. Buna rağmen revizyon yeni dil bilgisi ve cevap sızıntısı sorunları da üretmiş. Mevcut onay etiketlerini doğrudan yayın onayı olarak kabul etmiyorum.

## Gerçek ilerleme

- Önceki 42 soru cümlesi bitişi yerine artık hiçbir ana soru soru işaretiyle bitmiyor. Bazı metinler yalnız son ek silinerek değil, yeniden kurulmuş; özellikle ses/etki, kıyı/giyim ve gündelik eylem/halk oyunu anlamlarını buluşturan adaylar iyi yönde.
- Editör gerekçelerinin 42'si de birbirinden farklı; önceki sürümde 41'i aynı genel cümleydi. Alternatif eleme artık daha çok son soru metnine bağlanıyor.
- Toprağı işleme aracındaki ters ipucu kaldırılmış. Optik araçta iki cam koşulu ve bütünü tarif eden anlatım eklenmiş. Kuvvet sorusunda fiziksel kavram açıkça söylenmiş. Bilgi toplamı sorusunun konu etiketi ve bağlamı iyileşmiş.
- 42 benzersiz cevap, her sette her uzunluktan iki soru, toplam harf ve kelime bölünmesi kontrolleri geçiyor. Üç veya daha fazla kelimeli cevap yok. Yerel ana havuz, kaynak kuyruğu ve ilk set ile cevap çakışması bulunmadı; canlı ek havuz sorgulanmadı.

## Yayın öncesi gerekli düzeltmeler

### 1. Sözcük türü ve hedef anlam

**initial_002_q06**: “Keşke öyle yapmasaydım” dedirten sonucun ardından duyulan **üzüntü** soruluyor; cevap **PİŞMAN**. Bu bir kişi sıfatıdır. Metin, kişinin o durumunu nitelemeli; duygunun adını sormamalı. Şu an altı harfli **ÜZÜNTÜ** dahi cümlenin kendi içinden çıkan doğal bir yanıttır. Ek ipucu da “bu duygu” diyerek hatayı pekiştiriyor. `meaning` ve `meaningEvidence` de sıfatın anlamını doğru sözcük türüyle anlatmalı.

**initial_004_q13**: Hedef sıfat korunacaksa sonun “ev sahibinin niteliği” yerine kişiyi/ev sahibini niteleyen doğal bir tanım olması daha açık. Bu, önceki madde kadar ağır olmasa da aynı sözcük türü denetiminde düzeltilmeli.

### 2. Yeni aynı uzunlukta alternatif

**initial_004_q12**: “Bir konferans programında sunumuyla yer alan kişi; salondaki dinleyicilerden biri değil” metni **KONUŞMACI** cevabına doğrudan uyuyor; o da dokuz harfli ve pilotta zaten başka bir sorunun cevabı. Hedef **KATILIMCI** daha geniş bir rol. Konuşmacıyı zorunlu kılıp dinleyiciyi dışlamak hem ayrımı ters yöne götürüyor hem ana anlamı daraltıyor. Kayıt genel etkinlikte yer alma anlamına dönmeli; konuşmacı, dinleyici ve diğer etkinlik rollerini kapsayarak hedefi ayırt etmeli. Editörün yalnız `DİNLEYİCİ` alternatifini elemesi yeterli değil.

### 3. Cevabın kökünü verme

- **initial_003_q02:** OYUK için ana soruda “Oyulmuş” kullanılıyor; aynı kökü doğrudan veriyor.
- **initial_003_q09:** BAĞLANTI için ek ipucunda “bağlandığı” geçiyor; kök ailesi doğrudan açılıyor.
- **initial_002_q08:** BİRİKİM için ek ipucunda “biriktirilmiş” kullanılıyor; hedefin büyük bölümünü veren aynı kök söz konusu.

Bu sızıntılar, `rootText` alanına her zaman gerçek kök yerine tam sözcük yazılınca basit başlangıç denetiminden kaçabiliyor. Son metinlerde dilsel kök/kelime ailesi kontrolü de yapılmalı. İpucu hakkı, aynı kökü okuyucuya gösterme yerine farklı bir anlam veya kullanım bağlamı sağlamalı.

### 4. İlk hazır setin zorluk dengesi

`initial_002`: **5 kolay, 8 orta, 1 zor**. Mevcut [set seçicisi](/Users/yalinyilmaz/flutter_apps/kelime_yarisi/functions/src/set_selector.js:39), 14 soruda aynı zorluk grubunu en fazla 7 olarak sınırlandırıyor. Bu 14 kayıt tek başına hazır set olarak kullanılacaksa sınırı aşıyor. Soruların gerçek zorluğu gerekçeyle yeniden değerlendirilmeli veya soru değişimi yapılmalı; sırf denetim geçsin diye etiket değiştirilmemeli.

Diğer iki set dağılımı bu sınırı sağlıyor. Sorular birleşik havuzdan yeniden karıştırılırsa bu durum bütün havuzun kullanılamadığı anlamına gelmez; sorun bu hazır setin kendi dağılımıdır.

## Kısmen iyileşen fakat yeniden kontrol gerektirenler

- **initial_003_q05:** Önceki altı harfli taş alternatifi bileşim koşuluyla daraltılmış. Ancak yüksek kalsiyum karbonat ve cilalanabilirlik tek başına başka altı harfli bir taş olan KALKER ihtimalini yeterince dışlamıyor. Kireç taşının başkalaşım/yeniden kristalleşme niteliği daha ayırt edici ve daha doğru bir çerçeve sağlar. Kesin yüzde eşiğini oyuncuya ezberletmek soruyu ağırlaştırıyor. Mermerin jeolojik anlamındaki ayrım [BGS'nin yapı taşları açıklamasında](https://earthwise.bgs.ac.uk/index.php/Building_stones_of_Edinburgh:_geological_characteristics_of_building_stones) da yeniden kristalleşmiş kireç taşı üzerinden yapılıyor.
- **initial_003_q06:** Tatlı anlamı ana soruya taşınarak eş anlam ayrımı kurulmaya çalışılmış. Bu, doğru editör yaklaşımı. Fakat “BÜKLÜM tatlı anlamını karşılamaz” dışlaması bağımsız olarak doğrulanmış değil. İki TDK API sorgusu bu incelemede ağ hatasıyla sonuçlandı; yeniden denenmedi. Tam çözülmüş ilan etmiyorum. `meaningEvidence` şu anda yalnız kat/büklüm anlamını anlatıyor; tatlı anlamının somut kaynak desteği de eklenmeli.
- **initial_002_q03:** Soru daha canlı, ancak muhallebinin koyulaşmasını anlatan cümle hangi özelliğin arandığını yeterince açık belirtmiyor. Kısa bir “koyuluk/akış derecesi” hedefi korunursa oyun sorusu olarak daha anlaşılır olur.
- **initial_002_q11:** Birkaç demlik ve işletme tezgâhı ayrımı eskiye göre güçlü. Kelime bölünmesinin **3+6** olarak gösterilmesi, tek kelimeli dokuz harfli alternatiften ayrımı ayrıca destekler. Bu yapıyı kullanıcıya gösterecek giriş desteği henüz ayrı uygulama işidir.
- **initial_003_q08:** Anlam düzeldi; “kuvvet; fiziksel anlamıyla kuvvet büyüklüğü” yineleniyor. Daha kısa ifade yeterli.

## İpucu ve kayıt güvenilirliği

Ek ipuçları hâlâ ana sorular kadar iyileşmiş değil. Bazıları aynı bilgiyi örnekle tekrar ediyor: şiir satırı/dörtlük, limanda barınma/yük işlemleri, sözü alan kişi/anlatım yapan kişi, kil ürününü yapan kişi/pişmiş kil ürünleri gibi. Her ipucunun aynı güçte olması beklenmez; fakat oyuncunun sınırlı hakkını kullanınca yeni bir yardım alması gerekir.

**initial_004_q02** ipucunda doğrudan “TDK” deniyor; **initial_004_q09** ipucunda “Sözlükte...” diye başlanıyor. Bunlar doğrulama notunun oyun metnine taşınmasıdır. Oyuncuya doğrudan ek bilgi verilmeli.

`source.hintEvidence` alanı 41 soruda aynı genel cümleye dönüşmüş. Farklı editör gerekçeleri olumlu olsa da bu alan belirli ipucunun hangi kaynak olgusuyla desteklendiğini artık göstermiyor. Her kayda kısa ve özgül destek yazılmalı; gerçekten okunmayan kaynak `verified` olarak sunulmamalı.

**initial_004_q14** için editör notu “doğrulanmamış içtenlik anlamı çıkarıldı” diyor. Bu anlam ek ipucundan çıkarılmış olsa da `meaning` ve `source.meaningEvidence` içinde **“ayrıca içtenlik ve açık yüreklilik” hâlâ duruyor**. Oyuncuya görünen metin yanında destek alanları da temizlenmeli.

Kaynakların tamamı bu turda baştan doğrulanmadı. Somut yazım/anlam notları ve yapısal kontroller yapıldı; bunlar eksiksiz kaynak/lisans denetimi değildir. Taşıma JSON'u hâlâ `unpublished` ve mevcut backend ile doğrudan uyumlu değil.

## Süre, maliyet ve devam

Dosyadaki **1.413 saniye**, önceki üretim turuna ait. Revizyonun yeni süresi veya yeni kota tüketimi eklenmemiş; revizyonun da 23 dakika sürdüğü veya aynı maliyete yapıldığı sonucunu çıkaramayız. Token/USD değerlerinin bilinmediği açıkça korunmuş.

Önerim: yöntem kullanılabilir görünüyor; kalan iş dar bir son editör turudur. Önce yukarıdaki sözcük türü, aynı uzunlukta alternatif, kök sızıntısı ve set dengesi sorunları düzeltilmeli; sonra zayıf ipuçları seçilerek tamamlanmalı. Bütün 42 soruyu yeniden üretmek yerine hedefli düzeltme yapılmalı. Bir düzeltilmiş set kullanıcı denemesinden geçince bu son kontroller yeni üretimin zorunlu kabul koşullarına eklenebilir.

Bu inceleme JSON'u, uygulama kodunu veya yayın havuzunu değiştirmedi.
