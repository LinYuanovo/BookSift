import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';

abstract interface class ForumFileTransfer {
  Future<Uri?> save(
    ForumSourceClient client,
    Uri base,
    BookAttachment attachment,
    String cookie,
    CancelToken cancelToken,
    void Function(int, int) onProgress,
  );
}

class NativeForumFileTransfer implements ForumFileTransfer {
  @override
  Future<Uri?> save(
    ForumSourceClient client,
    Uri base,
    BookAttachment attachment,
    String cookie,
    CancelToken cancelToken,
    void Function(int, int) onProgress,
  ) async {
    final Directory temporary = await (await getTemporaryDirectory())
        .createTemp('booksift-book-');
    try {
      final File file = await client.download(
        base,
        attachment,
        temporary,
        cookie: cookie,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      final bytes = await file.readAsBytes();
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      onProgress(-1, bytes.length);
      return await FilePicker.saveFile(
        fileName: attachment.name.replaceAll(
          RegExp(r'[<>:"/\\|?*\x00-\x1f]'),
          '_',
        ),
        bytes: bytes,
        mimeType: 'application/octet-stream',
        dialogTitle: '保存书籍到指定位置',
      );
    } finally {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  }
}

final forumFileTransferProvider = Provider<ForumFileTransfer>(
  (ref) => NativeForumFileTransfer(),
);

Future<void> showForumDownload(
  BuildContext context,
  ForumSourceSettings settings,
  BookAttachment attachment,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  animationStyle: dialogAnimationStyle(context),
  builder: (_) => _ForumDownload(settings: settings, attachment: attachment),
);

class _ForumDownload extends ConsumerStatefulWidget {
  const _ForumDownload({required this.settings, required this.attachment});
  final ForumSourceSettings settings;
  final BookAttachment attachment;
  @override
  ConsumerState<_ForumDownload> createState() => _ForumDownloadState();
}

class _ForumDownloadState extends ConsumerState<_ForumDownload> {
  final CancelToken _cancel = CancelToken();
  String _message = '准备下载…';
  double? _progress;
  bool _saving = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final Uri? saved = await ref.read(forumFileTransferProvider).save(
        ref.read(forumClientProvider),
        widget.settings.base!,
        widget.attachment,
        widget.settings.cookie,
        _cancel,
        (received, total) {
          if (!mounted) return;
          setState(() {
            _saving = received < 0;
            _progress = _saving
                ? 1
                : total > 0
                ? (received / total).clamp(0, 1)
                : null;
            _message = _saving
                ? '选择保存位置…'
                : '已下载 ${(received / 1048576).toStringAsFixed(1)} MB';
          });
        },
      );
      if (mounted) {
        setState(() => _message = saved == null ? '已取消保存' : '已保存到：$saved');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = _cancel.isCancelled
              ? '下载已取消'
              : error is SourceFailure
              ? error.message
              : '下载或保存失败，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _done,
    child: AppDialog(
      title: widget.attachment.name,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_done)
            LinearProgressIndicator(
              value:
                  _progress ??
                  (AppMotionTheme.of(context).reduceMotion ? 0 : null),
              color: AppColors.of(context).accent,
            ),
          SizedBox(height: AppSpacing.of(context).space3),
          Text(_message),
        ],
      ),
      actions: <Widget>[
        if (!_done && !_saving)
          TextButton(
            onPressed: () => _cancel.cancel(),
            child: const Text('取消下载'),
          ),
        if (_done)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
      ],
    ),
  );
}
