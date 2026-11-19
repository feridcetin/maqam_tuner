import 'package:flutter/foundation.dart';

import 'strings.dart' as strs;

/// Current UI language. Listen to it to rebuild when the language changes.
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n i = L10n._();

  String _system = 'en';
  String _pref = 'system';
  String _code = 'en';

  String get code => _code;
  bool get rtl => _code == 'ar';

  /// Device language (called at start and when the device locale changes).
  void setSystemLanguage(String languageCode) {
    _system = strs.kLanguages.contains(languageCode) ? languageCode : 'en';
    _apply();
  }

  /// 'system', 'en', 'tr' or 'ar'.
  void setPreference(String pref) {
    _pref = pref;
    _apply();
  }

  void _apply() {
    final c = _pref == 'system'
        ? _system
        : (strs.kLanguages.contains(_pref) ? _pref : 'en');
    if (c != _code) {
      _code = c;
      notifyListeners();
    }
  }

  String t(String english) => strs.translate(_code, english);

  String fmt(String template, List<Object> args) =>
      strs.fmt(_code, template, args);
}
