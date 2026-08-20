# VerbTask Windows 安装器

本目录通过 [Inno Setup](https://jrsoftware.org/isinfo.php) 生成 Windows 安装包（`VerbTask-setup.exe`）。

## 先决条件

- 已在本机完成 `flutter build windows`（产物在 `build\windows\x64\runner\Release\`）
- 安装 Inno Setup 6（含 ISCC 命令行编译器）

## 编译

在仓库根目录执行：

```
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\verb_task.iss
```

产物输出到 `dist\VerbTask-setup.exe`。

## 可移植性说明

脚本内**全部使用相对路径**，均以本脚本所在目录（`installer/`）为基准解析，不依赖任何绝对路径。
因此任何人克隆本仓库后，只要满足先决条件即可直接编译，无需修改任何路径。

中文界面依赖仓库内自带的 `languages\ChineseSimplified.isl`（官方 Inno 发行版默认不含中文语言文件），
已随仓库提交，无需额外下载。
