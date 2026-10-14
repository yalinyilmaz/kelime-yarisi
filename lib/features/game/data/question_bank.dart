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
    ),
    GameQuestion(
      clue: 'Zamanı, akrep ve yelkovanla gösteren araç.',
      answer: 'SAAT',
    ),
    GameQuestion(
      clue: 'Sayfaları bir araya getirilmiş, okunan basılı eser.',
      answer: 'KİTAP',
    ),
    GameQuestion(
      clue: 'Okyanustan küçük, tuzlu ve geniş su kütlesi.',
      answer: 'DENİZ',
    ),
    GameQuestion(
      clue: 'Su veya çay içmek için kullanılan kap.',
      answer: 'BARDAK',
    ),
    GameQuestion(
      clue: 'Bitkilerin kök saldığı, yeryüzünün üst tabakası.',
      answer: 'TOPRAK',
    ),
    GameQuestion(
      clue: 'Kilidi açmak için kullanılan küçük metal araç.',
      answer: 'ANAHTAR',
    ),
    GameQuestion(
      clue: 'Toprak altında yetişen, kızartması yapılan yumru sebze.',
      answer: 'PATATES',
    ),
    GameQuestion(
      clue: 'Basamakları kullanarak yukarı çıkmayı sağlayan yapı.',
      answer: 'MERDİVEN',
    ),
    GameQuestion(
      clue: 'Ayçiçeğinden elde edilen, kabuğu çıtlatılarak yenen atıştırmalık.',
      answer: 'ÇEKİRDEK',
    ),
    GameQuestion(
      clue: 'Yağmurdan sonra gökyüzünde oluşabilen renkli yay.',
      answer: 'GÖKKUŞAĞI',
    ),
    GameQuestion(
      clue: 'Bir yerde toplanmış çok sayıda insan.',
      answer: 'KALABALIK',
    ),
    GameQuestion(
      clue: 'Verileri işleyen, ekran ve klavyeyle kullanılan elektronik cihaz.',
      answer: 'BİLGİSAYAR',
    ),
    GameQuestion(
      clue: 'Görüntülü yayınları evde izlemeyi sağlayan cihaz.',
      answer: 'TELEVİZYON',
    ),
  ];
}
