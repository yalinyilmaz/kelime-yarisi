import '../../room/domain/entities/room_game_mode.dart';
import '../domain/game_question.dart';

abstract final class QuestionBank {
  static String setIdFor(RoomGameMode mode) => '${mode.name}-v1';

  static List<GameQuestion> forSet(String? id) => switch (id) {
    'classic-v1' => _classic,
    'quick-v1' => List.unmodifiable([
      for (var i = 0; i < _classic.length; i += 2) _classic[i],
    ]),
    _ => throw StateError(
      'Bu soru seti desteklenmiyor. Uygulamayı güncelleyin.',
    ),
  };

  static const _classic = [
    GameQuestion(
      clue: 'Bir odaya girerken açıp çıkarken kapattığımız geçit.',
      answer: 'KAPI',
      hints: [
        "Koluna basıp içeri geçeriz.",
        "Kilit takılarak bir mekâna girişi sınırlayabilir.",
      ],
    ),
    GameQuestion(
      clue: 'Zamanı, akrep ve yelkovanla gösteren araç.',
      answer: 'SAAT',
      hints: [
        "Duvara asılan veya bileğe takılan türleri vardır.",
        "Kadranında dakikaları ve zamanı izleriz.",
      ],
    ),
    GameQuestion(
      clue: 'Sayfaları bir araya getirilmiş, okunan basılı eser.',
      answer: 'KİTAP',
      hints: [
        "Sayfaları okumak için kapakları açarsın.",
        "Basılı veya elektronik biçimde yayımlanabilir.",
      ],
    ),
    GameQuestion(
      clue: 'Okyanustan küçük, tuzlu ve geniş su kütlesi.',
      answer: 'DENİZ',
      hints: [
        "Kıyı, koy ve körfezleri bulunabilir.",
        "Geniş bir tuzlu su alanında yüzdüğünü düşün.",
      ],
    ),
    GameQuestion(
      clue: 'Su veya çay içmek için kullanılan kap.',
      answer: 'BARDAK',
      hints: [
        "Sıvıyı içebilmek için dudağa yaklaştırılır.",
        "Çay veya su koyulan günlük bir kaptır.",
      ],
    ),
    GameQuestion(
      clue: 'Bitkilerin kök saldığı, yeryüzünün üst tabakası.',
      answer: 'TOPRAK',
      hints: [
        "Kayaların ayrışması ve canlı kalıntılarıyla oluşur.",
        "Bitkinin su ve besin aldığı doğal ortamdır.",
      ],
    ),
    GameQuestion(
      clue: 'Kilidi açmak için kullanılan küçük metal araç.',
      answer: 'ANAHTAR',
      hints: [
        "Kilide uygun dişleri veya özel biçimi olabilir.",
        "Doğru olanı takıp çevirmek kapıyı açabilir.",
      ],
    ),
    GameQuestion(
      clue: 'Toprak altında yetişen, kızartması yapılan yumru sebze.',
      answer: 'PATATES',
      hints: [
        "Yenilen kısmı kök değil, yumrulaşmış gövdedir.",
        "Haşlanıp ezilerek püre yapılabilir.",
      ],
    ),
    GameQuestion(
      clue: 'Basamakları kullanarak yukarı çıkmayı sağlayan yapı.',
      answer: 'MERDİVEN',
      hints: [
        "Asansör çalışmayınca üst kata bununla çıkılabilir.",
        "Her adımda bir üst basamağa geçersin.",
      ],
    ),
    GameQuestion(
      clue: 'Ayçiçeğinden elde edilen, kabuğu çıtlatılarak yenen atıştırmalık.',
      answer: 'ÇEKİRDEK',
      hints: [
        "Ayçiçeğinin içinde gelişen yenilebilir tohumdur.",
        "Yemeden önce dışındaki sert kabuk ayıklanır.",
      ],
    ),
    GameQuestion(
      clue: 'Yağmurdan sonra gökyüzünde oluşabilen renkli yay.',
      answer: 'GÖKKUŞAĞI',
      hints: [
        "Görülürken güneş genellikle gözlemcinin arkasındadır.",
        "Farklı renkler gökyüzünde yan yana bir kemer oluşturur.",
      ],
    ),
    GameQuestion(
      clue: 'Bir yerde toplanmış çok sayıda insan.',
      answer: 'KALABALIK',
      hints: [
        "Konser çıkışında aynı yere yığılan insanlar bunu oluşturabilir.",
        "Bir mekânın tenha olmasının karşıtını düşündürür.",
      ],
    ),
    GameQuestion(
      clue: 'Verileri işleyen, ekran ve klavyeyle kullanılan elektronik cihaz.',
      answer: 'BİLGİSAYAR',
      hints: [
        "Yazılım olmadan kendisine verilen işleri yapamaz.",
        "Bellek ve işlemci gibi bileşenleri vardır.",
      ],
    ),
    GameQuestion(
      clue: 'Görüntülü yayınları evde izlemeyi sağlayan cihaz.',
      answer: 'TELEVİZYON',
      hints: [
        "Yayınları bir ekran ve ses çıkışıyla sunar.",
        "Kumandayla kanal seçilebilen ev aletini düşündürür.",
      ],
    ),
  ];
}
