import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const preferenceKey = 'preferred_language';
  bool _saving = false;
  int _revision = 0;

  int get revision => _revision;

  @override
  Locale build() => Locale(SharedPrefs.maybeInstance?.getString(preferenceKey) == 'ta' ? 'ta' : 'en');

  Future<void> restoreFromProfile(String? language, {int? requestedAtRevision}) async {
    if (_saving || (requestedAtRevision != null && requestedAtRevision != _revision)) return;
    if (language != 'en' && language != 'ta') return;
    if (state.languageCode == language) return;
    state = Locale(language!);
    await _persist(language);
  }

  Future<void> selectLanguage(String language, Future<void> Function() saveProfile) async {
    if (_saving || state.languageCode == language) return;
    final previous = state;
    _revision++;
    _saving = true;
    state = Locale(language);
    try {
      await saveProfile();
      await _persist(language);
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    } finally {
      _saving = false;
    }
  }

  Future<void> _persist(String language) async {
    try {
      final preferences = await SharedPrefs.getAsync();
      await preferences.setString(preferenceKey, language);
    } catch (error) {
      debugPrint('Could not store the application locale: $error');
    }
  }
}
