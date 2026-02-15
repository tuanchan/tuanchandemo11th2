// main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'logic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX: sqflite on desktop (Windows/macOS/Linux) needs FFI factory
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final logic = AppLogic();
  await logic.init();

  runApp(AppRoot(logic: logic));
}
