/// The app's name, first route and starting theme from app.yml. Pure Dart; core/config.dart checks the first
/// route against routes.yml.
library;

import '../../schemas/app/app_schema.dart';

class AppRulesError implements Exception {
  final String message;
  const AppRulesError(this.message);
  @override
  String toString() => 'app.yml: $message';
}

class AppEngine {
  /// The theme modes the app knows (Flutter's ThemeMode names).
  static const themeModes = {'light', 'dark', 'system'};

  final AppSchema rules;

  /// light | dark | system: what the app starts in.
  final String themeMode;

  /// [themeMode] replaces app.yml's starting theme (tests draw every screen in both).
  AppEngine(this.rules, {String? themeMode}) : themeMode = themeMode ?? rules.themeMode {
    if (rules.name.trim().isEmpty) throw const AppRulesError('name must not be empty');
    if (!rules.initialRoute.startsWith('/')) throw const AppRulesError('initial_route must start with "/"');
    if (!themeModes.contains(this.themeMode)) {
      throw AppRulesError('theme_mode must be one of ${themeModes.join(', ')}, got "${this.themeMode}"');
    }
  }

  /// The window and browser tab title.
  String get name => rules.name;

  /// Where the app opens.
  String get initialRoute => rules.initialRoute;
}
