# Dev release

Proje kökünden:

```sh
./scripts/release android dev
./scripts/release ios dev
./scripts/release all dev
```

Hedefler: **Play Console → Dahili test**, **TestFlight**. `prod` engellenir. Firebase deploy veya App Store inceleme gönderimi yapılmaz. Apple'ın build işlemesi yüklemeden sonra sürebilir. TestFlight harici tester dağıtımı yapılmaz.

Terminalde altı adım görünür: `⏳ [1/6]` ön kontrol, `[2/6]` sürüm, `[3/6]` build, `[4/6]` mağaza upload, `[5/6]` Sentry, `[6/6]` temizlik. Her başarılı adım `✅`, başarısız adım nedeni ile `❌` yazar. Hata çıkış kodu sıfır değildir. `--build-only` mağaza/Sentry upload yapmadığını açıkça bildirir.

## İlk kurulum

Ruby 3.2+, Flutter, Android SDK/JDK; iOS için macOS/Xcode gerekir. `Gemfile.lock` Fastlane bağımlılıklarını sabitler.

```sh
bundle install
brew install getsentry/tools/sentry-cli
mkdir -p .local/credentials
test -f .local/release.dev.env || cp fastlane/release.dev.env.example .local/release.dev.env
chmod 700 .local/credentials
chmod 600 .local/release.dev.env
```

Gerçek değerleri **yalnız `.local/release.dev.env`** içine yaz. `$`, `#`, boşluk içeren parolaları tek tırnak içine al. Bu dosya shell ile `source` edilmez; yalnız izin verilen release alanları dotenv ile okunur. `.local/sentry.dev.json` yalnız `SENTRY_DSN` içermeli. Upload tokenı, `.p8`, keystore ve servis hesabı JSON'u Flutter paketine/dart-define'a girmez. Git/deploy dışında tutulur.

### Android upload anahtarı

İlk anahtar için aşağıdaki komut parolaları terminalde sorar. Mevcut anahtar varsa yenisini oluşturma.

```sh
test ! -e .local/credentials/dev-upload.jks && keytool -genkeypair -v \
  -keystore .local/credentials/dev-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
chmod 600 .local/credentials/dev-upload.jks
```

Env dosyasına `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS=upload`, `ANDROID_KEY_PASSWORD` yaz. Keytool aynı parolayı kullandıysa iki parola aynıdır. Keystore ve parolaları güvenli, şifreli olarak yedekle. Script her release'te anahtar oluşturmaz. İmza yalnız **dev flavor** için kullanılır; debug/prod imzası değiştirilmez. [Flutter imzalama rehberi](https://docs.flutter.dev/deployment/android#sign-the-app).

### Play Console API

