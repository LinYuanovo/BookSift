#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <cstdlib>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring QuoteArgument(const std::wstring& value) {
  std::wstring quoted = L"\"";
  for (wchar_t ch : value) {
    if (ch == L'"') {
      quoted += L'\\';
    }
    quoted += ch;
  }
  quoted += L'"';
  return quoted;
}

bool StartUpdateHelper(const std::string& archive, const std::string& bundle) {
  std::error_code error;
  std::vector<wchar_t> executable_path(32768);
  const DWORD length = GetModuleFileNameW(
      nullptr, executable_path.data(), static_cast<DWORD>(executable_path.size()));
  if (length == 0 || length >= executable_path.size()) {
    return false;
  }
  const std::filesystem::path executable =
      std::filesystem::path(std::wstring(executable_path.data(), length))
          .parent_path();
  const std::filesystem::path script = executable / L"data" / L"update" /
                                       L"booksift_updater.ps1";
  if (!std::filesystem::is_regular_file(script, error)) {
    return false;
  }
  const std::wstring command =
      L"powershell.exe -NoProfile -ExecutionPolicy Bypass -File " +
      QuoteArgument(script.wstring()) + L" -Archive " +
      QuoteArgument(std::filesystem::path(archive).wstring()) + L" -Bundle " +
      QuoteArgument(std::filesystem::path(bundle).wstring()) + L" -ExeName " +
      QuoteArgument(L"booksift.exe") + L" -AppPid " +
      std::to_wstring(GetCurrentProcessId());
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  const BOOL created = CreateProcessW(
      nullptr, const_cast<wchar_t*>(command.c_str()), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process);
  if (!created) {
    return false;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return true;
}

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

// ── 窗口位置/尺寸/最大化态记忆（用户口径：关闭时记住，下次启动恢复） ──────────
// 存放 `%LOCALAPPDATA%\BooksSift\window.ini`（机器本地状态，不随漫游同步；ASCII 路径，
// 无编码坑）。用 Win32 Profile API 读写纯数字键值：零依赖、无解析歧义。
constexpr const wchar_t kPlacementDirName[] = L"BooksSift";
constexpr const wchar_t kPlacementFileName[] = L"window.ini";
constexpr const wchar_t kPlacementSection[] = L"window";

std::wstring PlacementFilePath() {
  wchar_t base[MAX_PATH * 2]{};
  const DWORD len =
      GetEnvironmentVariableW(L"LOCALAPPDATA", base, ARRAYSIZE(base));
  if (len == 0 || len >= ARRAYSIZE(base)) {
    return L"";
  }
  std::wstring dir = base;
  dir += L"\\";
  dir += kPlacementDirName;
  CreateDirectoryW(dir.c_str(), nullptr);  // 已存在时返回 false，忽略
  return dir + L"\\" + kPlacementFileName;
}

bool ReadPlacementInt(const std::wstring& file, const wchar_t* key,
                      long* out) {
  wchar_t buf[32]{};
  if (GetPrivateProfileStringW(kPlacementSection, key, L"", buf,
                               ARRAYSIZE(buf), file.c_str()) == 0) {
    return false;
  }
  wchar_t* end = nullptr;
  const long value = wcstol(buf, &end, 10);
  if (end == buf) {
    return false;
  }
  *out = value;
  return true;
}

// 读取上次关闭时的普通态矩形与最大化标记。返回 false = 无记录/记录非法
// （调用方保持默认启动位置）。尺寸只做粗校验，是否仍落在可见显示器内由调用方判。
bool LoadWindowPlacement(RECT* rect, bool* maximized) {
  *maximized = false;
  const std::wstring file = PlacementFilePath();
  if (file.empty()) {
    return false;
  }
  long x = 0, y = 0, w = 0, h = 0;
  if (!ReadPlacementInt(file, L"x", &x) ||
      !ReadPlacementInt(file, L"y", &y) ||
      !ReadPlacementInt(file, L"w", &w) ||
      !ReadPlacementInt(file, L"h", &h)) {
    return false;
  }
  if (w < 400 || h < 400 || w > 20000 || h > 20000) {
    return false;
  }
  rect->left = static_cast<LONG>(x);
  rect->top = static_cast<LONG>(y);
  rect->right = static_cast<LONG>(x + w);
  rect->bottom = static_cast<LONG>(y + h);
  *maximized =
      GetPrivateProfileIntW(kPlacementSection, L"maximized", 0, file.c_str()) !=
      0;
  return true;
}

void SaveWindowPlacement(HWND window) {
  if (window == nullptr) {
    return;
  }
  const std::wstring file = PlacementFilePath();
  if (file.empty()) {
    return;
  }
  WINDOWPLACEMENT wp{};
  wp.length = sizeof(wp);
  if (!GetWindowPlacement(window, &wp)) {
    return;
  }
  // rcNormalPosition = 普通态（非最大化）窗口矩形；窗口当前最小化时它仍是还原矩形。
  const RECT& r = wp.rcNormalPosition;
  const auto write = [&file](const wchar_t* key, long value) {
    WritePrivateProfileStringW(kPlacementSection, key,
                               std::to_wstring(value).c_str(), file.c_str());
  };
  write(L"x", r.left);
  write(L"y", r.top);
  write(L"w", r.right - r.left);
  write(L"h", r.bottom - r.top);
  WritePrivateProfileStringW(kPlacementSection, L"maximized",
                             wp.showCmd == SW_SHOWMAXIMIZED ? L"1" : L"0",
                             file.c_str());
}

// ── 自绘标题栏命中测试（WM_NCHITTEST：屏幕坐标 → HT* 码） ─────────────────────
//   HTCLIENT            = Flutter 客户区（标题栏三颗按钮 / 正文 / 滚动条都归 Flutter）；
//   HTLEFT / … / HTCAPTION = 系统非客户区（四边四角缩放、顶部拖动区）。
//
// ⚠ 真实鼠标路径上系统只问**最底层**的那个窗口：Flutter 视图是铺满客户区的子窗口，
// 顶层窗口自己的 WM_NCHITTEST 收不到消息。所以本函数有两处调用方：
//   1) 顶层窗口的 WM_NCHITTEST（命中对象直接是顶层窗口时）；
//   2) 视图子窗口的 wndproc 包装 ViewWndProc —— 判成非客户区返回 HTTRANSPARENT，
//      系统会继续问同线程的父窗口，顶层再给出最终 HT* 码。
// 两边共用这一个几何函数，保证「判在哪」和「谁执行拖动/缩放」不会错位。
LRESULT HitTestNonClient(HWND window, LPARAM lparam) {
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

// Flutter 视图子窗口的 wndproc 包装：把「非客户区」命中交回顶层窗口。
//
// 背景（实测复现）：视图子窗口铺满客户区，系统做鼠标命中测试时只问子窗口，子窗口
// 默认回 HTCLIENT → 顶层那套 HTLEFT/HTCAPTION 判定永远不生效：拖四边四角不缩放
// （光标一直是箭头、真实拖拽窗口尺寸 dW=0），拖标题栏也不移动窗口。
// 判成非客户区时返回 HTTRANSPARENT（系统继续问同线程的底层窗口 = 顶层窗口 → 得到
// HTLEFT/HTCAPTION，随后拖动/缩放/双击最大化/右键系统菜单全走系统原生路径）；
// 判成客户区时原样 HTCLIENT，点击/悬停/滚动/IME 消息照旧进 Flutter。
WNDPROC g_view_previous_proc = nullptr;

LRESULT CALLBACK ViewWndProc(HWND view, UINT message, WPARAM wparam,
                             LPARAM lparam) {
  if (message == WM_NCHITTEST) {
    const HWND top_level = GetParent(view);
    const LRESULT code =
        top_level == nullptr ? HTCLIENT : HitTestNonClient(top_level, lparam);
    return code == HTCLIENT ? HTCLIENT : HTTRANSPARENT;
  }
  return CallWindowProcW(g_view_previous_proc, view, message, wparam, lparam);
}

void InstallViewHitTestForwarding(HWND view) {
  if (view == nullptr) {
    return;
  }
  if (reinterpret_cast<WNDPROC>(GetWindowLongPtrW(view, GWLP_WNDPROC)) ==
      &ViewWndProc) {
    return;  // 已装过（幂等）
  }
  const LONG_PTR previous = SetWindowLongPtrW(
      view, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&ViewWndProc));
  if (previous != 0) {
    g_view_previous_proc = reinterpret_cast<WNDPROC>(previous);
  }
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
  // 视图子窗口铺满客户区：给它装 WM_NCHITTEST 转发，否则顶层的缩放边框/拖动区
  // 判定收不到消息（明细见 ViewWndProc）。
  InstallViewHitTestForwarding(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (start_maximized_) {
      // 上次关闭时是最大化：首帧直接以最大化示人，避免 普通态 → 最大化 的闪跳。
      ::ShowWindow(GetHandle(), SW_SHOWMAXIMIZED);
    } else {
      this->Show();
    }
  });

  SetupWindowChannel();
  SetupUpdateChannel();

  // Win11：圆角交给 DWM（去系统标题栏后仍要圆角窗口）。
  const int corner_preference = DWMWCP_ROUND;
  DwmSetWindowAttribute(GetHandle(), DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  // 恢复上次关闭时的位置/尺寸/最大化态（窗口尚未显示，先摆位再首帧亮相，无跳变）。
  ApplySavedPlacement();

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (update_channel_) {
    update_channel_->SetMethodCallHandler(nullptr);
    update_channel_ = nullptr;
  }
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

void FlutterWindow::SetupUpdateChannel() {
  update_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "booksift/update",
          &flutter::StandardMethodCodec::GetInstance());
  update_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "installPackage") {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("bad_args", "update arguments missing");
          return;
        }
        auto path_it = arguments->find(flutter::EncodableValue("path"));
        auto bundle_it = arguments->find(flutter::EncodableValue("bundle"));
        if (path_it == arguments->end() || bundle_it == arguments->end()) {
          result->Error("bad_args", "path or bundle missing");
          return;
        }
        const auto* path = std::get_if<std::string>(&path_it->second);
        const auto* bundle = std::get_if<std::string>(&bundle_it->second);
        if (path == nullptr || bundle == nullptr) {
          result->Error("bad_args", "path or bundle invalid");
          return;
        }
        if (!StartUpdateHelper(*path, *bundle)) {
          result->Error("update_failed", "could not start update helper");
          return;
        }
        result->Success(flutter::EncodableValue(true));
        PostMessage(GetHandle(), WM_CLOSE, 0, 0);
      });
}

