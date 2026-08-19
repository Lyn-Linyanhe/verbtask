import 'dart:io';
import 'package:flutter/material.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/theme/app_theme.dart';
import 'core/storage/file_repository.dart';
import 'core/storage/repository.dart';
import 'core/settings/local_settings.dart';
import 'core/settings/settings_controller.dart';
import 'ui/home_page.dart';

/// 应用根。可注入 [repository]（测试用内存版）；默认 JSON 文件持久化。
class VerbApp extends StatefulWidget {
  final TaskRepository? repository;
  final Locale? initialLocale;
  final SettingsController? settings;
  final VoidCallback? onQuickSync;
  const VerbApp({super.key, this.repository, this.initialLocale, this.settings, this.onQuickSync});

  @override
  State<VerbApp> createState() => _VerbAppState();
}

class _VerbAppState extends State<VerbApp> {
  late TaskRepository _repo;
  late SettingsController _settings;
  Locale _locale = const Locale('zh');

  @override
  void initState() {
    super.initState();
    final sep = Platform.pathSeparator;
    final dataDir = '${Directory.current.path}${sep}data';
    _repo = widget.repository ??
        FileRepository(File('$dataDir${sep}verb_data.json'));
    _settings = SettingsController(
      LocalSettings(File('$dataDir${sep}settings.json')),
      _repo,
    );
    if (widget.initialLocale != null) _locale = widget.initialLocale!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verb Task',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(),
      home: HomePage(
        repository: _repo,
        locale: _locale,
        onLocaleChanged: (l) => setState(() => _locale = l),
        settings: _settings,
        onQuickSync: widget.onQuickSync ?? () {},
      ),
    );
  }
}




