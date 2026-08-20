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
  String get planned => '计划';

  @override
  String get board => '看板';

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
  String get searchTasks => '搜索任务';

  @override
  String get filter => '筛选';

  @override
  String get allStatuses => '全部状态';

  @override
  String get sortByDue => '按截止时间';

  @override
  String get sortByCreated => '按创建时间';

  @override
  String get sortByTitle => '按标题';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get manageLists => '管理清单';

  @override
  String get newList => '新建清单';

  @override
  String get editList => '编辑清单';

  @override
  String get deleteList => '删除清单';

  @override
  String get listName => '清单名称';

  @override
  String get selectList => '选择清单';

  @override
  String get noLists => '还没有清单';

  @override
  String get deleteListConfirm => '删除清单后，其中的任务会移回收件箱。';

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
  String parseList(Object value) {
    return '清单：$value';
  }

  @override
  String parseReminder(Object value) {
    return '提醒：$value';
  }

  @override
  String parsePriority(Object value) {
    return '优先级：$value';
  }

  @override
  String parseSource(Object value) {
    return '解析方式：$value';
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
  String get emptyTodayTitle => '今天没有待办';

  @override
  String get emptyTodaySubtitle => '今天要做的任务会显示在这里';

  @override
  String get emptyPlannedTitle => '还没有计划任务';

  @override
  String get emptyPlannedSubtitle => '给任务设置截止日期后，它会出现在这里';

  @override
  String get emptyBoardTitle => '看板是空的';

  @override
  String get emptyBoardSubtitle => '任务状态会按列显示在这里';

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
  String get dueDate => '截止日期';

  @override
  String get dateOnly => '仅日期';

  @override
  String get dateAndTime => '日期 + 时刻';

  @override
  String get setDueDate => '设置截止日期';

  @override
  String get clearDueDate => '清除截止日期';

  @override
  String get reminder => '提醒';

  @override
  String get reminderEnabled => '为此任务提醒';

  @override
  String get reminderAdvanceMinutes => '提前分钟数';

  @override
  String get noReminder => '不提醒';

  @override
  String get priority => '优先级';

  @override
  String get priorityNone => '无优先级';

  @override
  String get priorityLow => '低';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityHigh => '高';

  @override
  String get parseLocal => '本地离线';

  @override
  String get parseLlm => 'LLM';

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
  String get llmDataNoticeTitle => '任务文本将发送到外部服务';

  @override
  String get llmDataNoticeBody =>
      '你已开启 LLM 增强解析。确认后，当前文本会发送到你填写的 OpenAI 兼容接口。数据不会发送到 VerbTask 自己的服务器。';

  @override
  String get llmFallbackNotice => 'LLM 不可用，已回退到本地解析';

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
  String get exportCsv => '导出 CSV';

  @override
  String get importCsv => '导入 CSV';

  @override
  String get csvExported => '已导出 CSV 备份';

  @override
  String get windowsSystem => 'Windows 系统';

  @override
  String get pairing => '同步配对';

  @override
  String get syncTokenLabel => '同步令牌';

  @override
  String get serverTokenHint => '把令牌输入到你的手机进行配对';

  @override
  String get clientTokenHint => '粘贴 Windows 主机的同步令牌';

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

  @override
  String get alwaysOnTop => '窗口置顶';

  @override
  String get quickNote => '悬浮速记';

  @override
  String get quickNoteHint => '输入任务，回车保存…';

  @override
  String get restoreWindow => '恢复正常窗口';

  @override
  String get exitQuickNote => '退出速记';
}
