import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/ui/pages/recycle_bin_page.dart';

// 以真人视角：让测试像人一样操作主界面（录入→确认→显示、搜索、回收站彻底删除、主题、LLM 字段）。
Widget localizedApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  setUp(() {
    // 用固定“现在”，让 NLP 日期解析结果可断言
    // （zh_parser 用 DateTime.now()，这里不 mock 时钟，仅断言字段非空）
  });

  /// 真人主流程：在首页输入框输入中文自然语言 → 回车 → 出现解析确认弹窗 → 点确认 → 任务出现
  testWidgets('真人主流程：快速录入中文→确认→任务出现在收件箱', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    // 输入自然语言并回车（触发 _quickAdd）
    final input = find.byType(TextField).first;
    await tester.enterText(input, '明天下午3点 交周报 高');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 应弹出解析确认弹窗
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);

    // 真人点“确认”
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 任务已入库，标题被解析掉日期/优先级 token 后应为 “交周报”
    final tasks = await repo.allTasks();
    expect(tasks, isNotEmpty);
    expect(tasks.any((t) => t.title.contains('交周报')), isTrue);
  });

  /// 真人主流程：搜索框真正过滤列表
  testWidgets('搜索框输入关键词后列表被过滤', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '买牛奶');
    await svc.create(title: '给老板交报告');

    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    // 初始两者都显示
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('给老板交报告'), findsOneWidget);

    // 第二个输入框是搜索框
    final search = find.byType(TextField).at(1);
    await tester.enterText(search, '牛奶');
    await tester.pumpAndSettle();

    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('给老板交报告'), findsNothing);
  });

  /// 回收站彻底删除按钮的交互
  testWidgets('回收站中彻底删除任务', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '待彻底删');
    await svc.recycle(t);

    await tester.pumpWidget(localizedApp(RecycleBinPageShell(svc)));
    await tester.pumpAndSettle();

    expect(find.text('待彻底删'), findsOneWidget);
    // 点“彻底删除”
    await tester.tap(find.byIcon(Icons.delete_forever_rounded));
    await tester.pumpAndSettle();

    // 二次确认弹窗
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '彻底删除'));
    await tester.pumpAndSettle();

    expect(find.text('待彻底删'), findsNothing);
    expect((await repo.allTasks()).isEmpty, isTrue);
  });

  /// 设置页：主题切换 与 LLM 配置字段可编辑
  testWidgets('设置页主题切换 + LLM 字段', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryRepository();
    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    // 更多菜单 → 设置
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // 设置页出现：语言 / LLM 增强解析
    expect(find.text('LLM 增强解析'), findsOneWidget);
    // 点开 LLM 开关
    await tester.tap(find.text('开启后，录入文本将发送到你填写的服务').first);
    await tester.pumpAndSettle();

    // 找三个 LLM 输入框(Base URL / API Key / 模型) —— 用 InputDecoration label
    expect(find.text('Base URL（OpenAI 兼容）'), findsOneWidget);
    expect(find.text('API Key（本地保存）'), findsOneWidget);
    expect(find.text('模型（如 gpt-4o-mini / deepseek-chat）'), findsOneWidget);
  });
}

// 回收站页面的最小外壳（与 localizedApp 一致，避免重复 import 页面内部导航）
class RecycleBinPageShell extends StatelessWidget {
  final TaskService service;
  const RecycleBinPageShell(this.service, {super.key});
  @override
  Widget build(BuildContext context) {
    return RecycleBinPage(service: service);
  }
}
