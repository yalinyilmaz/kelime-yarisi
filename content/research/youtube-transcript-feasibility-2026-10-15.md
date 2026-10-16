# Kelime Oyunu arşivinden soru havuzu: uygulanabilirlik araştırması

Tarih: 15 Ekim 2026. Kapsam: erişim, soru–cevap çıkarımı, tek seferlik maliyet ve kullanım koşulları. Bu çalışma bir araştırmadır; toplu aktarım veya ücretli servis denemesi yapılmadı.

## Sonuç

Mevcut Türkçe transkriptlerden soru–cevap adaylarını çıkarıp JSON'a dönüştürmek teknik olarak mümkün. Bir bölümde transkript erişimi doğrulandı. Ancak resmî YouTube API'si başkasına ait videoların altyazı metnini yalnızca API anahtarıyla indirmeye izin vermiyor. Toplu erişim izni ile soruları mobil oyunda yeniden kullanma hakkı ayrıca çözülmeli.

Mevcut altyazıları elde etmenin servis bedeli düşük. Asıl belirsizlik, doğru eşleştirilmiş ve tekrar etmeyen kaç sorunun elde edileceği, kontrol emeği ve varsa lisans bedeli. Bu nedenle tüm arşivden önce izin kapsamı netleştirilmiş küçük bir pilot öneriyorum.

## 1. Kanal ve transkript üzerinde doğrulananlar

15 Ekim 2026 tarihli doğrudan tarayıcı gözlemi:

| Gözlem | Bulgular |
| --- | --- |
| Kanalın gösterdiği toplam | 15.335 video; tam bölümler, kısa kesitler ve derlemeler birlikte |
| “Kelime Oyunu · Full Bölümler” listesi | 409 video |
| İncelenen bölüm | 1954. Bölüm, 14 Ekim 2026 |
| Alınan metin | Türkçe, otomatik oluşturulmuş altyazı; zaman damgalı |
| Dosya büyüklüğü | 65.298 bayt; yaklaşık 64 KiB |
| Metin hacmi | Yaklaşık 9.296 sözcük |

