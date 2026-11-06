import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../book_sources/forum_session.dart';
import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/icons.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'forum_account_dialog.dart';
import 'forum_browser_page.dart';

void openBookSourcePage(BuildContext context, {String initialQuery = ''}) {
  context.go(
    Uri(
      path: '/search',
      queryParameters: <String, String>{
        'q': initialQuery,
        'source': 'shangxiang',
      },
    ).toString(),
  );
}

class BookSourcePage extends ConsumerStatefulWidget {
  const BookSourcePage({
    super.key,
    this.initialQuery = '',
    this.source = ForumSource.shangxiang,
    this.embedded = false,
  });
  final String initialQuery;
  final ForumSource source;
  final bool embedded;
  @override
  ConsumerState<BookSourcePage> createState() => BookSourcePageState();
}

class BookSourcePageState extends ConsumerState<BookSourcePage> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  late ForumSource _source = widget.source;
  final ScrollController _scroll = ScrollController();
  final Map<ForumSource, List<ForumBook>> _results =
      <ForumSource, List<ForumBook>>{};
  bool _busy = false;
  bool _failed = false;
  String? _message;
  int _generation = 0;
  List<ForumBook> get _books => _results[_source] ?? const <ForumBook>[];

  @override
  void didUpdateWidget(BookSourcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) _select(widget.source);
  }

  void _select(ForumSource source) {
    setState(() {
      _source = source;
      _generation++;
      _busy = false;
      _message = null;
      _failed = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<ForumSourceSettings> _settings(ForumSource source) async {
    final settings = await ref.read(forumSettingsProvider(source).future);
    if (settings.base != null) return settings;
    final Uri base = await ref.read(forumClientProvider).resolve(source);
    if (!mounted) throw const SourceFailure('页面已关闭');
    await saveForumSettings(ref, source, base, '');
    return ForumSourceSettings(base: base);
  }

  Future<void> configure() async {
    if (_busy) return;
    await showForumAccountDialog(context, ref, _source);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    final int generation = ++_generation;
    final ForumSource source = _source;
    setState(() {
      _busy = true;
      _failed = false;
      _message = null;
    });
    try {
      final settings = await _settings(source);
      if (!mounted || generation != _generation) return;
      final client = ref.read(forumClientProvider);
      final List<ForumBook> books = await ForumSessionCoordinator(client).run(
        base: settings.base!,
        cookie: settings.cookie,
        login: () => !mounted || generation != _generation
            ? Future<String?>.value(null)
            : openForumLogin(context, ref, source, settings),
        operation: (cookie) =>
            client.search(settings.base!, query, cookie: cookie),
        persist: (cookie) async {
          if (mounted) {
            await saveForumSessionCookie(ref, source, settings, cookie);
          }
        },
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results[source] = books;
        _message = books.isEmpty ? '没有找到相关书籍' : null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _message = error is SourceFailure
              ? error.message
              : '连接失败，请检查网络、论坛地址和登录状态后重试';
          _failed = true;
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _browse(ForumBook book) async {
    final ForumSource source = _source;
    try {
      final settings = await _settings(source);
      if (!mounted) return;
      await ref.read(forumBrowserProvider)(
        context,
        ForumBrowserRequest(source: source, settings: settings, url: book.url),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is SourceFailure ? error.message : '暂时无法打开帖子，请重试';
          _failed = true;
        });
      }
    }
  }

  void showContents() {
    final List<ForumBook> books = _books;
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: overlayAnimationStyle(context),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            if (books.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppSpacing.of(context).pagePadding),
                child: const Text('尚无已加载的结果行'),
              ),
            for (final ForumBook book in books)
              ListTile(
                title: Text(book.title, style: AppTypography.of(context).body),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _browse(book);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final spacing = AppSpacing.of(context);
    final typography = AppTypography.of(context);
    final motion = AppMotionTheme.of(context);
    final Widget body = ScrollChrome(
      controller: _scroll,
      child: ListView(
        key: PageStorageKey<String>('forum-results-${_source.name}'),
        controller: _scroll,
        padding: EdgeInsets.all(spacing.pagePadding),
        children: <Widget>[
          if (!widget.embedded) ...<Widget>[
            SegmentedPill<ForumSource>(
              options: <(ForumSource, String)>[
                for (final source in ForumSource.values) (source, source.label),
              ],
              selected: _source,
              onChanged: _select,
            ),
            SizedBox(height: spacing.space4),
            AppTextField(
              controller: _query,
              label: '书名',
              textInputAction: TextInputAction.search,
              onSubmitted: search,
              action: IconButton(
                tooltip: '搜索书源',
                onPressed: _busy ? null : () => search(_query.text),
                icon: AppIcon('search', color: colors.accentStrong),
              ),
            ),
            SizedBox(height: spacing.space3),
          ],
          Text(
            '在应用内浏览帖子、选择附件，再保存到指定位置。',
            style: typography.caption.copyWith(color: colors.textMuted),
          ),
          if (_busy)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.space3),
              child: LinearProgressIndicator(
                value: motion.reduceMotion ? 0 : null,
                color: colors.accent,
                backgroundColor: colors.surfaceSunken,
                minHeight: spacing.space1,
                borderRadius: AppRadius.pillBorder,
                stopIndicatorRadius: 0,
                trackGap: 0,
              ),
            ),
          if (_message != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.space3),
              child: Text(
                _message!,
                style: typography.secondary.copyWith(
                  color: _failed ? colors.danger : colors.textSecondary,
                ),
              ),
            ),
          if (!_busy && _books.isEmpty)
            TextButton(
              onPressed: configure,
              child: const Text('设置账号 / Cookie'),
            ),
          for (final ForumBook book in _books)
            Padding(
              padding: EdgeInsets.only(top: spacing.cardGap),
              child: Card(
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing.cardPadding,
                    vertical: spacing.space2,
                  ),
                  title: Text(
                    book.title,
                    style: typography.cardTitle.copyWith(color: colors.text),
                  ),
                  subtitle: Text(
                    book.url.host,
                    style: typography.caption.copyWith(color: colors.textMuted),
                  ),
                  onTap: () => _browse(book),
                  trailing: AppIcon('book', color: colors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: (ModalRoute.of(context)?.canPop ?? false)
            ? IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.maybePop(context),
                icon: const AppIcon('back'),
              )
            : null,
        title: const Text('书源搜索与下载'),
        actions: <Widget>[
          IconButton(
            tooltip: '书源设置',
            onPressed: _busy ? null : configure,
            icon: const AppIcon('gear'),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
