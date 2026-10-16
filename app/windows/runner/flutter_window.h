#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that hosts a Flutter view on a self-drawn title bar frame.
//
// 自绘标题栏（用户口径：窗口顶部走 App 的 design token，而非系统原生标题栏）：
// 非客户区高度归零（客户区铺满整窗），拖动区/窗口按钮区的 WM_NCHITTEST 判定在
// 本类里手工算（几何常量与 Dart 侧 core/window/window_frame.dart 一一对应），
// 窗口控制（最小化/最大化/关闭/最大化态）走 `booksift/window` MethodChannel。
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // 注册 `booksift/window` 通道（最小化 / 最大化切换 / 关闭 / 最大化态）。
  void SetupWindowChannel();

  // 自绘标题栏的命中测试（WM_NCHITTEST：屏幕坐标 → HT* 码）。
  LRESULT HitTestNcArea(HWND window, LPARAM lparam) const;

  // 最大化态变化推给 Dart（WM_SIZE 后调用）。
  void NotifyMaximizedChanged();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // 窗口控制通道（Dart → native 调用 + native → Dart 最大化态推送）。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
