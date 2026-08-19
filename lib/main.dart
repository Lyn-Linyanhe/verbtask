import 'dart:io';
import 'package:flutter/material.dart';
import 'core/notifications/app_notifications.dart';
import 'core/storage/file_repository.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sep = Platform.pathSeparator;
  final repo = FileRepository(
      File('${Directory.current.path}${sep}data${sep}verb_data.json'));
  await AppNotifications.init(repo);
  runApp(VerbApp(repository: repo));
}
