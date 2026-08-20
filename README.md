# VerbTask

VerbTask 是一个个人使用的任务清单应用：Android 优先，同时支持 Windows。无账号、纯本地数据，中英双语，MIT 协议开源。

## 功能（v0.2）

- 快速录入：输入框支持中文自然语言解析（日期 / 时间 / 重复 / 优先级），解析结果先确认再保存
- 可选 LLM 增强解析：在设置中填写 OpenAI 兼容接口（base_url + API key，key 仅本地保存）；开启后发送任务文本前会明确提示，失败自动回退本地解析
- 清单（Lists）：创建、重命名、删除；删除清单时任务自动移回收件箱
- 视图：收件箱 / 今天 / 计划 / 清单 / 已完成 / 三列看板
- 完整编辑：标题、备注、状态、优先级、所属清单、截止日期（仅日期或日期+时刻）、提醒、重复规则（RRULE）
- 提醒：任务级提醒 + 全局默认提前量；创建、编辑、完成、恢复后自动重排通知
- 搜索 / 排序 / 筛选 / 回收站 / 中英一键切换 / 深浅色主题
- 备份导出：JSON 完整备份 + CSV 表格导出；导入带格式、版本与表头校验，失败不改动已有数据

## 数据与隐私

- 数据保存在本机应用数据目录（Windows 下为运行目录的 `data/`，文件为 `verb_data.json`）：没有账号，不上传云端
- 局域网同步（Windows 监听 + 手机前台/手动触发）属于 v0.3 路线，当前版本不把现有原型宣传为已完成的安全同步
- 只有开启 LLM 增强解析并逐次确认后，任务文本才会发送到你自填的 OpenAI 兼容接口

## 构建与安装

### Android

```bash
flutter build apk --debug
# 或
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/`，直接安装到手机即可。

### Windows

```bash
flutter build windows
```

产物在 `build/windows/x64/runner/Release/`，拷贝整个目录即可运行；后续可用 Inno Setup 或 MSIX 制作安装器。

## 开发

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

## 许可证

MIT，见 [LICENSE](LICENSE)。
