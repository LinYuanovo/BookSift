import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html;
import 'package:path_provider/path_provider.dart';

import '../../book_sources/forum_browser_policy.dart';
import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/icons.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/nav/page_transition.dart';
import '../../core/widgets/app_toast.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'forum_download.dart';

class ForumBrowserRequest {
  const ForumBrowserRequest({
    required this.source,
    required this.settings,
    required this.url,
    this.login = false,
  });
  final ForumSource source;
  final ForumSourceSettings settings;
  final Uri url;
  final bool login;
}

typedef ForumBrowserOpener =
    Future<String?> Function(BuildContext context, ForumBrowserRequest request);

final forumBrowserProvider = Provider<ForumBrowserOpener>(
  (ref) =>
      (context, request) =>
          Navigator.of(context, rootNavigator: true).push<String>(
            MotionPage<String>(
              type: SharedAxisTransitionType.horizontal,
              child: ForumBrowserPage(request: request),
            ).createRoute(context),
          ),
);

class ForumBrowserPage extends ConsumerStatefulWidget {
  const ForumBrowserPage({super.key, required this.request});
  final ForumBrowserRequest request;
  @override
  ConsumerState<ForumBrowserPage> createState() => _ForumBrowserPageState();
}

class _ForumBrowserPageState extends ConsumerState<ForumBrowserPage> {
  InAppWebViewController? _controller;
  CookieManager? _cookieManager;
  CookieManager get _cookies => _cookieManager!;
  WebViewEnvironment? _environment;
  bool _handlingLoad = false;
  bool _ready = false;
  bool _attemptedLogin = false;
  bool _checking = false;
  bool _downloading = false;
  bool _canPop = false;
  bool _leaving = false;
  int _progress = 0;
  String? _message;
  late Uri _current = widget.request.url;
  Uri get _base => widget.request.settings.base!;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (Platform.isLinux) {
      setState(() => _message = '当前 Linux 构建暂不支持内嵌网页；可先在书源设置中填写 Cookie。');
      return;
    }
    try {
      if (!isForumNavigationAllowed(_base, widget.request.url)) {
        throw const SourceFailure('网页地址与当前书源不一致');
      }
      PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
      if (Platform.isWindows) {
        final directory = await getApplicationSupportDirectory();
        _environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder:
                '${directory.path}/forum-webview/${widget.request.source.name}',
          ),
        );
      }
      _cookieManager = CookieManager.instance(webViewEnvironment: _environment);
      final WebUri url = WebUri(_base.toString());
      final existing = await _cookies.getCookies(url: url);
      for (final Cookie cookie in existing) {
        await _cookies.deleteCookie(
          url: url,
          name: cookie.name,
          domain: cookie.domain,
          path: cookie.path ?? '/',
        );
      }
      for (final String part in widget.request.settings.cookie.split(';')) {
        final int separator = part.indexOf('=');
        if (separator <= 0) continue;
        await _cookies.setCookie(
          url: url,
          name: part.substring(0, separator).trim(),
          value: part.substring(separator + 1).trim(),
          path: '/',
          isSecure: true,
        );
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _message = '无法打开应用内网页，请检查系统 WebView 组件后重试');
    }
  }

  Future<String> _readCookie() async {
    final Map<String, String> values = <String, String>{};
    for (final Uri address in <Uri>[_base, _current]) {
      if (!isForumNavigationAllowed(_base, address)) continue;
      for (final Cookie cookie in await _cookies.getCookies(
        url: WebUri(address.toString()),
      )) {
        values[cookie.name] = cookie.value;
      }
    }
    return values.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  Future<void> _onLoaded(
    InAppWebViewController controller,
    WebUri? address,
  ) async {
    final Uri? uri = address == null ? null : Uri.tryParse(address.toString());
    if (!mounted ||
        _handlingLoad ||
        uri == null ||
        !isForumNavigationAllowed(_base, uri)) {
      return;
    }
    _handlingLoad = true;
    try {
      _current = uri;
      final ForumSourceSettings settings = widget.request.settings;
      if (!_attemptedLogin &&
          settings.username.isNotEmpty &&
          settings.password.isNotEmpty) {
        final Object? result = await controller.evaluateJavascript(
          source: forumLoginScript(_base, settings.username, settings.password),
        );
        if (!mounted) return;
        if (result == 'submitted' ||
            result == 'captcha' ||
            result == 'filled') {
          _attemptedLogin = true;
          setState(
            () => _message = result == 'captcha'
                ? '账号密码已填入，请在页面中填写验证码后登录'
                : '正在尝试登录；如有验证请在页面内完成',
          );
        }
      }
      if (!widget.request.login) {
        final String cookie = await _readCookie();
        if (!mounted || cookie.isEmpty) return;
        await saveForumSessionCookie(
          ref,
          widget.request.source,
          settings,
          cookie,
        );
      } else {
        final Object? source = await controller.evaluateJavascript(
          source: forumDocumentScript(_base),
        );
        if (!mounted) return;
        if (source is String &&
            html
                    .parse(source)
                    .querySelector('a[href*="action=logout"], #um .vwmy') !=
                null) {
          await _finishLogin();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _message = '请在页面内完成登录或验证后重试');
    } finally {
      _handlingLoad = false;
    }
  }

  Future<void> _finishLogin() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final String cookie = await _readCookie();
      final bool valid = await ref
          .read(forumClientProvider)
          .checkSession(_base, cookie);
      if (!mounted) return;
      if (!valid) {
        setState(() => _message = '尚未登录成功，请完成账号、密码和验证码后再试');
        return;
      }
      final String current = ref.read(forumClientProvider).sessionCookie(_base);
      await saveForumSessionCookie(
        ref,
        widget.request.source,
        widget.request.settings,
        current,
      );
      if (mounted) {
        setState(() => _canPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, current);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is SourceFailure
              ? error.message
              : '暂时无法确认登录状态，请检查网络后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _chooseAttachments() async {
    if (_controller == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final String cookie = await _readCookie();
      final Object? source = await _controller!.evaluateJavascript(
        source: forumDocumentScript(_base),
      );
      List<BookAttachment> files = parseBookAttachments(
        source is String ? source : '',
        _current,
      );
      if (files.isEmpty) {
        files = await ref
            .read(forumClientProvider)
            .attachments(_base, ForumBook('当前帖子', _current), cookie: cookie);
      }
      if (!mounted) return;
      final BookAttachment? selected = await showDialog<BookAttachment>(
        context: context,
        animationStyle: dialogAnimationStyle(context),
        builder: (dialogContext) => SimpleDialog(
          title: Text('选择附件', style: AppTypography.of(context).headline),
          children: <Widget>[
            for (final BookAttachment file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, file),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.of(context).space2,
                  ),
                  child: Text(file.name, style: AppTypography.of(context).body),
                ),
              ),
          ],
        ),
      );
      if (selected != null && mounted) {
        await showForumDownload(
          context,
          widget.request.settings.withCookie(cookie),
          selected,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is SourceFailure
              ? error.message
              : '读取附件失败，请刷新当前帖子后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _directDownload(DownloadStartRequest request) async {
    if (_downloading) return;
    final Uri url = Uri.parse(request.url.toString());
    if (!isForumNavigationAllowed(_base, url)) {
      if (mounted) showAppToast(context, '附件指向其他网站，已停止下载');
      return;
    }
    setState(() => _downloading = true);
    try {
      final String cookie = await _readCookie();
      if (!mounted) return;
      await showForumDownload(
        context,
        widget.request.settings.withCookie(cookie),
        BookAttachment(request.suggestedFilename ?? '论坛附件', url, _current),
      );
    } catch (_) {
      if (mounted) showAppToast(context, '无法读取附件登录状态，请刷新后重试');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    if (!widget.request.login && _ready) {
      try {
        final String cookie = await _readCookie();
        if (mounted) {
          await saveForumSessionCookie(
            ref,
            widget.request.source,
            widget.request.settings,
            cookie,
          );
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _canPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '返回',
            onPressed: _leave,
            icon: const AppIcon('back'),
          ),
          title: Text(
            widget.request.login
                ? '${widget.request.source.label}登录'
                : widget.request.source.label,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: '刷新网页',
              onPressed: () => _controller?.reload(),
              icon: const AppIcon('refresh'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.pagePadding,
                  vertical: spacing.space2,
                ),
                child: Text(
                  _base.host,
                  style: AppTypography.of(
                    context,
                  ).caption.copyWith(color: colors.textMuted),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: EdgeInsets.all(spacing.pagePadding),
                  child: Text(
                    _message!,
                    style: AppTypography.of(context).secondary,
                  ),
                ),
              if (_ready && _progress < 100)
                LinearProgressIndicator(
                  value: _progress / 100,
                  color: colors.accent,
                  backgroundColor: colors.surfaceSunken,
                ),
              Expanded(
                child: !_ready
                    ? Center(
                        child: _message == null
                            ? const Text('准备应用内网页…')
                            : const SizedBox.shrink(),
                      )
                    : InAppWebView(
                        webViewEnvironment: _environment,
                        initialUrlRequest: URLRequest(
                          url: WebUri(widget.request.url.toString()),
                        ),
                        initialSettings: InAppWebViewSettings(
                          useShouldOverrideUrlLoading: true,
                          useOnDownloadStart: true,
                          javaScriptCanOpenWindowsAutomatically: false,
                          supportMultipleWindows: false,
                          isInspectable: false,
                          thirdPartyCookiesEnabled: false,
                          allowFileAccess: false,
                          allowContentAccess: false,
                        ),
                        onWebViewCreated: (controller) =>
                            _controller = controller,
                        shouldOverrideUrlLoading:
                            (controller, navigation) async {
                              final WebUri? url = navigation.request.url;
                              if (url == null) {
                                return NavigationActionPolicy.CANCEL;
                              }
                              if (navigation.isForMainFrame == false) {
                                return NavigationActionPolicy.ALLOW;
                              }
                              if (isForumNavigationAllowed(
                                _base,
                                Uri.parse(url.toString()),
                              )) {
                                return NavigationActionPolicy.ALLOW;
                              }
                              if (mounted) {
                                showAppToast(context, '该链接离开了当前书源，已留在应用内');
                              }
                              return NavigationActionPolicy.CANCEL;
                            },
                        onLoadStop: _onLoaded,
                        onLoadStart: (controller, address) async {
                          if (address == null) return;
                          final Uri uri = Uri.parse(address.toString());
                          if (isForumNavigationAllowed(_base, uri)) {
                            _current = uri;
                          } else if (uri.scheme != 'about') {
                            await controller.stopLoading();
                            if (mounted) {
                              setState(() => _message = '该页面离开当前书源，已停止加载');
                            }
                          }
                        },
                        onProgressChanged: (_, progress) {
                          if (mounted) setState(() => _progress = progress);
                        },
                        onReceivedError: (_, request, error) {
                          if (mounted && request.isForMainFrame == true) {
                            setState(() => _message = '网页加载失败，请检查网络后刷新');
                          }
                        },
                        onDownloadStartRequest: (_, request) =>
                            _directDownload(request),
                      ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.pagePadding),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () async {
                        if (await _controller?.canGoBack() ?? false) {
                          await _controller?.goBack();
                        }
                      },
                      child: const Text('上一页'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _checking || _downloading
                          ? null
                          : widget.request.login
                          ? _finishLogin
                          : _chooseAttachments,
                      child: Text(
                        _checking
                            ? '确认中…'
                            : widget.request.login
                            ? '登录完成'
                            : _downloading
                            ? '读取中…'
                            : '选择附件',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
