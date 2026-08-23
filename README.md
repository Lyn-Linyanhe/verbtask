# VerbTask

VerbTask 是一个个人使用的提醒记事工具：Android 优先，同时支持 Windows。它用于随手记下要做的事、设置截止时间和提醒、之后回看完成状态；无账号、纯本地数据，中英双语，MIT 协议开源。它不定位为番茄钟、自习室或专注学习工具。

## 功能（v0.4+）

- **快速录入**：输入框支持中文自然语言解析（日期 / 时间 / 重复 / 优先级），解析结果先确认再保存
- **可选 LLM 增强解析**：设置内填写 OpenAI 兼容接口（Base URL + API Key + 模型，key 仅本地保存）；支持一键拉取 `/models` 可用模型列表；发送录入文本前会明确提示、逐次确认；失败自动回退本地解析
- **清单（Lists）**：创建、重命名、删除；删除清单时事项自动移回收件箱
- **视图**：收件箱 / 今天 / 计划 / 清单 / 已完成 / 三列看板
- **完整编辑**：标题、备注、状态、优先级、所属清单、截止日期（仅日期或日期+时刻）、提醒、重复规则（RRULE）
- **提醒**：事项级提醒 + 全局默认提前量；每条事项支持继承/开启/明确关闭；绝对时刻提醒；重复事项自动预排
- **搜索 / 排序 / 筛选 / 回收站 / 中英一键切换 / 深浅色主题**
- **备份**：JSON 完整备份 + CSV 表格导出；导入带格式、版本与表头校验，失败不改动已有数据
- **Windows 专属**：默认 900×600 紧凑窗口、窗口置顶、悬浮速记小窗、托盘常驻（可关）、开机自启（可关）、跟随系统代理（供 OpenAI 等服务）
- **局域网同步（v0.3）**：Windows 主机监听 + 手机快捷同步，配对令牌鉴权、LWW 冲突处理、同步游标、幂等推送、删除/清单墓碑

## 数据与隐私

- 数据保存在本机应用数据目录（Windows 下 `%APPDATA%\com.verbapp\VerbTask\verb\`，文件 `verb_data.json`）：无账号、不上传云端。旧版开发包使用的 `%APPDATA%\com.verbapp\verb_app\verb\` 会在启动时兼容迁移，原目录不会删除
- 局域网同步为本地局域网内点对点；同步令牌在配对时手动交换
- 只有开启 LLM 增强解析并逐次确认后，录入文本才会发送到你自填的 OpenAI 兼容接口
- 彻底删除会在本地保留不可见的同步墓碑，仅用于防止旧设备把任务复活；它不会出现在回收站

## 构建与安装

### Windows

直接下载 GitHub Releases 里的 `VerbTask-setup.exe` 安装即可（DLL 已齐全，无需额外配置）。

本地构建：

```bash
flutter build windows --release
# 产物在 build/windows/x64/runner/Release/
# 用 Inno Setup 制作安装器：
#   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\verb_task.iss
# 产物在 dist/VerbTask-setup.exe
```

### Android

```bash
flutter build apk --release
# 产物在 build/app/outputs/flutter-apk/
```

Release APK 必须使用未提交到仓库的签名配置。可以在 `android/key.properties` 中填写
`storeFile`、`storePassword`、`keyAlias`、`keyPassword`，或设置对应的
`VERBTASK_STORE_FILE`、`VERBTASK_STORE_PASSWORD`、`VERBTASK_KEY_ALIAS`、
`VERBTASK_KEY_PASSWORD` 环境变量。缺少配置时 release 构建会明确失败，不会静默使用 debug 签名。

## 开发

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

## 测试

详见 [docs/Windows-测试报告-2026-08-20.md](docs/Windows-测试报告-2026-08-20.md)（Windows 真人视角全量测试报告）。

## 许可证

MIT，见 [LICENSE](LICENSE)。
