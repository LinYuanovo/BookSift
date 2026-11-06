import 'dart:io';

import 'package:animations/animations.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/icons.dart';
import '../../core/nav/center_slot.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';

void openBookSourcePage(BuildContext context, {String initialQuery = ''}) {
  openCenterPage(
    context,
    BookSourcePage(initialQuery: initialQuery),
    type: SharedAxisTransitionType.horizontal,
  );
}

class BookSourcePage extends ConsumerStatefulWidget {
  const BookSourcePage({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<BookSourcePage> createState() => _BookSourcePageState();
}

class _BookSourcePageState extends ConsumerState<BookSourcePage> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  ForumSource _source = ForumSource.shangxiang;
  List<ForumBook> _books = <ForumBook>[];
  bool _busy = false;
  String? _message;
  String? _progress;
  CancelToken? _cancel;
  final ScrollController _scroll = ScrollController();
  bool _failed = false;
  double? _progressValue;

  @override
  void dispose() {
    _cancel?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _error(Object error) {
    if (error is SourceFailure) return error.message;
    if (error is DioException && CancelToken.isCancel(error)) return '下载已取消';
    return '连接失败，请检查网络、网站证书、最新地址和登录状态后重试';
  }

  Future<ForumSourceSettings> _settings() async {
    final ForumSourceSettings settings = await ref.read(
      forumSettingsProvider(_source).future,
    );
    if (settings.base == null) {
      throw const SourceFailure('请先打开书源设置，解析并确认最新地址');
    }
    return settings;
  }

  Future<void> _search() async {
    if (_busy || _query.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
      _progressValue = null;
      _books = <ForumBook>[];
    });
    try {
      final ForumSourceSettings settings = await _settings();
      final List<ForumBook> results = await ref
          .read(forumClientProvider)
          .search(settings.base!, _query.text, cookie: settings.cookie);
      if (mounted) {
        setState(() {
          _books = results;
          _message = results.isEmpty ? '没有找到相关书籍' : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _error(error);
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) showAppToast(context, '无法打开浏览器');
    } catch (_) {
      if (mounted) showAppToast(context, '无法打开浏览器');
    }
  }

  Future<void> _configure() async {
    final AppColors colors = AppColors.of(context);
    final AppTypography typography = AppTypography.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    ForumSourceSettings settings = const ForumSourceSettings();
    try {
      settings = await ref.read(forumSettingsProvider(_source).future);
    } catch (_) {}
    if (!mounted) return;
    final TextEditingController address = TextEditingController(
      text: settings.base?.toString() ?? '',
    );
    final TextEditingController cookie = TextEditingController(
      text: settings.cookie,
    );
    bool resolving = false;
    bool saving = false;
    String? error;
    final DialogRoute<void> settingsRoute = DialogRoute<void>(
      context: context,
      animationStyle: dialogAnimationStyle(context),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AppDialog(
          title: '${_source.label}设置',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '先解析或填写论坛最新地址；需要登录时，在浏览器登录后粘贴 Cookie。登录态仅加密保存在本机，并绑定该地址。',
                style: typography.secondary.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: spacing.space4),
              AppTextField(
                controller: address,
                label: '论坛最新地址（HTTPS）',
                keyboardType: TextInputType.url,
              ),
              Wrap(
                spacing: spacing.space2,
                runSpacing: spacing.space1,
                children: <Widget>[
                  TextButton(
                    onPressed: resolving || saving
                        ? null
                        : () async {
                            update(() {
                              resolving = true;
                              error = null;
                            });
                            try {
                              final Uri target = await ref
                                  .read(forumClientProvider)
                                  .resolve(_source);
                              if (dialogContext.mounted) {
                                update(() {
                                  if (address.text != target.toString()) {
                                    cookie.clear();
                                  }
                                  address.text = target.toString();
                                });
                              }
                            } catch (failure) {
                              if (dialogContext.mounted) {
                                update(() => error = _error(failure));
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                update(() => resolving = false);
                              }
                            }
                          },
                    child: Text(resolving ? '解析中…' : '从导航页获取'),
                  ),
                  TextButton(
                    onPressed: () => _open(Uri.parse(_source.navigationUrl)),
                    child: const Text('打开导航页'),
                  ),
                  TextButton(
                    onPressed: () {
                      try {
                        _open(validateForumBase(address.text));
                      } catch (failure) {
                        update(() => error = _error(failure));
                      }
                    },
                    child: const Text('浏览器登录'),
                  ),
                ],
              ),
              SizedBox(height: spacing.space4),
              AppTextField(
                controller: cookie,
                obscureText: true,
                label: '登录 Cookie（可留空）',
                helper: '清空后保存可移除本机登录态',
              ),
              if (error != null)
                Padding(
                  padding: EdgeInsets.only(top: spacing.space3),
                  child: Text(
                    error!,
                    style: typography.secondary.copyWith(color: colors.danger),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving || resolving
                  ? null
                  : () async {
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final Uri base = validateForumBase(address.text);
                        if (settings.base != null &&
                            base.origin != settings.base!.origin &&
                            cookie.text == settings.cookie &&
                            cookie.text.isNotEmpty) {
                          throw const SourceFailure(
                            '地址已改变，请重新登录并填写新地址的 Cookie',
                          );
                        }
                        await saveForumSettings(
                          ref,
                          _source,
                          base,
                          cookie.text,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (failure) {
                        if (dialogContext.mounted) {
                          update(() {
                            error = _error(failure);
                            saving = false;
                          });
                        }
                      }
                    },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(settingsRoute);
    await settingsRoute.completed;
    address.dispose();
    cookie.dispose();
  }

  Future<void> _download(ForumBook book) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
      _progressValue = null;
      _progress = '读取附件…';
    });
    Directory? temporary;
    try {
      final ForumSourceSettings settings = await _settings();
      final ForumSourceClient client = ref.read(forumClientProvider);
      final List<BookAttachment> files = await client.attachments(
        settings.base!,
        book,
        cookie: settings.cookie,
      );
      if (!mounted) return;
      final BookAttachment? selected = await showDialog<BookAttachment>(
        context: context,
        animationStyle: dialogAnimationStyle(context),
        builder: (dialogContext) => SimpleDialog(
          title: Text(
            '选择附件',
            style: AppTypography.of(
              context,
            ).headline.copyWith(color: AppColors.of(context).text),
          ),
          titlePadding: EdgeInsets.all(AppSpacing.of(context).cardPadding),
          contentPadding: EdgeInsets.only(
            bottom: AppSpacing.of(context).cardPadding,
          ),
          children: <Widget>[
            for (final BookAttachment file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, file),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.of(context).cardPadding,
                  vertical: AppSpacing.of(context).space3,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppMetrics.minTouchTarget,
                  ),
                  child: Row(
                    children: <Widget>[
                      AppIcon('book', color: AppColors.of(context).textMuted),
                      SizedBox(width: AppSpacing.of(context).space3),
                      Expanded(
                        child: Text(
                          file.name,
                          style: AppTypography.of(
                            context,
                          ).body.copyWith(color: AppColors.of(context).text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      final CancelToken token = CancelToken();
      _cancel = token;
      temporary = await (await getTemporaryDirectory()).createTemp(
        'booksift-book-',
      );
      final File downloaded = await client.download(
        settings.base!,
        selected,
        temporary,
        cookie: settings.cookie,
        cancelToken: token,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _progressValue = total > 0
                  ? (received / total).clamp(0.0, 1.0)
                  : null;
              _progress = total > 0
                  ? '下载 ${(received * 100 / total).toStringAsFixed(0)}%'
                  : '已下载 ${(received / 1048576).toStringAsFixed(1)} MB';
            });
          }
        },
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _cancel = null;
        _progress = '选择保存位置…';
        _progressValue = 1;
      });
      final String name = selected.name.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1f]'),
        '_',
      );
      final Uri? destination = await FilePicker.saveFile(
        fileName: name,
        bytes: await downloaded.readAsBytes(),
        mimeType: 'application/octet-stream',
        dialogTitle: '保存书籍到指定位置',
      );
      if (mounted) {
        setState(
          () => _message = destination == null ? '已取消保存' : '已保存到：$destination',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _error(error);
          _failed = !(error is DioException && CancelToken.isCancel(error));
        });
      }
    } finally {
      _cancel = null;
      if (temporary != null && await temporary.exists()) {
        try {
          await temporary.delete(recursive: true);
        } catch (_) {
          if (mounted) _message = '文件操作已结束，临时缓存未能清除，请稍后重试整理存储';
        }
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography typography = AppTypography.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: (ModalRoute.of(context)?.canPop ?? false)
            ? IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.maybePop(context),
                icon: AppIcon('back', color: colors.textSecondary),
              )
            : null,
        title: Text(
          '书源搜索与下载',
          style: typography.headline.copyWith(color: colors.text),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '书源设置',
            onPressed: _busy ? null : _configure,
            icon: AppIcon(
              'gear',
              color: _busy ? colors.textMuted : colors.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ScrollChrome(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.all(spacing.pagePadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IgnorePointer(
                        ignoring: _busy,
                        child: SegmentedPill<ForumSource>(
                          options: <(ForumSource, String)>[
                            for (final ForumSource source in ForumSource.values)
                              (source, source.label),
                          ],
                          selected: _source,
                          onChanged: (selected) {
                            if (!_busy) {
                              setState(() {
                                _source = selected;
                                _books = <ForumBook>[];
                                _message = null;
                                _failed = false;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(height: spacing.space4),
                      AppTextField(
                        controller: _query,
                        label: '书名',
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        action: IconButton(
                          tooltip: '搜索书源',
                          onPressed: _busy ? null : _search,
                          icon: AppIcon(
                            'search',
                            color: _busy
                                ? colors.textMuted
                                : colors.accentStrong,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.space3),
                      Text(
                        '选择结果后查看附件，再选择保存位置。付费、回复和权限要求请在原站处理。',
                        style: typography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      if (_busy) ...<Widget>[
                        SizedBox(height: spacing.space4),
                        LinearProgressIndicator(
                          value:
                              _progressValue ??
                              (motion.reduceMotion ? 0 : null),
                          color: colors.accent,
                          backgroundColor: colors.surfaceSunken,
                          minHeight: spacing.space1,
                          borderRadius: AppRadius.pillBorder,
                          stopIndicatorRadius: 0,
                          trackGap: 0,
                          semanticsLabel: _progress ?? '正在搜索',
                        ),
                      ],
                      if (_progress != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.space2),
                          child: Text(
                            _progress!,
                            style: AppTypography.tabular(
                              typography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      if (_cancel != null)
                        TextButton(
                          onPressed: () => _cancel?.cancel(),
                          child: const Text('取消下载'),
                        ),
                      if (_message != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.space3),
                          child: Text(
                            _message!,
                            style: typography.secondary.copyWith(
                              color: _failed
                                  ? colors.danger
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  spacing.pagePadding,
                  0,
                  spacing.pagePadding,
                  spacing.space8,
                ),
                sliver: SliverList.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final ForumBook book = _books[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: spacing.cardGap),
                      child: Card(
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: spacing.cardPadding,
                            vertical: spacing.space2,
                          ),
                          title: Text(
                            book.title,
                            style: typography.cardTitle.copyWith(
                              color: colors.text,
                            ),
                          ),
                          subtitle: Padding(
                            padding: EdgeInsets.only(top: spacing.space1),
                            child: Text(
                              book.url.host,
                              style: typography.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          onTap: _busy ? null : () => _download(book),
                          trailing: IconButton(
                            tooltip: '打开原帖',
                            icon: AppIcon(
                              'external',
                              color: colors.textSecondary,
                            ),
                            onPressed: () => _open(book.url),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
