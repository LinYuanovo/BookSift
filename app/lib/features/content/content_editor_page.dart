import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../classify/src/engine.dart' show kRecommendKind;
import '../../content/content_draft.dart';
import '../../content/document_reader.dart';
import '../../content/document_source.dart';
import '../../content/review_recognizer.dart';
import '../../core/external_launch.dart';
import '../../core/icons.dart';
import '../../core/nav/center_slot.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'content_detail_page.dart';
import 'detail_slot.dart';

class ContentEditorPage extends ConsumerStatefulWidget {
  const ContentEditorPage({super.key, this.postId, this.initialDraft});

  final int? postId;
  final ContentDraft? initialDraft;

  @override
  ConsumerState<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends ConsumerState<ContentEditorPage> {
  final TextEditingController _sourceText = TextEditingController();
  final TextEditingController _sourceUrl = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final ScrollController _scroll = ScrollController();
  ContentDraft? _draft;
  _PostFields? _post;
  final List<_FloorFields> _floors = <_FloorFields>[];
  final List<_EntryFields> _entries = <_EntryFields>[];
  final List<_DisposableFields> _retired = <_DisposableFields>[];
  bool _busy = false;
  bool _dirty = false;
  bool _leaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null) {
      _setDraft(widget.initialDraft!);
    } else if (widget.postId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final ContentDraft? draft = await ref
          .read(contentEditorRepositoryProvider)
          .load(widget.postId!);
      if (!mounted) return;
      if (draft == null) throw const ContentEditException('帖子已不存在。');
      _setDraft(draft);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setDraft(ContentDraft draft) {
    if (_post != null) _retired.add(_post!);
    _retired.addAll(_floors);
    _retired.addAll(_entries);
    _floors.clear();
    _entries.clear();
    _draft = draft;
    _post = _PostFields(draft);
    _floors.addAll(draft.floors.map(_FloorFields.new));
    _entries.addAll(draft.entries.map(_EntryFields.new));
    _dirty = false;
    _error = null;
  }

  @override
  void dispose() {
    _sourceText.dispose();
    _sourceUrl.dispose();
    _scroll.dispose();
    _post?.dispose();
    for (final _DisposableFields fields in <_DisposableFields>[
      ..._floors,
      ..._entries,
      ..._retired,
    ]) {
      fields.dispose();
    }
    super.dispose();
  }

  Future<void> _read(Future<ContentDraft?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ContentDraft? draft = await action();
      if (mounted && draft != null) setState(() => _setDraft(draft));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ContentDraft _collectDraft() => _draft!.copyWith(
    title: _post!.title.text,
    author: _post!.author.text,
    channel: _post!.channel.text,
    subChannel: _post!.subChannel.text,
    date: _post!.date.text,
    sourceUrl: _post!.sourceUrl.text,
    category: _post!.category,
    floors: _floors.map((_FloorFields floor) => floor.collect()).toList(),
    entries: _entries.map((_EntryFields fields) {
      final ContentEntryDraft entry = fields.collect();
      return entry.copyWith(
        recommender: entry.recommender == _draft!.author
            ? _post!.author.text
            : entry.recommender,
        channel: entry.channel == _draft!.channel
            ? _post!.channel.text
            : entry.channel,
        date: entry.date == _draft!.date ? _post!.date.text : entry.date,
        sourceUrl: entry.sourceUrl == _draft!.sourceUrl
            ? _post!.sourceUrl.text
            : entry.sourceUrl,
      );
    }).toList(),
  );

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        animationStyle: dialogAnimationStyle(context),
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('返回继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _close() async {
    if (_busy) return;
    if ((_dirty ||
            widget.postId == null &&
                (_draft != null || _sourceText.text.isNotEmpty)) &&
        !await _confirm('放弃未保存内容？', '返回后这次编辑不会保存。', '放弃修改')) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  Future<void> _recognize() async {
    if (_entries.isNotEmpty &&
        !await _confirm('重新识别书目？', '会替换当前书目校对内容，楼层原文和图片保持不变。', '重新识别')) {
      return;
    }
    if (!mounted) return;
    final ContentDraft current = _collectDraft();
    final List<ContentEntryDraft> entries = const ReviewRecognizer().recognize(
      current,
    );
    setState(() {
      _retired.addAll(_entries);
      _entries.clear();
      _entries.addAll(entries.map(_EntryFields.new));
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ContentDraft draft = _collectDraft();
      if (draft.floors.any(
        (ContentFloorDraft floor) =>
            floor.images.any((ContentImageDraft image) => !image.embedded),
      )) {
        draft = await ref.read(documentSourceProvider).preserveImages(draft);
        if (!mounted) return;
        final List<String> losses = draft.warnings
            .where(
              (String warning) =>
                  warning.startsWith('有 ') && warning.contains('未能下载'),
            )
            .toList();
        if (losses.isNotEmpty &&
            !await _confirm('有图片尚未完整留档', losses.join('\n'), '保留链接并保存')) {
          return;
        }
      }
      final ContentSaveResult result = await ref
          .read(contentEditorRepositoryProvider)
          .save(draft);
      if (!mounted) return;
      final GoRouter? router = GoRouter.maybeOf(context);
      final bool embedded = centerSlotMounted();
      ref.invalidate(queriesProvider);
      ref.invalidate(postDetailProvider(result.postId));
      setState(() {
        _dirty = false;
        _leaving = true;
      });
      if (widget.postId == null && embedded) {
        ref.read(onlinePostDetailProvider.notifier).state = null;
        ref.read(detailSelectionProvider.notifier).state = PostSelection(
          postId: result.postId,
        );
      }
      showAppToast(
        context,
        result.alreadyImported
            ? '内容已导入，已打开原帖子'
            : '已保存 · ${result.entryCount} 本书${result.entryCount == 0 ? ' · 原文作为帖子保留' : ''}',
      );
      Navigator.of(context).pop();
      if (widget.postId == null && !embedded && router != null) {
        router.push(
          '/post/${result.postId}',
          extra: PostSelection(postId: result.postId),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return PopScope<void>(
      canPop:
          _leaving ||
          !_busy &&
              !_dirty &&
              (widget.postId != null ||
                  _draft == null && _sourceText.text.isEmpty),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '取消编辑',
            onPressed: _busy ? null : _close,
            icon: AppIcon('back', size: 20, color: colors.textSecondary),
          ),
          title: Text(widget.postId == null ? '导入扫书' : '编辑帖子'),
          actions: <Widget>[
            if (_draft != null)
              Padding(
                padding: EdgeInsets.only(right: AppSpacing.of(context).space3),
                child: FilledButton(
                  key: const Key('content-save'),
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '处理中…' : '保存'),
                ),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Form(
                key: _form,
                onChanged: () {
                  if (!_dirty) setState(() => _dirty = true);
                },
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.all(AppSpacing.of(context).pagePadding),
                  children: <Widget>[
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null) _notice(_error!, danger: true),
                    if (_draft == null && widget.postId == null) _importInput(),
                    if (_draft != null) ..._editor(),
                    if (_draft == null && widget.postId != null && !_busy)
                      TextButton(onPressed: _load, child: const Text('重新读取帖子')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _importInput() => _section('保留原文，再校对书目', <Widget>[
    const Text(
      '粘贴论坛、社区、公众号扫书正文，或选择 TXT / Markdown / HTML / DOCX。识别只提取书目，不会删掉原文。',
    ),
    _field(_sourceUrl, '原文链接（可选）', key: 'import-source-url'),
    Wrap(
      spacing: AppSpacing.of(context).space2,
      runSpacing: AppSpacing.of(context).space2,
      children: <Widget>[
        OutlinedButton(
          key: const Key('import-read-url'),
          onPressed: () => _read(
            () => ref
                .read(documentSourceProvider)
                .readUrl(_sourceUrl.text.trim()),
          ),
          child: const Text('读取链接'),
        ),
        OutlinedButton(
          key: const Key('import-pick-file'),
          onPressed: () =>
              _read(() => ref.read(documentSourceProvider).pickDocument()),
          child: const Text('选择文档'),
        ),
        if (_sourceUrl.text.trim().isNotEmpty)
          TextButton(
            onPressed: () => openThreadExternallyWithFeedback(
              context,
              _sourceUrl.text.trim(),
            ),
            child: const Text('在浏览器打开'),
          ),
      ],
    ),
    _field(_sourceText, '扫书原文', key: 'import-source-text', lines: 12),
    FilledButton(
      key: const Key('import-recognize'),
      onPressed: () => _read(() async {
        final ContentDraft draft = const DocumentReader().read(
          bytes: Uint8List.fromList(utf8.encode(_sourceText.text)),
          fileName: '粘贴扫书.txt',
          sourceUrl: _sourceUrl.text.trim(),
        );
        return draft;
      }),
      child: const Text('识别并校对'),
    ),
    const Text('网页需要验证时，请在实际浏览器完成验证后保存 HTML 或粘贴正文；验证页不会作为扫书导入。'),
  ]);

  List<Widget> _editor() => <Widget>[
    _notice(
      '原文 ${_floors.length} 段 · 图片 ${_floors.fold<int>(0, (int count, _FloorFields floor) => count + floor.images.length)} 张 · 书目 ${_entries.length} 本。${_entries.isEmpty ? '尚未识别书目，将作为帖子保存，也可手动添加。' : '请核对书名、小说作者与评价对应关系。'}',
    ),
    for (final String warning in _draft!.warnings) _notice(warning),
    _section('帖子信息', <Widget>[
      _field(_post!.title, '标题', key: 'edit-post-title'),
      _field(_post!.author, '发帖人 / 书评人', key: 'edit-post-author'),
      _field(
        _post!.channel,
        '来源 / 社区',
        key: 'edit-post-channel',
        required: true,
      ),
      _field(_post!.subChannel, '子来源 / 栏目', key: 'edit-post-subchannel'),
      _field(
        _post!.date,
        '发布日期 YYYY-MM-DD',
        key: 'edit-post-date',
        validator: (String value) => validContentDate(value) ? null : '请输入有效日期',
      ),
      _field(
        _post!.sourceUrl,
        '原文链接',
        key: 'edit-post-source',
        validator: (String value) =>
            validContentUrl(value) ? null : '请输入 HTTP 或 HTTPS 链接',
      ),
      _category(
        _post!.category,
        (String value) => setState(() {
          _post!.category = value;
          _dirty = true;
        }),
        key: 'edit-post-category',
      ),
      if (widget.postId != null)
        TextButton(
          onPressed: () async {
            try {
              final String? saved = await ref
                  .read(contentEditorRepositoryProvider)
                  .exportOriginal(widget.postId!);
              if (mounted && saved != null) showAppToast(context, '原始文档已保存');
            } catch (error) {
              if (mounted) setState(() => _error = _message(error));
            }
          },
          child: const Text('导出原始留档'),
        ),
    ]),
    _section('原文与图片', <Widget>[
      const Text('完整正文始终保留。编辑正文后，书目评价可独立校对，或重新识别。'),
      for (final (int index, _FloorFields floor) in _floors.indexed)
        _floorEditor(floor, index),
      OutlinedButton(
        key: const Key('edit-add-floor'),
        onPressed: () => setState(() {
          _floors.add(_FloorFields(const ContentFloorDraft(text: '')));
          _dirty = true;
        }),
        child: const Text('添加正文段落'),
      ),
    ]),
    _section('书目与评价', <Widget>[
      Wrap(
        spacing: AppSpacing.of(context).space2,
        children: <Widget>[
          OutlinedButton(
            key: const Key('edit-recognize-again'),
            onPressed: _recognize,
            child: const Text('重新识别书目'),
          ),
          OutlinedButton(
            key: const Key('edit-add-entry'),
            onPressed: () => setState(() {
              _entries.add(
                _EntryFields(
                  ContentEntryDraft(
                    name: '',
                    comment: '',
                    recommender: _post!.author.text,
                    channel: _post!.channel.text,
                    date: _post!.date.text,
                    sourceUrl: _post!.sourceUrl.text,
                  ),
                ),
              );
              _dirty = true;
            }),
            child: const Text('手动添加书目'),
          ),
        ],
      ),
      for (final (int index, _EntryFields entry) in _entries.indexed)
        _entryEditor(entry, index),
    ]),
  ];

  Widget _floorEditor(_FloorFields floor, int index) => ExpansionTile(
    key: ObjectKey(floor),
    initiallyExpanded: _floors.length <= 4,
    title: Text(
      '${index + 1} · ${floor.text.text.trim().isEmpty ? '正文段落' : floor.text.text.trim().split('\n').first}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${floor.text.text.runes.length} 字 · ${floor.images.length} 张图片',
    ),
    children: <Widget>[
      _field(
        floor.text,
        '第 ${index + 1} 段正文',
        key: 'edit-floor-$index',
        lines: 5,
      ),
      for (final (int imageIndex, ContentImageDraft image)
          in floor.images.indexed)
        ListTile(
          title: Text(
            image.embedded ? '本地嵌入图片 ${imageIndex + 1}' : image.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: image.embedded && !image.url.startsWith('data:image/svg')
              ? Image.memory(
                  UriData.parse(image.url).contentAsBytes(),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Text('图片'),
                )
              : AppIcon(
                  'image',
                  size: 20,
                  color: AppColors.of(context).textSecondary,
                ),
          trailing: IconButton(
            tooltip: '移除图片',
            icon: AppIcon(
              'close',
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            onPressed: () => setState(() {
              floor.images.removeAt(imageIndex);
              _dirty = true;
            }),
          ),
          onTap: () => _editImageUrl(floor, imageIndex),
        ),
      Wrap(
        spacing: AppSpacing.of(context).space2,
        children: <Widget>[
          TextButton(
            onPressed: () async {
              try {
                final ContentImageDraft? image = await ref
                    .read(documentSourceProvider)
                    .pickImage();
                if (mounted && image != null) {
                  setState(() {
                    floor.images.add(image);
                    _dirty = true;
                  });
                }
              } catch (error) {
                if (mounted) setState(() => _error = _message(error));
              }
            },
            child: const Text('添加本地图片'),
          ),
          TextButton(
            onPressed: () => _editImageUrl(floor, null),
            child: const Text('添加图片链接'),
          ),
          TextButton(
            onPressed: () async {
              if (!await _confirm('删除这一段正文？', '原始留档不会改变，关联书目将改为第一段。', '删除段落') ||
                  !mounted) {
                return;
              }
              setState(() {
                _retired.add(_floors.removeAt(index));
                for (final _EntryFields entry in _entries) {
                  if (entry.floorIndex == index) {
                    entry.floorIndex = 0;
                  } else if (entry.floorIndex > index) {
                    entry.floorIndex--;
                  }
                }
                _dirty = true;
              });
            },
            child: const Text('删除段落'),
          ),
        ],
      ),
    ],
  );

  Widget _entryEditor(_EntryFields entry, int index) => ExpansionTile(
    key: ObjectKey(entry),
    initiallyExpanded: _entries.length <= 4,
    title: Text(
      '${index + 1} · ${entry.name.text.isEmpty ? '待填写书名' : entry.name.text}',
    ),
    subtitle: Text(entry.author.text.isEmpty ? '小说作者待校对' : entry.author.text),
    children: <Widget>[
      _field(entry.name, '书名', key: 'edit-entry-name-$index', required: true),
      _field(entry.author, '小说作者', key: 'edit-entry-author-$index'),
      _field(entry.comment, '完整评价', key: 'edit-entry-comment-$index', lines: 6),
      _field(
        entry.recommender,
        '推荐人 / 书评人',
        key: 'edit-entry-recommender-$index',
      ),
      _field(entry.channel, '书目来源', key: 'edit-entry-channel-$index'),
      _field(
        entry.date,
        '评价日期 YYYY-MM-DD',
        key: 'edit-entry-date-$index',
        validator: (String value) => validContentDate(value) ? null : '日期无效',
      ),
      _field(
        entry.sourceUrl,
        '评价来源链接',
        key: 'edit-entry-source-$index',
        validator: (String value) => validContentUrl(value) ? null : '链接无效',
      ),
      _field(
        entry.wordCount,
        '小说字数（不是评价长度）',
        key: 'edit-entry-wordcount-$index',
        validator: (String value) =>
            value.isEmpty ||
                int.tryParse(value) != null && int.parse(value) >= 0
            ? null
            : '请输入非负整数字数',
      ),
      _field(
        entry.bookGrade,
        '原始评级颜色（可选）',
        key: 'edit-entry-grade-$index',
        validator: (String value) =>
            value.isEmpty || RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
            ? null
            : '请输入 #RRGGBB',
      ),
      _category(
        entry.category,
        (String value) => setState(() {
          entry.category = value;
          entry.bookGrade.text = value == kRecommendKind
              ? '#11850A'
              : value == CategoryKind.avoid
              ? '#FF0000'
              : '';
          _dirty = true;
        }),
        key: 'edit-entry-category-$index',
      ),
      if (_floors.isNotEmpty)
        DropdownButtonFormField<int>(
          key: ValueKey<String>('edit-entry-floor-$index-${_floors.length}'),
          initialValue: entry.floorIndex.clamp(0, _floors.length - 1),
          isExpanded: true,
          decoration: const InputDecoration(labelText: '对应正文段落'),
          items: <DropdownMenuItem<int>>[
            for (int floorIndex = 0; floorIndex < _floors.length; floorIndex++)
              DropdownMenuItem<int>(
                value: floorIndex,
                child: Text('第 ${floorIndex + 1} 段'),
              ),
          ],
          onChanged: (int? value) => setState(() {
            entry.floorIndex = value ?? 0;
            _dirty = true;
          }),
        ),
      TextButton(
        key: ValueKey<String>('edit-remove-entry-$index'),
        onPressed: () => setState(() {
          _retired.add(_entries.removeAt(index));
          _dirty = true;
        }),
        child: const Text('移除书目（保留原文）'),
      ),
    ],
  );

  Future<void> _editImageUrl(_FloorFields floor, int? index) async {
    final TextEditingController controller = TextEditingController(
      text: index == null || floor.images[index].embedded
          ? ''
          : floor.images[index].url,
    );
    final String? value = await showDialog<String>(
      context: context,
      animationStyle: dialogAnimationStyle(context),
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('图片链接'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'HTTP / HTTPS 图片地址'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (validContentUrl(controller.text.trim()) &&
                  controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    _retired.add(_ControllerFields(controller));
    if (!mounted || value == null) return;
    setState(() {
      final ContentImageDraft image = ContentImageDraft(
        id: index == null ? null : floor.images[index].id,
        url: value,
      );
      if (index == null) {
        floor.images.add(image);
      } else {
        floor.images[index] = image;
      }
      _dirty = true;
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? key,
    int lines = 1,
    bool required = false,
    String? Function(String value)? validator,
  }) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.of(context).space2),
    child: TextFormField(
      key: key == null ? null : ValueKey<String>(key),
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : null,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      validator: (String? value) => required && (value ?? '').trim().isEmpty
          ? '请填写$label'
          : validator?.call((value ?? '').trim()),
    ),
  );

  Widget _category(
    String value,
    ValueChanged<String> change, {
    required String key,
  }) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.of(context).space2),
    child: DropdownButtonFormField<String>(
      key: ValueKey<String>(key),
      initialValue:
          <String>{...CategoryKind.all, kRecommendKind}.contains(value)
          ? value
          : CategoryKind.scan,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '类别'),
      items: <DropdownMenuItem<String>>[
        for (final String kind in <String>[
          CategoryKind.scan,
          kRecommendKind,
          CategoryKind.avoid,
          CategoryKind.ask,
          CategoryKind.daily,
        ])
          DropdownMenuItem<String>(value: kind, child: Text(kind)),
      ],
      onChanged: (String? value) {
        if (value != null) change(value);
      },
    ),
  );

  Widget _section(String title, List<Widget> children) => Container(
    margin: EdgeInsets.only(bottom: AppSpacing.of(context).space4),
    padding: EdgeInsets.all(AppSpacing.of(context).cardPadding),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface,
      border: Border.all(color: AppColors.of(context).border),
      borderRadius: AppRadius.mdBorder,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: AppTypography.of(context).headline),
        SizedBox(height: AppSpacing.of(context).space3),
        ...children,
      ],
    ),
  );

  Widget _notice(String message, {bool danger = false}) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.of(context).space3),
    child: Text(
      message,
      style: AppTypography.of(context).secondary.copyWith(
        color: danger
            ? AppColors.of(context).danger
            : AppColors.of(context).textSecondary,
      ),
    ),
  );

  String _message(Object error) =>
      error is ContentEditException ? error.message : '操作失败，内容尚未保存，草稿仍在。请重试。';
}

void openContentEditor(
  BuildContext context, {
  int? postId,
  ContentDraft? draft,
}) => openCenterPage(
  context,
  ContentEditorPage(postId: postId, initialDraft: draft),
);

abstract interface class _DisposableFields {
  void dispose();
}

class _ControllerFields implements _DisposableFields {
  _ControllerFields(this.controller);
  final TextEditingController controller;
  @override
  void dispose() => controller.dispose();
}

class _PostFields implements _DisposableFields {
  _PostFields(ContentDraft draft)
    : title = TextEditingController(text: draft.title),
      author = TextEditingController(text: draft.author),
      channel = TextEditingController(text: draft.channel),
      subChannel = TextEditingController(text: draft.subChannel),
      date = TextEditingController(text: draft.date),
      sourceUrl = TextEditingController(text: draft.sourceUrl),
      category = draft.category;
  final TextEditingController title,
      author,
      channel,
      subChannel,
      date,
      sourceUrl;
  String category;
  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      title,
      author,
      channel,
      subChannel,
      date,
      sourceUrl,
    ]) {
      controller.dispose();
    }
  }
}

class _FloorFields implements _DisposableFields {
  _FloorFields(ContentFloorDraft floor)
    : id = floor.id,
      text = TextEditingController(text: floor.text),
      images = List<ContentImageDraft>.of(floor.images);
  final int? id;
  final TextEditingController text;
  final List<ContentImageDraft> images;
  ContentFloorDraft collect() => ContentFloorDraft(
    id: id,
    text: text.text,
    images: List<ContentImageDraft>.of(images),
  );
  @override
  void dispose() => text.dispose();
}

class _EntryFields implements _DisposableFields {
  _EntryFields(ContentEntryDraft entry)
    : id = entry.id,
      name = TextEditingController(text: entry.name),
      author = TextEditingController(text: entry.author),
      comment = TextEditingController(text: entry.comment),
      recommender = TextEditingController(text: entry.recommender),
      channel = TextEditingController(text: entry.channel),
      date = TextEditingController(text: entry.date),
      sourceUrl = TextEditingController(text: entry.sourceUrl),
      wordCount = TextEditingController(
        text: entry.wordCount?.toString() ?? '',
      ),
      bookGrade = TextEditingController(text: entry.bookGrade ?? ''),
      floorIndex = entry.floorIndex,
      category = entry.category;
  final int? id;
  final TextEditingController name,
      author,
      comment,
      recommender,
      channel,
      date,
      sourceUrl,
      wordCount,
      bookGrade;
  int floorIndex;
  String category;
  ContentEntryDraft collect() => ContentEntryDraft(
    id: id,
    name: name.text,
    author: author.text,
    comment: comment.text,
    recommender: recommender.text,
    channel: channel.text,
    date: date.text,
    sourceUrl: sourceUrl.text,
    wordCount: int.tryParse(wordCount.text),
    bookGrade: bookGrade.text.trim().isEmpty ? null : bookGrade.text.trim(),
    floorIndex: floorIndex,
    category: category,
  );
  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      name,
      author,
      comment,
      recommender,
      channel,
      date,
      sourceUrl,
      wordCount,
      bookGrade,
    ]) {
      controller.dispose();
    }
  }
}
