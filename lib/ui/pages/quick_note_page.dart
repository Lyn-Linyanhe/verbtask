import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/window_control.dart';

/// 悬浮速记页：在小窗里快速连续记录任务，回车保存不清空、可继续输入。
/// 顶部把手可拖动窗口；右上角返回恢复正常窗口。
class QuickNotePage extends StatefulWidget {
  final Future<void> Function(String text) onAdd; // 保存回调（复用 HomePage._quickAdd）
  final bool restoreAlwaysOnTop; // 退出时是否恢复置顶
  const QuickNotePage({
    super.key,
    required this.onAdd,
    this.restoreAlwaysOnTop = false,
  });

  @override
  State<QuickNotePage> createState() => _QuickNotePageState();
}

class _QuickNotePageState extends State<QuickNotePage> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(String text) async {
    final v = text.trim();
    if (v.isEmpty) return;
    await widget.onAdd(v);
    if (!mounted) return;
    _input.clear(); // 连记：保存后清空继续输入
  }

  Future<void> _close() async {
    // 返回 HomePage（由调用方负责 exitMini 恢复窗口）
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 可拖动把手 + 标题 + 恢复按钮
            MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanStart: (_) => WindowControl.startDragging(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator, size: 18, color: scheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.quickNote,
                          style: TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: l.restoreWindow,
                        onPressed: _close,
                        icon: const Icon(Icons.fullscreen_exit_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: TextField(
                controller: _input,
                autofocus: true,
                maxLines: 1,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: _save,
                decoration: InputDecoration(
                  hintText: l.quickNoteHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

