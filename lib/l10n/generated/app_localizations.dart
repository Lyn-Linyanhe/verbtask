import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Verb Task'**
  String get appTitle;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @todo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get todo;

  /// No description provided for @doing.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get doing;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add a task…'**
  String get addTask;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @quickSync.
  ///
  /// In en, this message translates to:
  /// **'Quick Sync'**
  String get quickSync;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get searchTasks;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @sortByDue.
  ///
  /// In en, this message translates to:
  /// **'Sort by due date'**
  String get sortByDue;

  /// No description provided for @sortByCreated.
  ///
  /// In en, this message translates to:
  /// **'Sort by created time'**
  String get sortByCreated;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by title'**
  String get sortByTitle;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @manageLists.
  ///
  /// In en, this message translates to:
  /// **'Manage lists'**
  String get manageLists;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get editList;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listName;

  /// No description provided for @selectList.
  ///
  /// In en, this message translates to:
  /// **'Select a list'**
  String get selectList;

  /// No description provided for @noLists.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get noLists;

  /// No description provided for @deleteListConfirm.
  ///
  /// In en, this message translates to:
  /// **'Tasks in this list will move to Inbox.'**
  String get deleteListConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @parseTitle.
  ///
  /// In en, this message translates to:
  /// **'Title: {value}'**
  String parseTitle(Object value);

  /// No description provided for @parseDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {value}'**
  String parseDue(Object value);

  /// No description provided for @parseRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat: {value}'**
  String parseRepeat(Object value);

  /// No description provided for @parseList.
  ///
  /// In en, this message translates to:
  /// **'List: {value}'**
  String parseList(Object value);

  /// No description provided for @parseReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {value}'**
  String parseReminder(Object value);

  /// No description provided for @parsePriority.
  ///
  /// In en, this message translates to:
  /// **'Priority: {value}'**
  String parsePriority(Object value);

  /// No description provided for @parseSource.
  ///
  /// In en, this message translates to:
  /// **'Parser: {value}'**
  String parseSource(Object value);

  /// No description provided for @unrecognized.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized'**
  String get unrecognized;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @recycleBin.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin'**
  String get recycleBin;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @emptyInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox is empty'**
  String get emptyInboxTitle;

  /// No description provided for @emptyInboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture something to do and finish it here'**
  String get emptyInboxSubtitle;

  /// No description provided for @emptyDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks yet'**
  String get emptyDoneTitle;

  /// No description provided for @emptyDoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks will appear here'**
  String get emptyDoneSubtitle;

  /// No description provided for @emptyListTitle.
  ///
  /// In en, this message translates to:
  /// **'No list tasks yet'**
  String get emptyListTitle;

  /// No description provided for @emptyListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize tasks into lists'**
  String get emptyListSubtitle;

  /// No description provided for @emptyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get emptyTodayTitle;

  /// No description provided for @emptyTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks due today will appear here'**
  String get emptyTodaySubtitle;

  /// No description provided for @emptyPlannedTitle.
  ///
  /// In en, this message translates to:
  /// **'No planned tasks yet'**
  String get emptyPlannedTitle;

  /// No description provided for @emptyPlannedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a due date to see a task here'**
  String get emptyPlannedSubtitle;

  /// No description provided for @emptyBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'The board is empty'**
  String get emptyBoardTitle;

  /// No description provided for @emptyBoardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks will be grouped by status here'**
  String get emptyBoardSubtitle;

  /// No description provided for @dateMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String dateMonthDay(Object day, Object month);

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @hasDueDate.
  ///
  /// In en, this message translates to:
  /// **'Has due date'**
  String get hasDueDate;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @dateOnly.
  ///
  /// In en, this message translates to:
  /// **'Date only'**
  String get dateOnly;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date + time'**
  String get dateAndTime;

  /// No description provided for @setDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set due date'**
  String get setDueDate;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Remind me for this task'**
  String get reminderEnabled;

  /// No description provided for @reminderAdvanceMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes in advance'**
  String get reminderAdvanceMinutes;

  /// No description provided for @noReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get noReminder;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'No priority'**
  String get priorityNone;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @parseLocal.
  ///
  /// In en, this message translates to:
  /// **'Offline local'**
  String get parseLocal;

  /// No description provided for @parseLlm.
  ///
  /// In en, this message translates to:
  /// **'LLM'**
  String get parseLlm;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get basicInformation;

  /// No description provided for @titleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleField;

  /// No description provided for @notesField.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesField;

  /// No description provided for @statusField.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusField;

  /// No description provided for @scheduling.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get scheduling;

  /// No description provided for @repeatRule.
  ///
  /// In en, this message translates to:
  /// **'Repeat rule (RRULE)'**
  String get repeatRule;

  /// No description provided for @repeatRuleHint.
  ///
  /// In en, this message translates to:
  /// **'FREQ=DAILY'**
  String get repeatRuleHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @exportedCharacters.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} characters'**
  String exportedCharacters(Object count);

  /// No description provided for @backupFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Backup file not found'**
  String get backupFileMissing;

  /// No description provided for @importedTasks.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} tasks'**
  String importedTasks(Object count);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @llmEnhancedParsing.
  ///
  /// In en, this message translates to:
  /// **'LLM-enhanced parsing'**
  String get llmEnhancedParsing;

  /// No description provided for @llmSendTaskTextDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, task text is sent to the service you provide'**
  String get llmSendTaskTextDescription;

  /// No description provided for @llmOfflineParsingDescription.
  ///
  /// In en, this message translates to:
  /// **'Off by default; offline parsing is always available'**
  String get llmOfflineParsingDescription;

  /// No description provided for @llmDataNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Task text will be sent to an external service'**
  String get llmDataNoticeTitle;

  /// No description provided for @llmDataNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'LLM-enhanced parsing is enabled. After you confirm, the current text will be sent to the OpenAI-compatible endpoint you entered. VerbTask does not receive the data.'**
  String get llmDataNoticeBody;

  /// No description provided for @llmFallbackNotice.
  ///
  /// In en, this message translates to:
  /// **'LLM unavailable; fell back to offline parsing'**
  String get llmFallbackNotice;

  /// No description provided for @baseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL (OpenAI-compatible)'**
  String get baseUrlLabel;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key (stored locally)'**
  String get apiKeyLabel;

  /// No description provided for @syncAndReminders.
  ///
  /// In en, this message translates to:
  /// **'Sync and reminders'**
  String get syncAndReminders;

  /// No description provided for @autoSyncIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync interval (minutes)'**
  String get autoSyncIntervalMinutes;

  /// No description provided for @useDefaultReminder.
  ///
  /// In en, this message translates to:
  /// **'Use default reminder'**
  String get useDefaultReminder;

  /// No description provided for @defaultReminderAdvanceMinutes.
  ///
  /// In en, this message translates to:
  /// **'Default reminder lead time (minutes)'**
  String get defaultReminderAdvanceMinutes;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importBackup;

  /// No description provided for @windowsSystem.
  ///
  /// In en, this message translates to:
  /// **'Windows system'**
  String get windowsSystem;

  /// No description provided for @keepInTray.
  ///
  /// In en, this message translates to:
  /// **'Keep in system tray'**
  String get keepInTray;

  /// No description provided for @launchAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartup;

  /// No description provided for @emptyRecycleBinTitle.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin is empty'**
  String get emptyRecycleBinTitle;

  /// No description provided for @emptyRecycleBinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted tasks appear here and can be restored'**
  String get emptyRecycleBinSubtitle;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
