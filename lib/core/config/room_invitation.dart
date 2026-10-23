import 'package:flutter/services.dart';

/// Production has no invitation host until its domain and stores are ready.
abstract final class RoomInvitation {
  static const devBaseUrl = 'https://kelime-yarisi-yalin.web.app';
  static const prodBaseUrl = '';

  static String get baseUrl => appFlavor == 'prod' ? prodBaseUrl : devBaseUrl;

  static String? normalizeCode(String? value) {
    if (value == null ||
        !RegExp(r'^[a-zA-Z0-9]{3}-?[a-zA-Z0-9]{3}$').hasMatch(value)) {
      return null;
    }
    final code = value.replaceAll('-', '').toUpperCase();
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }

  static Uri? link(String code, {String? base}) {
    final normalized = normalizeCode(code);
    final host = base ?? baseUrl;
    if (normalized == null || host.isEmpty) return null;
    return Uri.parse(host).replace(path: '/invite/$normalized');
  }

  static String shareText(String code) {
    final url = link(code);
    return 'Kelime Yarışı odama katıl!\n'
        '${url == null ? '' : '$url\n'}'
        'Oda kodu: $code';
  }

  static String joinLocation(String code) =>
      Uri(path: '/invite/$code').toString();
}
