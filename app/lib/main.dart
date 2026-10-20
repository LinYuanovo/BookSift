import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/fonts/font_service.dart';
import 'core/window/window_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ProviderContainer container = ProviderContainer();
  // 启动加载用户导入字体（v1.4 §2.2）：失败自动降级 system，不阻塞启动；
  // 默认配置（零导入）不产生任何字体文件加载。
  await container.read(fontServiceProvider).bootstrap();
  // 自绘标题栏的最大化态回读/推送（非 Windows 静默 no-op；不阻塞启动）。
  unawaited(WindowFrame.bind());
  runApp(UncontrolledProviderScope(container: container, child: const BookSiftApp()));
}
