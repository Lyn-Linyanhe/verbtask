// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Reminder Notes';

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
  String get addTask => 'Capture a note…';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get quickSync => 'Quick Sync';

  @override
  String get search => 'Search';

  @override
  String get searchTasks => 'Search notes and reminders';

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
  String get searchNoResultSubtitle =>
      'Try a different keyword or clear the search';

  @override
  String get searchNoResultTitle => 'No matching items';

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
  String get deleteListConfirm => 'Items in this list will move to Inbox.';

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
  String get unrecognizedInput => 'No recordable item was recognized';

  @override
  String get reminderNeedsDue =>
      'No due date was set, so the reminder cannot be scheduled; this will be saved as a regular item';

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
  String get emptyInboxSubtitle =>
      'Capture something to remember and come back to it later';

  @override
  String get emptyInboxSubtitleHint =>
      'Try: remind me tomorrow at 3 PM to submit the weekly report';

  @override
  String get emptyDoneTitle => 'No completed items yet';

  @override
  String get emptyDoneSubtitle => 'Completed items will appear here';

  @override
  String get emptyListTitle => 'This list is empty';

  @override
  String get emptyListSubtitle => 'Group items here to find them later';

  @override
  String get emptyTodayTitle => 'Nothing scheduled today';

  @override
  String get emptyTodaySubtitle => 'Items due today will appear here';

  @override
  String get emptyPlannedTitle => 'No scheduled items yet';

  @override
  String get emptyPlannedSubtitle => 'Set a date to see an item here';

  @override
  String get emptyBoardTitle => 'The board is empty';

  @override
  String get emptyBoardSubtitle => 'Items will be grouped by status here';

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
  String get reminderEnabled => 'Remind me about this item';

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
  String get editTask => 'Edit item';

  @override
  String get basicInformation => 'Basic information';

  @override
  String get titleField => 'Title';

  @override
  String get titleRequired => 'A title is required';

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
  String get editRecurringTitle => 'Edit recurring item';

  @override
  String get editThisOccurrence => 'This occurrence only';

  @override
  String get editThisAndFuture => 'This and following';

  @override
  String get editWholeSeries => 'Entire series';

  @override
  String get recurringDueRequired =>
      'A recurring item needs a due date, or you can clear its repeat rule.';

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
    return 'Imported $count items';
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
      'When enabled, captured text is sent to the service you provide';

  @override
  String get llmOfflineParsingDescription =>
      'Off by default; offline parsing is always available';

  @override
  String get llmDataNoticeTitle =>
      'Captured text will be sent to an external service';

  @override
  String get llmDataNoticeBody =>
      'LLM-enhanced parsing is enabled. After you confirm, the current captured text will be sent to the OpenAI-compatible endpoint you entered. VerbTask does not receive the data.';

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
  String get fetchModels => 'Fetch models';

  @override
  String get fetchModelsFailed =>
      'Could not fetch models (endpoint may not support /models; enter manually)';

  @override
  String get noModels => 'No models returned by this endpoint';

  @override
  String get syncAndReminders => 'Sync and reminders';

  @override
  String get autoSyncIntervalMinutes => 'Auto-sync interval (minutes)';

  @override
  String get syncNotRun => 'Not synced yet';

  @override
  String get syncSucceeded => 'Last sync succeeded';

  @override
  String get syncFailed => 'Sync failed';

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
  String get autostartFailed =>
      'Could not change startup setting. Check Windows permissions.';

  @override
  String get emptyRecycleBinTitle => 'Recycle bin is empty';

  @override
  String get emptyRecycleBinSubtitle =>
      'Deleted items appear here and can be restored';

  @override
  String get restore => 'Restore';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get deletePermanentlyConfirmTitle => 'Delete permanently?';

  @override
  String get deletePermanentlyConfirmBody => 'This cannot be undone. Continue?';

  @override
  String get fillLlmConfigFirst =>
      'Fill in Base URL and API Key first, then fetch models.';

  @override
  String get alwaysOnTop => 'Always on top';

  @override
  String get quickNote => 'Floating note';

  @override
  String get quickNoteHint => 'Type a note or reminder, press Enter to save…';

  @override
  String get restoreWindow => 'Restore window';

  @override
  String remindBeforeMinutes(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get remindAtDue => 'at due time';

  @override
  String get exitQuickNote => 'Exit quick note';
}
