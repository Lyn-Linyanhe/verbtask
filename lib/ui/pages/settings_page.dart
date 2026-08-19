import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/settings/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final SettingsController controller;
  final ValueChanged<Locale> onLocaleChanged;
  final File? backupFile;
  final VoidCallback? onQuickSync;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const SettingsPage({super.key, required this.controller, required this.onLocaleChanged, this.backupFile, this.onQuickSync, this.onThemeModeChanged});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _llmUrl;
  late final TextEditingController _llmKey;
  late final TextEditingController _syncMin;
  late final TextEditingController _notifyMin;

  @override
  void initState() {
    super.initState();
    _llmUrl = TextEditingController(text: widget.controller.llmBaseUrl);
    _llmKey = TextEditingController(text: widget.controller.llmKey);
    _syncMin = TextEditingController(text: widget.controller.syncAutoIntervalMin.toString());
    _notifyMin = TextEditingController(text: widget.controller.notifyDefaultOffsetMin.toString());
  }

  @override
  void dispose() { _llmUrl.dispose(); _llmKey.dispose(); _syncMin.dispose(); _notifyMin.dispose(); super.dispose(); }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final f = widget.backupFile ?? File('verb_backup.json');
    final json = await widget.controller.exportTo(f);
    _snack('已导出 ${json.length} 字符');
  }

  Future<void> _import() async {
    final f = widget.backupFile ?? File('verb_backup.json');
    if (!f.existsSync()) { _snack('备份文件不存在'); return; }
    final n = await widget.controller.importFrom(f);
    _snack('已导入 $n 条任务');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Section(title: '语言', child: DropdownButtonFormField<String>(
          initialValue: c.language,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.translate_rounded)),
          items: const [DropdownMenuItem(value: 'zh', child: Text('中文')), DropdownMenuItem(value: 'en', child: Text('English'))],
          onChanged: (v) { if (v == null) return; setState(() => c.language = v); widget.onLocaleChanged(Locale(v)); },
        )),
        _Section(title: '外观', child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('跟随系统'), icon: Icon(Icons.brightness_auto_rounded, size: 16)),
            ButtonSegment(value: ThemeMode.light, label: Text('浅色'), icon: Icon(Icons.light_mode_rounded, size: 16)),
            ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(Icons.dark_mode_rounded, size: 16)),
          ],
          selected: {ThemeMode.system},
          showSelectedIcon: false,
          onSelectionChanged: (s) { if (widget.onThemeModeChanged != null) widget.onThemeModeChanged!(s.first); },
        )),
        _Section(title: 'LLM 增强解析', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('开启后任务文本将发送到你填写的服务'),
            subtitle: const Text('默认关闭；本地离线解析始终可用', style: TextStyle(fontSize: 12)),
            value: c.llmEnabled == 1,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => c.llmEnabled = v ? 1 : 0),
          ),
          const SizedBox(height: 4),
          TextField(controller: _llmUrl, onChanged: (v) => c.llmBaseUrl = v, decoration: const InputDecoration(labelText: 'Base URL（OpenAI 兼容）')),
          const SizedBox(height: 12),
          TextField(controller: _llmKey, onChanged: (v) => c.llmKey = v, obscureText: true, decoration: const InputDecoration(labelText: 'API Key（本地保存）')),
        ])),

        _Section(title: '同步与提醒', child: Column(children: [
          _NumberField(label: '自动同步间隔（分钟）', controller: _syncMin, onChanged: (v) => c.syncAutoIntervalMin = int.tryParse(v) ?? 30),
          const SizedBox(height: 12),
          _NumberField(label: '默认提醒提前（分钟）', controller: _notifyMin, onChanged: (v) => c.notifyDefaultOffsetMin = int.tryParse(v) ?? 30),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.upload_file_rounded), label: const Text('导出备份'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.download_rounded), label: const Text('导入恢复'))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: widget.onQuickSync ?? () {}, icon: const Icon(Icons.sync_rounded), label: const Text('快速同步'))),
        ])),

        _Section(title: 'Windows 系统', child: Column(children: [
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('托盘常驻'), value: c.trayEnabled, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => c.trayEnabled = v)),
          const Divider(height: 1),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('开机自启'), value: c.autostartEnabled, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => c.autostartEnabled = v)),
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
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted)),
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
  const _NumberField({required this.label, required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: TextInputType.number, onChanged: onChanged, decoration: InputDecoration(labelText: label));
}

