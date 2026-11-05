import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/icons.dart';
import '../../core/widgets/app_toast.dart';

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

  @override
  void dispose() {
    _cancel?.cancel();
    _query.dispose();
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
      if (mounted) setState(() => _message = _error(error));
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text('${_source.label}设置'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '先解析或填写论坛最新地址；需要登录时，在浏览器登录后粘贴 Cookie。登录态仅加密保存在本机，并绑定该地址。',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(
                      labelText: '论坛最新地址（HTTPS）',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
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
                        onPressed: () =>
                            _open(Uri.parse(_source.navigationUrl)),
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
                  TextField(
                    controller: cookie,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '登录 Cookie（可留空）',
                      helperText: '清空后保存可移除本机登录态',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!),
                    ),
                ],
              ),
            ),
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
    address.dispose();
    cookie.dispose();
  }

  Future<void> _download(ForumBook book) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
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
        builder: (dialogContext) => SimpleDialog(
          title: const Text('选择附件'),
          children: <Widget>[
            for (final BookAttachment file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, file),
                child: Text(file.name),
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
            setState(
              () => _progress = total > 0
                  ? '下载 ${(received * 100 / total).toStringAsFixed(0)}%'
                  : '已下载 ${(received / 1048576).toStringAsFixed(1)} MB',
            );
          }
        },
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _cancel = null;
        _progress = '选择保存位置…';
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
      if (mounted) setState(() => _message = _error(error));
    } finally {
      _cancel = null;
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源搜索与下载'),
        actions: <Widget>[
          IconButton(
            tooltip: '书源设置',
            onPressed: _busy ? null : _configure,
            icon: const AppIcon('gear'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                SegmentedButton<ForumSource>(
                  segments: <ButtonSegment<ForumSource>>[
                    for (final ForumSource source in ForumSource.values)
                      ButtonSegment(value: source, label: Text(source.label)),
                  ],
                  selected: <ForumSource>{_source},
                  onSelectionChanged: _busy
                      ? null
                      : (selected) => setState(() {
                          _source = selected.single;
                          _books = <ForumBook>[];
                          _message = null;
                        }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: '书名',
                    suffixIcon: IconButton(
                      tooltip: '搜索书源',
                      onPressed: _busy ? null : _search,
                      icon: const AppIcon('search'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('选择结果后查看附件，再选择保存位置。付费、回复和权限要求请在原站处理。'),
                if (_busy) const LinearProgressIndicator(),
                if (_progress != null) Text(_progress!),
                if (_cancel != null)
                  TextButton(
                    onPressed: () => _cancel?.cancel(),
                    child: const Text('取消下载'),
                  ),
                if (_message != null) Text(_message!),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final ForumBook book = _books[index];
                return ListTile(
                  title: Text(book.title),
                  subtitle: Text(book.url.host),
                  onTap: _busy ? null : () => _download(book),
                  trailing: IconButton(
                    tooltip: '打开原帖',
                    icon: const AppIcon('external'),
                    onPressed: () => _open(book.url),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
