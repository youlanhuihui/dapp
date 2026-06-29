import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleController extends ChangeNotifier {
  static const _storageKey = 'app_locale';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Locale _locale = const Locale('zh');

  LocaleController() {
    loadLocale();
  }

  Locale get locale => _locale;
  bool get isChinese => _locale.languageCode == 'zh';

  Future<void> loadLocale() async {
    final code = await _storage.read(key: _storageKey);
    if (code == 'zh' || code == 'en') {
      _locale = Locale(code!);
      notifyListeners();
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'zh' && languageCode != 'en') return;
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    await _storage.write(key: _storageKey, value: languageCode);
    notifyListeners();
  }
}
