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

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String parseTitle(Object value) {
    return '标题：$value';
  }

  @override
  String parseDue(Object value) {
    return '截止：$value';
  }

  @override
  String parseRepeat(Object value) {
    return '重复：$value';
  }

  @override
  String get unrecognized => '未识别';

  @override
  String get none => '无';

  @override
  String get recycleBin => '回收站';

  @override
  String get more => '更多';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get emptyInboxTitle => '收件箱是空的';

  @override
  String get emptyInboxSubtitle => '把要做的事记下来，随手完成';

  @override
  String get emptyDoneTitle => '还没有已完成的任务';

  @override
  String get emptyDoneSubtitle => '勾选任务即可在这里看到';

  @override
  String get emptyListTitle => '还没有清单任务';

  @override
  String get emptyListSubtitle => '把任务归入清单，分门别类';

  @override
  String dateMonthDay(Object day, Object month) {
    return '$month月$day日';
  }

  @override
  String get overdue => '已逾期';

  @override
  String get today => '今天';

  @override
  String get hasDueDate => '有期限';

  @override
  String get editTask => '编辑任务';

  @override
  String get basicInformation => '基本信息';

  @override
  String get titleField => '标题';

  @override
  String get notesField => '备注';

  @override
  String get statusField => '状态';

  @override
  String get scheduling => '安排';

  @override
  String get repeatRule => '重复规则 (RRULE)';

  @override
  String get repeatRuleHint => 'FREQ=DAILY';

  @override
  String get save => '保存';

  @override
  String exportedCharacters(Object count) {
    return '已导出 $count 字符';
  }

  @override
  String get backupFileMissing => '备份文件不存在';

  @override
  String importedTasks(Object count) {
    return '已导入 $count 条任务';
  }

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get llmEnhancedParsing => 'LLM 增强解析';

  @override
  String get llmSendTaskTextDescription => '开启后任务文本将发送到你填写的服务';

  @override
  String get llmOfflineParsingDescription => '默认关闭；本地离线解析始终可用';

  @override
  String get baseUrlLabel => 'Base URL（OpenAI 兼容）';

  @override
  String get apiKeyLabel => 'API Key（本地保存）';

  @override
  String get syncAndReminders => '同步与提醒';

  @override
  String get autoSyncIntervalMinutes => '自动同步间隔（分钟）';

  @override
  String get useDefaultReminder => '使用默认提醒';

  @override
  String get defaultReminderAdvanceMinutes => '默认提醒提前（分钟）';

  @override
  String get exportBackup => '导出备份';

  @override
  String get importBackup => '导入恢复';

  @override
  String get windowsSystem => 'Windows 系统';

  @override
  String get keepInTray => '托盘常驻';

  @override
  String get launchAtStartup => '开机自启';

  @override
  String get emptyRecycleBinTitle => '回收站是空的';

  @override
  String get emptyRecycleBinSubtitle => '删除的任务会在这里，可恢复';

  @override
  String get restore => '恢复';

  @override
  String get deletePermanently => '彻底删除';
}
