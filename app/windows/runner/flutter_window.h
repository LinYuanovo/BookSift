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
// 非客户区高度归零（客户区铺满整窗）；缩放边框/顶部拖动区的命中几何由
// flutter_window.cpp 的 HitTestNonClient() 统一算（几何常量与 Dart 侧
// core/window/window_frame.dart 一一对应）。真实鼠标路径上光标落在铺满客户区的
// Flutter 视图子窗口上，所以该子窗口的 wndproc 包装（同文件的 ViewWndProc）会把
// 非客户区判成 HTTRANSPARENT 交回顶层窗口，拖动/缩放才走系统原生路径。
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

  /// 注册 `booksift/update` 通道：启动退出后替换更新助手。
  void SetupUpdateChannel();

  // 最大化态变化推给 Dart（WM_SIZE 后调用）。
  void NotifyMaximizedChanged();

  // 恢复上次关闭时的窗口矩形/最大化态（OnCreate 内调用，窗口仍隐藏）。
  void ApplySavedPlacement();

  // 关闭时落盘：普通态矩形 + 是否最大化（%LOCALAPPDATA%\BooksSift\window.ini）。
  void SavePlacement();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // 窗口控制通道（Dart → native 调用 + native → Dart 最大化态推送）。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  // 更新通道（桌面安装包替换）。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      update_channel_;

  // 首帧显示时是否直接最大化（= 上次关闭时的状态）。
  bool start_maximized_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
