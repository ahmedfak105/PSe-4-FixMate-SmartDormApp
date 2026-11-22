import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language is shared by every FixMate role and persisted on device/browser.
/// Null follows the device locale (English or Lithuanian).
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit() : super(null) {
    _load();
  }

  static const _key = 'fixmate_locale';
  bool _changedManually = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (!_changedManually && !isClosed &&
          (saved == 'en' || saved == 'lt')) {
        emit(Locale(saved!));
      }
    } catch (_) {
      // Follow the device locale if persistence is unavailable.
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _changedManually = true;
    if (!isClosed) emit(locale);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else if (locale.languageCode == 'en' || locale.languageCode == 'lt') {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      // A storage failure should not prevent changing the visible language.
    }
  }
}
