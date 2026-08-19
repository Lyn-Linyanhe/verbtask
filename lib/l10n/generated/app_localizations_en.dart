// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Verb Task';

  @override
  String get inbox => 'Inbox';

  @override
  String get lists => 'Lists';

  @override
  String get todo => 'To Do';

  @override
  String get doing => 'In Progress';

  @override
  String get done => 'Done';

  @override
  String get addTask => 'Add a task…';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get quickSync => 'Quick Sync';

  @override
  String get search => 'Search';
}
