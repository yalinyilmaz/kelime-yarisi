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
3. **Oyun motoru:** Ortak 14 soru, dört dakikalık tur, kişisel harf alma, cevap doğrulama, puanlama ve canlı skor.
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

Step 2 tamamlandı. Android ve iOS uygulamaları `kelime-yarisi-yalin` Firebase projesine bağlıdır. Oyuncular anonim oturumla oda oluşturabilir veya oda koduyla katılabilir; oyuncu, bağlantı ve hazır bilgileri Realtime Database üzerinden tüm cihazlarda canlı güncellenir. Oda dolup herkes hazır olduğunda sunucu saatine bağlı ortak geri sayım başlar.

Sıradaki adım, ortak soru setini, dört dakikalık oyun sayacını, kişisel harf alma durumunu ve puanlamayı yönetecek oyun motorudur.
