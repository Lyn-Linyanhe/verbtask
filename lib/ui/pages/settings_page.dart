import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/settings/settings_controller.dart';

class SettingsPage extends StatefulWidget {
  final SettingsController controller;
  final ValueChanged<Locale> onLocaleChanged;
  final File? backupFile;
  final VoidCallback? onQuickSync;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ThemeMode themeMode;
  const SettingsPage(
      {super.key,
      required this.controller,
      required this.onLocaleChanged,
      this.backupFile,
      this.onQuickSync,
      this.onThemeModeChanged,
      this.themeMode = ThemeMode.system});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _llmUrl;
  late final TextEditingController _llmKey;
  late final TextEditingController _syncMin;
  late final TextEditingController _notifyMin;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _llmUrl = TextEditingController(text: widget.controller.llmBaseUrl);
    _llmKey = TextEditingController(text: widget.controller.llmKey);
    _syncMin = TextEditingController(
        text: widget.controller.syncAutoIntervalMin.toString());
    _notifyMin = TextEditingController(
        text: widget.controller.notifyDefaultOffsetMin.abs().toString());
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _themeMode = widget.themeMode;
    }
  }

  @override
  void dispose() {
    _llmUrl.dispose();
    _llmKey.dispose();
    _syncMin.dispose();
    _notifyMin.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final f = widget.backupFile ?? File('verb_backup.json');
    final json = await widget.controller.exportTo(f);
    _snack(l.exportedCharacters(json.length));
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final f = widget.backupFile ?? File('verb_backup.json');
    if (!f.existsSync()) {
      _snack(l.backupFileMissing);
      return;
    }
    final n = await widget.controller.importFrom(f);
    _snack(l.importedTasks(n));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Section(
            title: l.language,
            child: DropdownButtonFormField<String>(
              initialValue: c.language,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.translate_rounded)),
              items: [
                DropdownMenuItem(value: 'zh', child: Text(l.languageChinese)),
                DropdownMenuItem(value: 'en', child: Text(l.languageEnglish))
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => c.language = v);
                widget.onLocaleChanged(Locale(v));
              },
            )),
        _Section(
            title: l.appearance,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l.themeSystem),
                    icon: Icon(Icons.brightness_auto_rounded, size: 16)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l.themeLight),
                    icon: Icon(Icons.light_mode_rounded, size: 16)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l.themeDark),
                    icon: Icon(Icons.dark_mode_rounded, size: 16)),
              ],
              selected: {_themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() => _themeMode = s.first);
                widget.controller.themeMode = _themeMode;
                if (widget.onThemeModeChanged != null) {
                  widget.onThemeModeChanged!(_themeMode);
                }
              },
            )),
        _Section(
            title: l.llmEnhancedParsing,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.llmSendTaskTextDescription),
                subtitle: Text(l.llmOfflineParsingDescription,
                    style: TextStyle(fontSize: 12)),
                value: c.llmEnabled == 1,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (v) => setState(() => c.llmEnabled = v ? 1 : 0),
              ),
              const SizedBox(height: 4),
              TextField(
                  controller: _llmUrl,
                  onChanged: (v) => c.llmBaseUrl = v,
                  decoration: InputDecoration(labelText: l.baseUrlLabel)),
              const SizedBox(height: 12),
              TextField(
                  controller: _llmKey,
                  onChanged: (v) => c.llmKey = v,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l.apiKeyLabel)),
            ])),
        _Section(
            title: l.syncAndReminders,
            child: Column(children: [
              _NumberField(
                  label: l.autoSyncIntervalMinutes,
                  controller: _syncMin,
                  onChanged: (v) =>
                      c.syncAutoIntervalMin = int.tryParse(v) ?? 30),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.useDefaultReminder),
                value: c.notifyDefaultReminderEnabled,
                onChanged: (v) =>
                    setState(() => c.notifyDefaultReminderEnabled = v),
              ),
              const SizedBox(height: 4),
              _NumberField(
                  label: l.defaultReminderAdvanceMinutes,
                  controller: _notifyMin,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed == null) return;
                    c.notifyDefaultOffsetMin = parsed == 0 ? 0 : -parsed.abs();
                  }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(l.exportBackup))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l.importBackup))),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: widget.onQuickSync ?? () {},
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(l.quickSync))),
            ])),
        _Section(
            title: l.windowsSystem,
            child: Column(children: [
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.keepInTray),
                  value: c.trayEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (v) => setState(() => c.trayEnabled = v)),
              const Divider(height: 1),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.launchAtStartup),
                  value: c.autostartEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (v) => setState(() => c.autostartEnabled = v)),
            ])),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            child,
          ]),
        )));
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _NumberField(
      {required this.label, required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label));
}
