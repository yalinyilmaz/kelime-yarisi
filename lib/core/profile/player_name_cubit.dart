import 'package:hydrated_bloc/hydrated_bloc.dart';

class PlayerNameCubit extends HydratedCubit<String?> {
  PlayerNameCubit({super.storage}) : super(null);

  static String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validate(String value) {
    final name = normalize(value);
    if (name.length < 2) return 'Oyuncu adın en az 2 karakter olmalı.';
    if (name.length > 24) return 'Oyuncu adın en fazla 24 karakter olabilir.';
    return null;
  }

  bool saveName(String value) {
    if (validate(value) != null || isClosed) return false;
    emit(normalize(value));
    return true;
  }

  @override
  String get storagePrefix => 'player_name_v1';

  @override
  String? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    return name is String && validate(name) == null ? normalize(name) : null;
  }

  @override
  Map<String, dynamic> toJson(String? state) => {'name': state};
}
