import 'package:flutter_test/flutter_test.dart';
import 'package:saoshuhui/core/window_size.dart';

void main() {
  test('Material 3 断点：<600 compact / 600–1024 medium（含 1024）/ >1024 expanded', () {
    expect(WindowSize.fromWidth(390), WindowSizeClass.compact);
    expect(WindowSize.fromWidth(599.9), WindowSizeClass.compact);
    expect(WindowSize.fromWidth(600), WindowSizeClass.medium);
    expect(WindowSize.fromWidth(840), WindowSizeClass.medium);
    expect(WindowSize.fromWidth(1023.9), WindowSizeClass.medium);
    // QA ISSUE-1：1024dp（iPad 横屏逻辑宽）归 medium，设计系统 v1.4 §9.1 边界裁决。
    expect(WindowSize.fromWidth(1024), WindowSizeClass.medium);
    expect(WindowSize.fromWidth(1024.1), WindowSizeClass.expanded);
    expect(WindowSize.fromWidth(1920), WindowSizeClass.expanded);
  });

  test('阅读列最大宽度 token = 720dp', () {
    expect(WindowSize.maxContentWidth, 720);
  });
}
