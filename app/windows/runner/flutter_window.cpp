#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// 自绘标题栏几何（**逻辑 px**，命中测试时按窗口 DPI 换算成物理 px）。
// 必须与 Dart 侧 core/window/window_frame.dart 的 WindowFrameMetrics 一致，
// 不一致的症状 = 拖动区/按钮点击区与画面错位。
constexpr int kTitleBarLogicalHeight = 36;
constexpr int kCaptionButtonLogicalWidth = 46;
// 右侧按钮簇总宽：最小化 / 最大化 / 关闭。
constexpr int kCaptionButtonsLogicalWidth = kCaptionButtonLogicalWidth * 3;
// 四边缩放命中宽度（去系统边框后自己算，取系统细边框档）。
constexpr int kResizeBorderLogicalWidth = 6;

// Windows 11 圆角偏好（旧 SDK / 旧系统上 DwmSetWindowAttribute 直接失败，忽略即可）。
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

// 逻辑 px → 物理 px。
//
// DPI 一律取 **Flutter 视图子窗口** 的口径（FlutterDesktopGetDpiForHWND）：embedder 就是用它
// 算 DPR 的（见 flutter_windows.h:311-319），只有同源才能保证本文件里的几何与 Dart 侧
// 按 DPR 画出来的标题栏/按钮逐像素对齐。
int ScaleForWindow(HWND window, int logical) {
  const UINT dpi = FlutterDesktopGetDpiForHWND(window);
  const double scale = dpi == 0 ? 1.0 : static_cast<double>(dpi) / 96.0;
  return static_cast<int>(logical * scale + 0.5);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  SetupWindowChannel();

  // Win11：圆角交给 DWM（去系统标题栏后仍要圆角窗口）。
  const int corner_preference = DWMWCP_ROUND;
  DwmSetWindowAttribute(GetHandle(), DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (window_channel_) {
    window_channel_->SetMethodCallHandler(nullptr);
    window_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetupWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "booksift/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND window = GetHandle();
        const std::string& method = call.method_name();
        if (method == "minimize") {
          ShowWindow(window, SW_MINIMIZE);
          result->Success();
        } else if (method == "toggleMaximize") {
          ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
        } else if (method == "close") {
          PostMessage(window, WM_CLOSE, 0, 0);
          result->Success();
        } else if (method == "isMaximized") {
          result->Success(flutter::EncodableValue(IsZoomed(window) != 0));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::NotifyMaximizedChanged() {
  if (!window_channel_) {
    return;
  }
  window_channel_->InvokeMethod(
      "maximizedChanged",
      std::make_unique<flutter::EncodableValue>(IsZoomed(GetHandle()) != 0));
}

LRESULT FlutterWindow::HitTestNcArea(HWND window, LPARAM lparam) const {
  // WM_NCHITTEST 的坐标是**屏幕坐标**。
  const POINT screen_point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  RECT window_rect{};
  if (!GetWindowRect(window, &window_rect)) {
    return HTCLIENT;
  }
  // 缩放基准取 Flutter 视图窗口（与 embedder 的 DPR 同源，子窗口还没建时退回顶层窗口）。
  HWND scale_window = window;
  if (const HWND view = GetWindow(window, GW_CHILD)) {
    scale_window = view;
  }

  const int resize_border = ScaleForWindow(scale_window, kResizeBorderLogicalWidth);
  if (!IsZoomed(window)) {
    const bool on_left = screen_point.x < window_rect.left + resize_border;
    const bool on_right = screen_point.x >= window_rect.right - resize_border;
    const bool on_top = screen_point.y < window_rect.top + resize_border;
    const bool on_bottom = screen_point.y >= window_rect.bottom - resize_border;
    if (on_top && on_left) {
      return HTTOPLEFT;
    }
    if (on_top && on_right) {
      return HTTOPRIGHT;
    }
    if (on_bottom && on_left) {
      return HTBOTTOMLEFT;
    }
    if (on_bottom && on_right) {
      return HTBOTTOMRIGHT;
    }
    if (on_left) {
      return HTLEFT;
    }
    if (on_right) {
      return HTRIGHT;
    }
    if (on_top) {
      return HTTOP;
    }
    if (on_bottom) {
      return HTBOTTOM;
    }
  }

  // 顶部条 = Flutter 自绘标题栏：右侧按钮簇留给 Dart（HTCLIENT，点按/悬停都在
  // Flutter 侧），其余是拖动区（HTCAPTION → 系统负责拖动/双击最大化/右键系统菜单）。
  const int title_bar_height = ScaleForWindow(scale_window, kTitleBarLogicalHeight);
  const int buttons_width = ScaleForWindow(scale_window, kCaptionButtonsLogicalWidth);
  if (screen_point.y < window_rect.top + title_bar_height &&
      screen_point.x < window_rect.right - buttons_width) {
    return HTCAPTION;
  }
  return HTCLIENT;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // 自绘标题栏骨架：WM_NCCALCSIZE 归零非客户区（保留 WS_OVERLAPPEDWINDOW 样式 →
  // DWM 阴影/圆角/贴边行为不变），WM_NCHITTEST 用上面的几何自己判。
  // 这两条必须抢在 Flutter 引擎之前处理（引擎不认这套 NC 规则）。
  switch (message) {
    case WM_NCCALCSIZE: {
      // 客户区 = 整窗：**必须显式把矩形写回去**——只 `return 0` 不改 rect 在本机仍会落到
      // 系统默认帧（实测窗口顶部残留一条原生标题栏，客户端原点 (17,40)）。
      // wParam==TRUE 时 lParam 是 NCCALCSIZE_PARAMS（rgrc[0]），FALSE 时就是 RECT*，
      // 两者同一块内存布局，都按屏幕坐标处理。
      RECT* client_rect = (wparam == TRUE)
                              ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam)->rgrc[0]
                              : reinterpret_cast<RECT*>(lparam);
      if (IsZoomed(hwnd)) {
        // 最大化时窗口矩形盖住整块显示器（含任务栏），按显示器工作区裁回。
        MONITORINFO monitor_info{};
        monitor_info.cbSize = sizeof(monitor_info);
        if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                           &monitor_info)) {
          *client_rect = monitor_info.rcWork;
        }
      } else {
        RECT window_rect{};
        if (GetWindowRect(hwnd, &window_rect)) {
          *client_rect = window_rect;
        }
      }
      return 0;
    }
    case WM_NCHITTEST:
      return HitTestNcArea(hwnd, lparam);
    case WM_SIZE:
      NotifyMaximizedChanged();
      break;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