void FlutterWindow::ApplySavedPlacement() {
  RECT rect{};
  bool maximized = false;
  if (!LoadWindowPlacement(&rect, &maximized)) {
    return;
  }
  // 显示器布局变化（拔掉外接屏/改分辨率）后旧位置可能整窗落在屏幕外：
  // 与任何显示器都不相交则丢弃记录，保持默认启动位置。
  if (MonitorFromRect(&rect, MONITOR_DEFAULTTONULL) == nullptr) {
    return;
  }
  SetWindowPos(GetHandle(), nullptr, rect.left, rect.top, rect.right - rect.left,
               rect.bottom - rect.top, SWP_NOZORDER | SWP_NOACTIVATE);
  start_maximized_ = maximized;
}

void FlutterWindow::SavePlacement() { SaveWindowPlacement(GetHandle()); }

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // 自绘标题栏骨架：WM_NCCALCSIZE 归零非客户区（保留 WS_OVERLAPPEDWINDOW 样式 →
  // DWM 阴影/圆角/贴边行为不变），WM_NCHITTEST 用上面的几何自己判。
  // 这两条必须抢在 Flutter 引擎之前处理（引擎不认这套 NC 规则）。
  switch (message) {
    case WM_NCCALCSIZE: {
      // 客户区 = 整窗（自绘标题栏）。wParam==TRUE 时 lParam 是 NCCALCSIZE_PARAMS
      // （rgrc[0]），FALSE 时就是 RECT*，两者同一块内存布局，都按屏幕坐标处理。
      //
      // ⚠ 入参矩形就是系统**提议的新窗口矩形**：返回 0 且不修改它 = 客户区铺满整窗。
      // 绝不能改用 GetWindowRect() 自己算——NC 重算发生在窗口真正移动/缩放**之前**，
      // 那时取到的是旧矩形（旧实现里「最小化还原」因此把客户区留在窗口图标尺寸
      // 158x26，界面点不动）。
      RECT* client_rect = (wparam == TRUE)
                              ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam)->rgrc[0]
                              : reinterpret_cast<RECT*>(lparam);
      if (IsZoomed(hwnd) && !IsIconic(hwnd)) {
        // 最大化时窗口矩形盖住整块显示器（含任务栏），按显示器工作区裁回。
        //
        // ⚠ 显示器必须按**提议矩形**判定：最大化 → 最小化 → 任务栏还原时，这次
        // WM_NCCALCSIZE 里窗口自身还停在最小化坐标 (-32000,-32000)，用
        // MonitorFromWindow 会取「离它最近的显示器」——实测本机是副屏竖屏
        // （1080x1920@125%，工作区 1080x1860），客户区于是被裁成 1080x1860，
        // 而窗口是 2582x1390：Flutter 视图塞进错误尺寸 → 界面错位、整窗点不动。
        // 提议矩形就是这次变更后的窗口矩形，按它取显示器不会有这个问题。
        MONITORINFO monitor_info{};
        monitor_info.cbSize = sizeof(monitor_info);
        if (GetMonitorInfo(MonitorFromRect(client_rect, MONITOR_DEFAULTTONEAREST),
                           &monitor_info)) {
          *client_rect = monitor_info.rcWork;
        }
      }
      return 0;
    }
    case WM_NCHITTEST:
      return HitTestNonClient(hwnd, lparam);
    case WM_CLOSE:
      // 关闭前落盘窗口位置/尺寸/最大化态（用户口径：下次启动恢复）。
      SavePlacement();
      break;
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
