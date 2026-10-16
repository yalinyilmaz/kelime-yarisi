# Kelime Yarışı — proje çalışma kuralları

Bu dosya, global `AGENTS.md` kurallarını bu proje için tamamlar. Aşağıdaki açık istisnalar global varsayımların önüne geçer.

## Kapsam ve iletişim

- Kullanıcının seçtiği modeli ve reasoning ayarını koru.
- Jev Token Saver bu projede kapalıdır. `mcp__jev_token_saver` araçlarını kullanma. Dar kapsamlı `rg` aramaları ve sınırlı dosya okumalarıyla ilerle. Bu istisna uygulamanın Firebase oturum/token güvenliğini değiştirmez.
- YAGNI uygula: mevcut kodu ve bağımlılıkları kullan; gereksiz kod, spekülatif soyutlama, bağımlılık veya ilgisiz düzenleme ekleme.
- Kullanıcının mevcut değişikliklerini koru. İşi küçük, tutarlı değişikliklerle tamamla.
- Sonucu önce söyle, kısa ve açık yaz. Anlamı belirsiz bir gereksinim veya veri kaybı, maliyet, güvenlik ya da canlı davranışı etkileyebilecek belirsizlik varsa kullanıcıya soru sor. Açıkça yetkilendirilmiş rutin adımlar için tekrar onay isteme.
- Her final yanıtını gerçekten kullanılan skill adlarıyla bitir; hiç kullanılmadıysa `Kullanılan skill: yok.` yaz.

## Ortamlar ve gizli bilgiler

- Dev: `kelime-yarisi-yalin`. Prod: `kelime-yarisi-prod`. Komutlarda hedef projeyi açıkça belirt; dev/prod ayarlarını karıştırma.
- Kullanıcının talebini dev üzerinde çöz. Prod değişikliği için açık yetki gerekir.
- Gizli API anahtarlarını, App Check debug tokenlarını, oturum tokenlarını ve özel anahtarları çıktıya yazma; Git'e, Flutter asset'lerine veya deploy paketine ekleme. Firebase istemci yapılandırmalarını mevcut yerel/ignore düzeninde tut; native Firebase başlangıcını koru.
- Yerel gizli dosyaları ve mevcut ignore/deploy korumalarını koru. Güvenlik kurallarını veya App Check doğrulamasını hatayı gizlemek için gevşetme.

## Test ve gerçek cihazlar

- Entegrasyon ve oyun davranışı testlerinde kullanıcının gerçek Android/iOS cihazlarını tercih et. Bağlı cihazları kontrol et; gereken cihaz bağlı değilse bağlamasını iste.
- Uygulamaya test için `USE_FIREBASE_EMULATORS`, emulator yönlendirmesi, sahte Firebase uygulaması veya benzeri kalıcı başlangıç seçenekleri ekleme. Soru havuzunu da gerçek cihazda dev Firebase ile test et.
- Uygun birim/widget testlerini ihtiyaç kadar çalıştır; cihaz doğrulamasını yapmadıysan yapılmış gibi raporlama.
- Bir davranışı farklı cihazlarda veya güvenlik kurallarını izole ortamda doğrulamak için emulator teknik olarak gerçekten gerekirse nedenini açıkla. Kullanım geçici olsun; süreçleri durdur ve bu iş için üretilen gereksiz dosyaları temizle. Belirsizlik, veri kaybı veya ek maliyet riski varsa önce kullanıcıya sor.
- Test odası veya test verisi oluşturursan yalnız kendi oluşturduğun kayıtları iş sonunda temizle. Kullanıcının oyun verisini veya soru havuzunu silme.

## Disk ve iş sonu temizliği

- Büyük build/test işleminden önce boş alanı ve mevcut çıktı dizinlerini kontrol et. Mümkünse mevcut çıktıları yeniden kullan; gereksiz APK/IPA/archive kopyaları üretme.
- İş sonunda kendi test/build işlemlerinin ürettiği, artık gerekmeyen APK, IPA, archive, geçici dosya, log ve cache'leri temizle. Yalnız bu işte oluştuğunu veya güvenle yeniden üretilebildiğini doğruladığın dosyaları hedefle.
- Uygulamanın yeniden çalıştırılmasını engelleyecek disk birikimi bırakma. Gerekirse proje build çıktısını temizle; kullanıcının sakladığı dağıtım dosyalarını, kaynakları, yapılandırmaları veya kimlik bilgilerini silme.
- Flutter iOS çıktısını temizlerken yalnız `build/` dizinini silip eski üretilmiş Xcode ayarlarını bırakma. Tam temizlik gerektiğinde `flutter clean` ve ardından `flutter pub get` kullan; son doğrulanmış run için gereken güncel çıktıları koru. Temizlik sonrası ilk derlemede `Runner.app` yolunun tekrar üretildiğini doğrula.
- Global Flutter/Gradle/CocoaPods önbelleklerini, Xcode DeviceSupport dizinlerini ve kullanıcıya ait emulator/cihaz verilerini topluca silme. Böyle bir temizlik gerçekten gerekirse kapsamı ve etkisini açıklayıp onay al.
- Başlattığın test/dev süreçlerini kapat. Son yanıtta cihaz doğrulamasının durumunu ve anlamlı bir temizlik yaptıysan kapsamını kısaca belirt.
