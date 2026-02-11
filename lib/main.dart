// main.dart
import 'package:flutter/material.dart';
import 'logic.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logic = AppLogic();
  await logic.init();

  runApp(AppRoot(logic: logic));
}