Kaynaklar: [kanal](https://www.youtube.com/@KelimeOyunuTv2), [tam bölümler listesi](https://www.youtube.com/playlist?list=PL8q5DJEEe6TuzIxNbnsG8RUnY_sfHaqOY), [incelenen video](https://www.youtube.com/watch?v=yLtDX5QwKx8).

“1954” bölüm numarasıdır. Kanalda 1.954 ayrı tam bölümün erişilebilir olduğunu henüz doğrulamadık. 409 kayıt da kanalın bütün arşivinin bu kadar olduğunu göstermez; diğer yüklemeler henüz envantere alınmadı. Aşağıdaki 1.954 hesabı bir senaryodur.

Tek bölümün metni tarayıcı aracının transkript dışa aktarımıyla alınabildi. Bu deney resmî Data API üzerinden yapılmadı ve bütün videoların erişilebilirliğini kanıtlamıyor. Ücretli sağlayıcıların başarısı ayrıca denenmedi.

Anahtar kelimeler yararlı ama tek başına yeterli değil: örnekte “dokuz harf” hiç bulunmazken “9 harf” beş kez bulunuyor. “Harfli” 26 kez geçiyor; bu sayı soru sayısı değildir. Sunucu kalan harfleri veya önceki bir soruyu da konuşabiliyor. Sayıyla ve yazıyla ifade edilen uzunlukları birlikte tanımak gerekiyor.

## 2. Resmî YouTube API'si

`captions.list` altyazı kanallarını listeler; metni döndürmez. `captions.download` ise videoyu düzenleme yetkisi olan kullanıcının OAuth yetkilendirmesini gerektirir. Kendi hesabımızla giriş yapmak veya API anahtarı oluşturmak TV2 videolarında bu yetkiyi sağlamaz. Kanal sahibinin uygun yetkilendirmesiyle resmî yol değerlendirilebilir. Kaynaklar: [listeleme](https://developers.google.com/youtube/v3/docs/captions/list), [indirme](https://developers.google.com/youtube/v3/docs/captions/download).

Video envanteri için resmî metadata API'si uygundur: kanalın yüklemeler listesi alınır, video kimlikleri sayfalanır, tam bölüm ve tekrar filtreleri uygulanır. Altyazı indirme yetkisi bundan ayrı bir konudur. Kaynaklar: [channels.list](https://developers.google.com/youtube/v3/docs/channels/list), [playlistItems.list](https://developers.google.com/youtube/v3/docs/playlistItems/list).

## 3. Alternatif araçlar ve tek seferlik servis bedeli

Aşağıdaki USD tutarları mevcut altyazıları video başına bir kez alma senaryosudur. Bir aylık plan ve gereken kredi alımları esas alındı. Vergi, lisans, model kullanımı, manuel kontrol, yeni ses transkripsiyonu ve ek endpoint çağrıları dahil değildir. Fiyatlar 15 Ekim 2026'da kontrol edildi; abonelik kendiliğinden tek seferlik değildir, yenileme ayrıca yönetilmelidir.

| Seçenek | Ücret modeli | 409 video | 1.954 video senaryosu |
| --- | --- | ---: | ---: |
| TranscriptAPI.com | Aylık 5 dolar / 1.000 kredi; ek 1.000 kredi 2,50 dolar; başarılı transkript 1 kredi | 5 dolar | 7,50 dolar |
| Supadata Pro | Aylık 17 dolar / 3.000 kredi; mevcut transkript 1 kredi | 17 dolar | 17 dolar |
| Scrapingdog Lite | Aylık 40 dolar / 200.000 kredi; transkript 5 kredi | 40 dolar | 40 dolar |
| youtube-transcript-api | Açık kaynak araç; sağlayıcı aboneliği yok | Servis ücreti yok | Servis ücreti yok; çalışma garantisi yok |

Kaynaklar: [TranscriptAPI fiyatlandırma](https://transcriptapi.com/#pricing), [Supadata fiyatlandırma](https://supadata.ai/pricing), [Scrapingdog fiyatlandırma](https://www.scrapingdog.com/pricing/), [açık kaynak aracın deposu](https://github.com/jdepoix/youtube-transcript-api).

TranscriptAPI ve Supadata 100 ücretsiz kredi sunuyor. Küçük pilot için yeterli olabilir. İlkinde 1.954 transkript hesabı, 5 dolarlık plan ve tek 1.000 kredilik ek paketten oluşuyor; listeleme ve tekrar çağrıları kalan krediyi tüketebilir. Supadata'nın 5 dolar/ay görünen Basic planı yıllık 60 dolar tahsilat gerektirdiğinden bu tek seferlik karşılaştırmada kullanılmadı.

Açık kaynak aracın belgeleri IP engellerini açıkça belirtiyor. Bu yüzden abonelik ücretinin olmaması bakım ve toplu erişim maliyetinin sıfır olduğu anlamına gelmez. Erişim engelini aşmaya dayalı bir çözüm önermiyorum.

Supadata tercih edilirse `mode=native` seçilmeli: varsayılan `auto` modu mevcut metin bulunamazsa yeni ses transkripsiyonuna geçebilir. Yeni transkripsiyon dakika başına 2 kredidir; örneğin altyazısız 100 adet bir saatlik video 12.000 kredi eder. İlk aktarımda bu fallback kapalı, dönen dil Türkçe olarak doğrulanmış olmalı. Kaynak: [transkript API belgesi](https://docs.supadata.ai/get-transcript).

Tüm 15.335 yüklemeyi almak, aynı içeriğin kesitlerini tekrar işlemeye yol açabilir. Yalnız transkript bedeli o senaryoda yaklaşık TranscriptAPI 42,50 dolar, Supadata Mega 47 dolar veya Scrapingdog Lite 40 dolardır. Envanteri daraltmak sonraki kontrol ve model işini de azaltır.

## 4. Soru ayıklama ve kontrol maliyeti

Yerel kurallar aday konuşma aralıklarını seçer. Model yalnız bu aralıklardan soru, onaylanan cevap ve kaynak zamanlarını çıkarır. Yarışmacının yanlış tahmini doğru cevap sayılmaz; metinde bulunmayan cevap uydurulmaz. Belirsiz kayıtlar inceleme kuyruğunda kalır.

Luna ile örnek hesap için resmî `gpt-6-luna` standart fiyatı: milyon input token başına 0,10 dolar, output başına 0,50 dolar. Bu fiyat sayfasındaki model adı kullanıldı; bir “6.1 Luna” fiyatı varsayılmadı. Kaynak: [OpenAI model ve fiyat belgesi](https://developers.openai.com/api/docs/models/gpt-6-luna).

| Bölüm başına toplam ayıklama + kontrol varsayımı | Bölüm başı | 409 bölüm | 1.954 bölüm |
| --- | ---: | ---: | ---: |
| 20.000 input + 5.000 ücretlendirilen output token | 0,0045 dolar | 1,84 dolar | 8,79 dolar |
| 50.000 input + 10.000 ücretlendirilen output token | 0,0100 dolar | 4,09 dolar | 19,54 dolar |

Formül: `(input × 0,10 + output × 0,50) / 1.000.000`.

Bunlar ölçülmüş token tüketimi veya kalite garantisi değildir. Tüm model çağrıları ve ücretlendirilen reasoning/output tokenları toplama dahil olmalıdır. Tekrar denemeler, görüntüden okuma ve ek kontroller gideri artırabilir. Pilot gerçek tüketimi ölçmelidir.

Bu varsayımlarla 1.954 bölüm için TranscriptAPI + Luna yaklaşık 16–27 dolar, Supadata + Luna yaklaşık 26–37 dolardır. Bunlar toplam proje bedeli değildir: lisans, geliştirme, manuel editörlük ve gerektiğinde görüntü kontrolü ayrıca kalır. Bu çalışma kapsamında ücretli sağlayıcı veya OpenAI API çağrısı yapılmadı.

## 5. Kalite ve havuza aktarım

Yayın sorusunun editörce hazırlanmış olması otomatik altyazıyı da onaylanmış yapmaz. Türkçe karakterler, özel isimler, konuşmacı değişimleri ve cevabın sadece ekranda görünmesi eşleştirmeyi bozabilir.

Önerilen akış:

1. Tam bölüm envanteri oluştur; kesitleri ve tekrar yüklemeleri ayır.
2. İzin kapsamındaki Türkçe altyazıyı zamanları ve kaynak bilgisiyle al; tekrar indirmeyi önle.
3. Sayısal/yazılı harf uzunluğu işaretleriyle aday aralıkları seç.
4. Soru ile son doğrulanan cevabı eşleştir; belirsizleri ayır.
5. Türkçe normalizasyonu, mevcut oyunun 4–10 harf koşulları ve tekrar denetimini uygula.
6. Kontrolden geçen ve kullanım hakkı net olan kayıtları mevcut havuz formatına dönüştür.

JSON kayıtları en az `clue`, `answer`, `answerId`, `length`, `source.videoId`, `source.startSeconds`, `source.endSeconds`, `source.captionKind`, `reviewStatus` ve kullanım izni referansı taşımalı. Kaynak zamanları editörün doğru bölümü hızla kontrol etmesini sağlar.

Tekrarı yalnız soru metnine göre değil normalize edilmiş cevap kimliğine göre de değerlendirmeliyiz. Aynı kelimenin farklı tanımı, oyuncu açısından mutlaka yeni cevap değildir. Bölüm sayısından on binlerce benzersiz soru veya belirli sayıda 14'lü set garantisi çıkarılamaz; uzunluk dağılımı da set sayısını sınırlar.

Bu tarihsel aktarım tek seferlik bilgisayar işi olabilir; bunun için günlük Cloud Function zorunlu değildir. Ham transkriptler uygulama paketine konmaz; mevcut havuzun kullanacağı onaylı soru kayıtları aktarılır.

## 6. Kullanım izni ve önerilen sonraki karar

YouTube'un koşulları otomatik erişimi ve içeriğin hizmet dışına kopyalanmasını sınırlar. API geliştirici politikaları doğrudan veya dolaylı scraping'i ayrıca sınırlar. Üçüncü tarafın ücretli API sunması bu kısıtları veya soru bankasının kullanım haklarını ortadan kaldırmaz. Kaynaklar: [YouTube kullanım koşulları](https://www.youtube.com/static?template=terms), [API geliştirici politikaları, E.6](https://developers.google.com/youtube/terms/developer-policies).

Bu, her sıradan kelimenin veya tanımın tek başına korunduğu yönünde bir hukuki sonuç değildir. Ancak yayın arşivinden sistematik soru bankası çıkarıp oyunda kullanmak için hak sahibinin izin/lisans kapsamı netleştirilmelidir. Erişim izni ile ticari yeniden kullanım hakkı ayrı ele alınmalıdır. Lisans bedeli bilinmiyor.

İlk tercih, TV2/hak sahibinden kullanım izniyle birlikte orijinal soru–cevap verisini CSV/JSON olarak istemek olur. Bu, transkript hatalarını ve eşleştirme işini azaltabilir. [TV2 iletişim bilgileri](https://www.tv2.com.tr/kunye) mevcut; bu araştırmada iletişim kurulmadı.

Uygun izin kapsamıyla 10–20 farklı dönemden bölüm üzerinde pilot yapılmalı. Elle doğrulanmış 100–200 soru–cevaplık örnekle altyazı kapsaması, çıkarım doğruluğu, kaçırılan sorular, benzersiz cevap sayısı/uzunluğu, kontrol süresi ve onaylı yeni soru başına gider ölçülmeli. Büyük aktarım kararı bu sonuçlara dayanmalı. Mevcut günlük üretim sistemi bu araştırma için değiştirilmedi; oyun havuzuna TV2 sorusu eklenmedi.
