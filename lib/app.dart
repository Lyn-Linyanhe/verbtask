import 'dart:io';
import 'package:flutter/material.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/storage/file_repository.dart';
import 'core/storage/repository.dart';
import 'ui/home_page.dart';

/// 应用根。可注入 [repository]（测试用内存版）；默认 JSON 文件持久化。
class VerbApp extends StatefulWidget {
  final TaskRepository? repository;
  final Locale? initialLocale;
  const VerbApp({super.key, this.repository, this.initialLocale});

  @override
  State<VerbApp> createState() => _VerbAppState();
}

class _VerbAppState extends State<VerbApp> {
  late TaskRepository _repo;
  Locale _locale = const Locale('zh');

  @override
  void initState() {
    super.initState();
    final sep = Platform.pathSeparator;
    _repo = widget.repository ??
        FileRepository(File('${Directory.current.path}${sep}data${sep}verb_data.json'));
    if (widget.initialLocale != null) _locale = widget.initialLocale!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verb Task',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HomePage(
        repository: _repo,
        locale: _locale,
        onLocaleChanged: (l) => setState(() => _locale = l),
      ),
    );
  }
}
