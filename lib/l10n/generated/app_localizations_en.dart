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
  String get planned => 'Planned';

  @override
  String get board => 'Board';

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

  @override
  String get searchTasks => 'Search tasks';

  @override
  String get filter => 'Filter';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get sortByDue => 'Sort by due date';

  @override
  String get sortByCreated => 'Sort by created time';

  @override
  String get sortByTitle => 'Sort by title';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get manageLists => 'Manage lists';

  @override
  String get newList => 'New list';

  @override
  String get editList => 'Edit list';

  @override
  String get deleteList => 'Delete list';

  @override
  String get listName => 'List name';

  @override
  String get selectList => 'Select a list';

  @override
  String get noLists => 'No lists yet';

  @override
  String get deleteListConfirm => 'Tasks in this list will move to Inbox.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String parseTitle(Object value) {
    return 'Title: $value';
  }

  @override
  String parseDue(Object value) {
    return 'Due: $value';
  }

  @override
  String parseRepeat(Object value) {
    return 'Repeat: $value';
  }

  @override
  String parseList(Object value) {
    return 'List: $value';
  }

  @override
  String parseReminder(Object value) {
    return 'Reminder: $value';
  }

  @override
  String parsePriority(Object value) {
    return 'Priority: $value';
  }

  @override
  String parseSource(Object value) {
    return 'Parser: $value';
  }

  @override
  String get unrecognized => 'Unrecognized';

  @override
  String get none => 'None';

  @override
  String get recycleBin => 'Recycle bin';

  @override
  String get more => 'More';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get emptyInboxTitle => 'Inbox is empty';

  @override
  String get emptyInboxSubtitle => 'Capture something to do and finish it here';

  @override
  String get emptyDoneTitle => 'No completed tasks yet';

  @override
  String get emptyDoneSubtitle => 'Completed tasks will appear here';

  @override
  String get emptyListTitle => 'No list tasks yet';

  @override
  String get emptyListSubtitle => 'Organize tasks into lists';

  @override
  String get emptyTodayTitle => 'Nothing due today';

  @override
  String get emptyTodaySubtitle => 'Tasks due today will appear here';

  @override
  String get emptyPlannedTitle => 'No planned tasks yet';

  @override
  String get emptyPlannedSubtitle => 'Add a due date to see a task here';

  @override
  String get emptyBoardTitle => 'The board is empty';

  @override
  String get emptyBoardSubtitle => 'Tasks will be grouped by status here';

  @override
  String dateMonthDay(Object day, Object month) {
    return '$month/$day';
  }

  @override
  String get overdue => 'Overdue';

  @override
  String get today => 'Today';

  @override
  String get hasDueDate => 'Has due date';

  @override
  String get dueDate => 'Due date';

  @override
  String get dateOnly => 'Date only';

  @override
  String get dateAndTime => 'Date + time';

  @override
  String get setDueDate => 'Set due date';

  @override
  String get clearDueDate => 'Clear due date';

  @override
  String get reminder => 'Reminder';

  @override
  String get reminderEnabled => 'Remind me for this task';

  @override
  String get reminderAdvanceMinutes => 'Minutes in advance';

  @override
  String get noReminder => 'No reminder';

  @override
  String get priority => 'Priority';

  @override
  String get priorityNone => 'No priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get parseLocal => 'Offline local';

  @override
  String get parseLlm => 'LLM';

  @override
  String get editTask => 'Edit task';

  @override
  String get basicInformation => 'Basic information';

  @override
  String get titleField => 'Title';

  @override
  String get notesField => 'Notes';

  @override
  String get statusField => 'Status';

  @override
  String get scheduling => 'Scheduling';

  @override
  String get repeatRule => 'Repeat rule (RRULE)';

  @override
  String get repeatRuleHint => 'FREQ=DAILY';

  @override
  String get save => 'Save';

  @override
  String exportedCharacters(Object count) {
    return 'Exported $count characters';
  }

  @override
  String get backupFileMissing => 'Backup file not found';

  @override
  String importedTasks(Object count) {
    return 'Imported $count tasks';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get llmEnhancedParsing => 'LLM-enhanced parsing';

  @override
  String get llmSendTaskTextDescription =>
      'When enabled, task text is sent to the service you provide';

  @override
  String get llmOfflineParsingDescription =>
      'Off by default; offline parsing is always available';

  @override
  String get llmDataNoticeTitle =>
      'Task text will be sent to an external service';

  @override
  String get llmDataNoticeBody =>
      'LLM-enhanced parsing is enabled. After you confirm, the current text will be sent to the OpenAI-compatible endpoint you entered. VerbTask does not receive the data.';

  @override
  String get llmFallbackNotice =>
      'LLM unavailable; fell back to offline parsing';

  @override
  String get baseUrlLabel => 'Base URL (OpenAI-compatible)';

  @override
  String get apiKeyLabel => 'API key (stored locally)';

  @override
  String get modelLabel => 'Model (e.g. gpt-4o-mini / deepseek-chat)';

  @override
  String get syncAndReminders => 'Sync and reminders';

  @override
  String get autoSyncIntervalMinutes => 'Auto-sync interval (minutes)';

  @override
  String get useDefaultReminder => 'Use default reminder';

  @override
  String get defaultReminderAdvanceMinutes =>
      'Default reminder lead time (minutes)';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get importBackup => 'Import backup';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get csvExported => 'CSV backup exported';

  @override
  String get windowsSystem => 'Windows system';

  @override
  String get pairing => 'Sync pairing';

  @override
  String get syncTokenLabel => 'Sync token';

  @override
  String get serverTokenHint => 'Enter this token on your phone to pair';

  @override
  String get clientTokenHint => 'Paste the sync token from your Windows host';

  @override
  String get keepInTray => 'Keep in system tray';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get emptyRecycleBinTitle => 'Recycle bin is empty';

  @override
  String get emptyRecycleBinSubtitle =>
      'Deleted tasks appear here and can be restored';

  @override
  String get restore => 'Restore';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get alwaysOnTop => 'Always on top';

  @override
  String get quickNote => 'Quick note';

  @override
  String get quickNoteHint => 'Type a task, press Enter to save…';

  @override
  String get restoreWindow => 'Restore window';

  @override
  String get exitQuickNote => 'Exit quick note';
}