1. Google Cloud Console'da **Google Play Android Developer API**'yi etkinleştir.
2. **IAM & Admin → Service Accounts** üzerinden release için servis hesabı oluştur. Firebase admin yetkisi gerekmez.
3. Hesapta **Keys → Add key → Create new key → JSON** seç. Dosyayı `.local/credentials/play-dev.json` olarak sakla.
4. Play Console **Users and permissions** bölümünde bu hesabın e-postasını davet et. Yalnız dev uygulamasına görüntüleme ve test kanalına release yetkisi ver; production release yetkisi gerekmez.
5. Env'de `PLAY_JSON_KEY_PATH=.local/credentials/play-dev.json` doldur.
6. İlk AAB için `./scripts/release android dev --build-only` çalıştır. Çıktıda belirtilen dosyayı dev uygulamasında **Testing → Internal testing → Create new release** alanına elle yükle. Play App Signing ve gerekli uygulama bilgilerini tamamla. Bundan sonra normal komut yeni build'i API ile yükler. [Fastlane ilk upload ve API kurulumu](https://docs.fastlane.tools/actions/upload_to_play_store/).
7. **App integrity → App signing** bölümündeki **app signing certificate SHA-256** değerinin dev Firebase Android uygulamasında kayıtlı olduğunu kontrol et. App Check / Play Integrity ayarını doğrula. Upload anahtarı ile mağazanın dağıtım imzası farklı olabilir. Son testi Play üzerinden kurarak yap. [Play App Signing](https://developer.android.com/studio/publish/app-signing#app-signing-google-play).

### Apple / TestFlight

1. App Store Connect dev uygulamasının Bundle ID'si `com.yalinyilmaz.kelimeYarisi.dev` olmalı. Developer Portal'daki App ID tek başına TestFlight kaydı oluşturmaz.
2. **Users and Access → Integrations → App Store Connect API → Team Keys** alanında gerekirse API erişimini iste. **App Manager** rolüyle API key oluştur, `.p8` dosyasını indir. Yalnız bir kez indirilebilir.
3. Dosyayı `.local/credentials/AuthKey_dev.p8` konumuna koy. Env'de `ASC_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID` doldur. Apple ID parolasını yazma.
4. Developer hesabının **Membership details → Team ID** değerini `APPLE_TEAM_ID` alanına koy. Team ID ile Issuer ID farklıdır.
5. Xcode **Settings → Accounts** içinde ücretli takıma giriş yap. **Manage Certificates → + → Apple Distribution** ile bu Mac'te sertifikayı özel anahtarıyla oluştur/kur. Varsa yeniden oluşturma.
6. `ios/Runner.xcworkspace` aç; dev uygulamasının ücretli takımını, automatic signing ve **App Attest** yetkisini kontrol et. Script `dev` / `Release-dev` kullanır; env Team ID'sini yalnız build komutuna verir. Proje/prod takım ayarını değiştirmez.
7. Apple sözleşmelerini kabul et. TestFlight iç test grubunu ve otomatik dağıtımını ayarla. Export compliance sorusu çıkarsa kullanılan şifreleme için Console'da doğru cevabı ver; script bunu varsaymaz.

Kaynaklar: [Apple API key](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api), [Fastlane TestFlight](https://docs.fastlane.tools/actions/upload_to_testflight/), [automatic provisioning](https://docs.fastlane.tools/codesigning/xcode-project/).

### Sentry

1. **User Settings → Personal Tokens** içinde `org:read` ve `project:releases` yetkili token oluştur. Kuruluş organization/build tokenı sunuyorsa release/symbol upload yetkili eşdeğeri kullanılabilir.
2. Env'de `SENTRY_AUTH_TOKEN` alanına koy. DSN tokenın yerine geçmez.
3. `SENTRY_ORG` kuruluş slug'ını, `SENTRY_PROJECT` **Flutter istemcisinin** proje slug'ını yaz; Functions projesini seçme. Slug'lar proje ayarları URL'sinde görünür.

Sentry release adı platformun gerçek paket kimliğiyle `paket@X.Y.Z+N`, dist `N`, environment `dev` olur. Aynı değerler uygulamaya verilir. Android Dart/native ELF sembolleri ve R8 mapping; iOS Dart sembolleri ve archive dSYM'leri yüklenir. Android mapping UUID'si aynı build'in SDK ayarıyla eşleştirilir. Tam kaynak kodu yüklenmez. [Sentry semboller](https://docs.sentry.io/cli/dif/), [token yetkileri](https://docs.sentry.io/api/permissions/).

## Sürüm, kontrol ve yeniden deneme

```sh
./scripts/release all dev --check
./scripts/release all dev
./scripts/release all dev --version 0.2.0
./scripts/release android dev --build-only
./scripts/release all dev --resume
```

- `--check`: yerel dosya/alan/komut kontrolü. Sürüm artırmaz, build/upload yapmaz. Uzak izinleri veya imzalamayı doğrulamaz.
- Normal komut, ön kontrol ve `flutter pub get` sonrasında pubspec **build numarasını bir artırır**: `0.1.0+1 → 0.1.0+2`. Pazarlama sürümü yalnız `--version X.Y.Z` ile değişir; build yine artar. Geri sürüm engellenir. Güncellenen `pubspec.yaml` dosyasını commit et.
- `all` iki platforma aynı sürümü verir. Ayrı komutlar ayrı build numarası üretir. Kilit aynı checkout'taki eşzamanlı işlemleri engeller; farklı makinelerden aynı anda release üretme. Daha önce Console'a yüksek build yüklediysen pubspec build numarasını önce onunla eşitle.
- Hata sonrası sürüm geri alınmaz. Başarılı build için `--resume`, mevcut pubspec sürümünün kalan adımlarını tamamlar; tekrar derlemez. Önce pubspec'i değiştirme. `.local/releases/dev/X.Y.Z+N/<platform>/status.json` tamamlanan upload'ları atlar; paket SHA-256 ile doğrulanır. Sentry hatası mağaza upload'ını tekrar etmez.
- Build başarısızsa hatayı düzeltip normal komutla yeni build üret. `all` içinde yalnız bir platform başarısızsa onun hedefini kullanabilirsin. Sunucu kabul ettikten sonra bağlantı koparsa receipt yazılmamış olabilir; tekrar denemeden önce Console'da build numarasını kontrol et.
- Tam başarı sonrası yalnız o release'in özel IPA/AAB/archive/DerivedData/sembol kopyaları temizlenir; `status.json` kalır. Android build dizinindeki aynı AAB da hash eşleşirse silinir. Başarısız / `--build-only` çıktıları yeniden deneme/ilk upload için tutulur. İşi biten ilgili `.local/releases/dev/X.Y.Z+N/` dizinini kaldırabilirsin. Global cache, normal iOS build çıktısı ve kimlik bilgileri silinmez.
- Sentry sembol upload'ı gerçek crash testi değildir. Son doğrulama mağazadan kurulan release uygulamasında yapılır.

## Yerel doğrulama

```sh
ruby test/dev_release_test.rb
bundle exec fastlane lanes
bash -n scripts/release
```
