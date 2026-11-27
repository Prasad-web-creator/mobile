import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'theme_mode';
  int _version = 0;

  @override
  ThemeMode build() {
    final prefs = SharedPrefs.maybeInstance;
    if (prefs != null) return _storedMode(prefs.get(_themeKey));
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final version = ++_version;
    final activeRef = ref;
    try {
      final prefs = await SharedPrefs.getAsync();
      if (!activeRef.mounted || version != _version) return;
      state = _storedMode(prefs.get(_themeKey));
    } catch (e) {
      debugPrint('[ThemeNotifier] Error loading theme: $e');
    }
  }

  ThemeMode _storedMode(Object? value) => switch (value) {
    'system' => ThemeMode.system,
    true || 'dark' => ThemeMode.dark,
    _ => ThemeMode.light,
  };

  Future<void> selectTheme(ThemeMode mode) async {
    final version = ++_version;
    state = mode;
    try {
      final prefs = await SharedPrefs.getAsync();
      if (version == _version) await prefs.setString(_themeKey, mode.name);
    } catch (e) {
      debugPrint('[ThemeNotifier] Error saving theme: $e');
    }
  }
}
