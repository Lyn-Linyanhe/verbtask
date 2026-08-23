import 'dart:async';
import 'package:flutter/material.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/theme/app_theme.dart';
import 'core/storage/repository.dart';
import 'core/storage/inmemory_repository.dart';
import 'core/settings/local_settings.dart';
import 'core/settings/settings_controller.dart';
import 'ui/home_page.dart';
import 'app/navigation.dart';

/// Fires one best-effort sync after the app returns from the background.
/// A second resume while the previous sync is running is coalesced.
class AppLifecycleSyncObserver with WidgetsBindingObserver {
  final Future<void> Function()? onResumed;
  bool _wasBackgrounded = false;
  bool _running = false;

  AppLifecycleSyncObserver({this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      return;
    }
    if (state != AppLifecycleState.resumed ||
        !_wasBackgrounded ||
        _running ||
        onResumed == null) {
      return;
    }
    _wasBackgrounded = false;
    _running = true;
    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    try {
      await onResumed!.call();
    } catch (_) {
      // Sync status is recorded by the app-level callback; lifecycle hooks
      // must not surface an unhandled future to the platform runner.
    } finally {
      _running = false;
    }
  }
}

class VerbApp extends StatefulWidget {
  final TaskRepository? repository;
  final Locale? initialLocale;
  final SettingsController? settings;
  final Future<void> Function()? onQuickSync;
  const VerbApp(
      {super.key,
      this.repository,
      this.initialLocale,
      this.settings,
      this.onQuickSync});

  @override
  State<VerbApp> createState() => _VerbAppState();
}

class _VerbAppState extends State<VerbApp> {
  late TaskRepository _repo;
  late SettingsController _settings;
  Locale _locale = const Locale('zh');
  ThemeMode _themeMode = ThemeMode.system;
  late final AppLifecycleSyncObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    // main.dart supplies the persistent repository/settings in production.
    // The fallback is deliberately memory-only so embedding the widget on
    // Android cannot attempt to write relative to the process root.
    _repo = widget.repository ?? InMemoryRepository();
    _settings =
        widget.settings ?? SettingsController(LocalSettings.inMemory(), _repo);
    _themeMode = _settings.themeMode;
    final language = _settings.language == 'en' ? 'en' : 'zh';
    _locale = widget.initialLocale ?? Locale(language);
    _lifecycleObserver = AppLifecycleSyncObserver(
      onResumed: () async {
        await widget.onQuickSync?.call();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  void _changeLocale(Locale locale) {
    final language = locale.languageCode == 'en' ? 'en' : 'zh';
    setState(() => _locale = Locale(language));
    _settings.language = language;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerbTask',
      navigatorKey: appNavigatorKey,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      home: HomePage(
        repository: _repo,
        locale: _locale,
        onLocaleChanged: _changeLocale,
        settings: _settings,
        themeMode: _themeMode,
        onQuickSync: widget.onQuickSync,
        onThemeModeChanged: (m) => setState(() => _themeMode = m),
      ),
    );
  }
}
