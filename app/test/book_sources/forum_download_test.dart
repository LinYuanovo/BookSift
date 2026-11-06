import 'dart:async';

import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/features/search/forum_download.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transfer implements ForumFileTransfer {
  final Completer<Uri?> result = Completer<Uri?>();
  void Function(int, int)? progress;
  CancelToken? cancellation;
  @override
  Future<Uri?> save(
    ForumSourceClient client,
    Uri base,
    BookAttachment attachment,
    String cookie,
    CancelToken cancelToken,
    void Function(int, int) onProgress,
  ) {
    cancellation = cancelToken;
    progress = onProgress;
    cancelToken.whenCancel.then((error) {
      if (!result.isCompleted) result.completeError(error);
    });
    return result.future;
  }
}

void main() {
  Future<_Transfer> mount(WidgetTester tester) async {
    final transfer = _Transfer();
    final base = Uri.parse('https://forum.example/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [forumFileTransferProvider.overrideWithValue(transfer)],
        child: MaterialApp(
          theme: BookTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showForumDownload(
                context,
                ForumSourceSettings(base: base),
                BookAttachment('测试.txt', base.resolve('attachment.php'), base),
              ),
              child: const Text('下载'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return transfer;
  }

  testWidgets('download reaches native save phase and reports its chosen URI', (
    tester,
  ) async {
    final transfer = await mount(tester);
    transfer.progress!(256, 1024);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    transfer.progress!(-1, 1024);
    await tester.pump();
    expect(find.text('选择保存位置…'), findsOneWidget);
    expect(find.text('取消下载'), findsNothing);
    transfer.result.complete(Uri.parse('content://documents/book.txt'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('已保存到：content://documents/book.txt'),
      findsOneWidget,
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel download cancels network; cancel native save is not success',
    (tester) async {
      final transfer = await mount(tester);
      await tester.tap(find.text('取消下载'));
      await tester.pumpAndSettle();
      expect(transfer.cancellation!.isCancelled, isTrue);
      expect(find.text('下载已取消'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      final second = await mount(tester);
      second.result.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('已取消保存'), findsOneWidget);
      expect(find.textContaining('已保存到'), findsNothing);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
    },
  );
}
