// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '任务清单';

  @override
  String get inbox => '收件箱';

  @override
  String get lists => '清单';

  @override
  String get todo => '未开始';

  @override
  String get doing => '进行中';

  @override
  String get done => '已完成';

  @override
  String get addTask => '添加任务…';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get quickSync => '快速同步';

  @override
  String get search => '搜索';
}
