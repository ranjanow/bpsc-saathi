import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Manages the active [AppThemeMode] and persists the user's choice.
///
/// Wrap the app root with this provider via [ListenableBuilder] or
/// [AnimatedBuilder] to react to theme changes.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'bpsc_theme_mode';

  AppThemeMode _mode = AppThemeMode.vibrant;
  AppThemeMode get mode => _mode;

  BpscThemeData get bpscTheme => BpscThemeData.fromMode(_mode);
  ThemeData get materialTheme => AppTheme.fromBpsc(bpscTheme);

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// Switch to a new theme and persist.
  void setTheme(AppThemeMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    _saveToPrefs();
  }

  /// Cycle through themes: Vibrant → Professional → Dark → Vibrant…
  void cycleTheme() {
    final values = AppThemeMode.values;
    final nextIndex = (_mode.index + 1) % values.length;
    setTheme(values[nextIndex]);
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final match = AppThemeMode.values.where((m) => m.name == saved);
      if (match.isNotEmpty) {
        _mode = match.first;
        notifyListeners();
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _mode.name);
  }
}
