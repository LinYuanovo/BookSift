import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/fonts/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ProviderContainer container = ProviderContainer();
  // 启动加载用户导入字体（v1.4 §2.2）：失败自动降级 system，不阻塞启动；
  // 默认配置（零导入）不产生任何字体文件加载。
  await container.read(fontServiceProvider).bootstrap();
  runApp(UncontrolledProviderScope(container: container, child: const BookSiftApp()));
}
