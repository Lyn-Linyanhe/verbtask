import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/settings/settings_controller.dart';

class SettingsPage extends StatefulWidget {
  final SettingsController controller;
  final ValueChanged<Locale> onLocaleChanged;
  final File? backupFile;
  final VoidCallback? onQuickSync;
  const SettingsPage({
    super.key,
    required this.controller,
    required this.onLocaleChanged,
    this.backupFile,
    this.onQuickSync,
  });

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
  void dispose() {
    _llmUrl.dispose(); _llmKey.dispose(); _syncMin.dispose(); _notifyMin.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final f = widget.backupFile ?? File('verb_backup.json');
    final json = await widget.controller.exportTo(f);
    _snack('已导出 ${json.length} 字符 -> $f');
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
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            title: const Text('语言 / Language'),
            trailing: DropdownButton<String>(
              value: c.language,
              items: const [
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() { c.language = v; });
                widget.onLocaleChanged(Locale(v));
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('LLM 增强解析（开启后任务文本将发送到你填写的服务）'),
            value: c.llmEnabled == 1,
            onChanged: (v) => setState(() => c.llmEnabled = v ? 1 : 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              TextField(controller: _llmUrl, onChanged: (v) => c.llmBaseUrl = v, decoration: const InputDecoration(labelText: 'Base URL (OpenAI 兼容)')),
              TextField(controller: _llmKey, onChanged: (v) => c.llmKey = v, obscureText: true, decoration: const InputDecoration(labelText: 'API Key (存本地)')),
            ]),
          ),
          const Divider(),
          ListTile(
            title: const Text('自动同步频率（分钟）'),
            trailing: SizedBox(width: 80, child: TextField(controller: _syncMin, keyboardType: TextInputType.number, onChanged: (v) => c.syncAutoIntervalMin = int.tryParse(v) ?? 30)),
          ),
          ListTile(
            title: const Text('默认提醒提前（分钟）'),
            trailing: SizedBox(width: 80, child: TextField(controller: _notifyMin, keyboardType: TextInputType.number, onChanged: (v) => c.notifyDefaultOffsetMin = int.tryParse(v) ?? 30)),
          ),
          const Divider(),
          SwitchListTile(title: const Text('Windows 托盘常驻'), value: c.trayEnabled, onChanged: (v) => setState(() => c.trayEnabled = v)),
          SwitchListTile(title: const Text('开机自启'), value: c.autostartEnabled, onChanged: (v) => setState(() => c.autostartEnabled = v)),
          const Divider(),
          ListTile(
            title: const Text('备份 / 同步'),
            subtitle: const Text('导出 JSON / 导入恢复；快速同步立即执行'),
            isThreeLine: true,
          ),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _export, child: const Text('导出备份'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: _import, child: const Text('导入恢复'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: widget.onQuickSync ?? () {}, child: const Text('快速同步'))),
          ]),
        ],
      ),
    );
  }
}
