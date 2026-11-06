import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/core/nav/page_transition.dart';
import 'package:booksift/core/widgets/app_dialog.dart';
import 'package:booksift/core/widgets/app_text_field.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/search/book_source_page.dart';
import 'package:booksift/theme/app_accent.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_radius.dart';
import 'package:booksift/theme/app_spacing.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SourceClient extends ForumSourceClient {
  Completer<List<ForumBook>>? pending;
  bool fail = false;

  @override
  Future<List<ForumBook>> search(
    Uri base,
    String query, {
    String cookie = '',
  }) async {
    if (fail) throw const SourceFailure('网站要求登录，请更新登录状态');
    return pending?.future ??
        <ForumBook>[
          ForumBook(
            '《红楼梦》完整校订版与附录 · 一个需要换行显示的长书名',
            base.resolve('thread-1.html'),
          ),
          ForumBook('《孙子兵法》精校版', base.resolve('thread-2.html')),
        ];
  }

  @override
  Future<List<BookAttachment>> attachments(
    Uri base,
    ForumBook book, {
    String cookie = '',
  }) async => <BookAttachment>[
    BookAttachment(
      '红楼梦（完整校订版·含附录和注释）.epub',
      base.resolve('attachment.php'),
      book.url,
    ),
  ];
}

Future<void> _snapshot(WidgetTester tester, GlobalKey key, String name) async {
  final String? directory = Platform.environment['BOOKSIFT_UI_SNAPSHOTS'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _mount(
  WidgetTester tester,
  _SourceClient client,
  ThemeData theme, {
  double width = 390,
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => client.dio.close(force: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        forumClientProvider.overrideWithValue(client),
        for (final ForumSource source in ForumSource.values)
          forumSettingsProvider(source).overrideWith(
            (ref) async =>
                ForumSourceSettings(base: Uri.parse('https://forum.example/')),
          ),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: capture, child: child),
        ),
        home: const BookSourcePage(initialQuery: '红楼梦'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String? fontPath = Platform.environment['BOOKSIFT_UI_FONT'];
  final FontFamilySet visualFamilies = fontPath == null
      ? FontFamilySet.standard
      : FontFamilySet.fromFamilyOf((role) => 'UiAudit');
  setUpAll(() async {
    if (fontPath == null) return;
    final FontLoader loader = FontLoader('UiAudit');
    loader.addFont(
      File(fontPath).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await loader.load();
  });
  for (final (Brightness brightness, double width, double scale) configuration
      in <(Brightness, double, double)>[
        (Brightness.light, 390, 1),
        (Brightness.dark, 320, 1.6),
        (Brightness.light, 1280, 1),
      ]) {
    testWidgets(
      'source page tokens and dialogs ${configuration.$1.name} ${configuration.$2} scale ${configuration.$3}',
      (tester) async {
        final _SourceClient client = _SourceClient();
        final ThemeData theme = BookTheme.of(configuration.$1, visualFamilies);
        final AppColors colors = theme.extension<AppColors>()!;
        final AppTypography typography = theme.extension<AppTypography>()!;
        final GlobalKey capture = GlobalKey();
        await _mount(
          tester,
          client,
          theme,
          width: configuration.$2,
          scale: configuration.$3,
          capture: capture,
        );
        expect(find.byType(SegmentedPill<ForumSource>), findsOneWidget);
        expect(find.byType(SegmentedButton<ForumSource>), findsNothing);
        expect(find.byType(Icon), findsNothing);
        final TextField field = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(field.style, typography.body.copyWith(color: colors.text));
        expect(field.decoration!.border, InputBorder.none);
        await tester.tap(find.byTooltip('搜索书源'));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsNWidgets(2));
        expect(
          tester.widget<Text>(find.textContaining('一个需要换行')).style,
          typography.cardTitle.copyWith(color: colors.text),
        );
        await _snapshot(
          tester,
          capture,
          'results-${configuration.$1.name}-${configuration.$2}',
        );
        await tester.ensureVisible(find.byType(ListTile).first);
        await tester.tap(find.byType(ListTile).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SimpleDialogOption), findsOneWidget);
        expect(find.byType(Icon), findsNothing);
        expect(tester.takeException(), isNull);
        await _snapshot(
          tester,
          capture,
          'attachments-${configuration.$1.name}-${configuration.$2}',
        );
        Navigator.of(tester.element(find.byType(SimpleDialogOption))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('书源设置'));
        await tester.pumpAndSettle();
        expect(find.byType(AppDialog), findsOneWidget);
        expect(find.byType(AppTextField), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        await _snapshot(
          tester,
          capture,
          'settings-${configuration.$1.name}-${configuration.$2}',
        );
        final Finder address = find
            .descendant(
              of: find.byType(AppDialog),
              matching: find.byType(TextField),
            )
            .first;
        await tester.ensureVisible(address);
        await tester.tap(address);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('取消'));
        await tester.tap(find.text('取消'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'accent/font tokens, focus, loading and error remain project styles',
    (tester) async {
      final _SourceClient client = _SourceClient()
        ..pending = Completer<List<ForumBook>>();
      final ThemeData theme = BookTheme.of(
        Brightness.dark,
        const FontFamilySet(
          body: 'AuditBody',
          caption: 'AuditCaption',
          headline: 'AuditHeading',
        ),
        AppAccentTheme.derived(
          id: 'test',
          label: 'test',
          seed: const Color(0xff396cb0),
        ),
        true,
      );
      final AppColors colors = theme.extension<AppColors>()!;
      final AppTypography typography = theme.extension<AppTypography>()!;
      await _mount(tester, client, theme);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final AnimatedContainer input = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AppTextField),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final BoxDecoration decoration = input.decoration! as BoxDecoration;
      expect(decoration.color, colors.surfaceRaised);
      expect(decoration.borderRadius, AppRadius.xlBorder);
      expect((decoration.border! as Border).top.color, colors.accent);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontFamily,
        'AuditBody',
      );
      await tester.tap(find.byTooltip('搜索书源'));
      await tester.pump();
      final LinearProgressIndicator progress = tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
      expect(progress.color, colors.accent);
      expect(progress.backgroundColor, colors.surfaceSunken);
      expect(progress.borderRadius, AppRadius.pillBorder);
      expect(progress.minHeight, AppSpacing.standard.space1);
      expect(
        progress.value,
        0,
        reason: 'reduced motion has no looping indicator',
      );
      await tester.tap(find.text('搜书吧'), warnIfMissed: false);
      expect(
        tester
            .widget<SegmentedPill<ForumSource>>(
              find.byType(SegmentedPill<ForumSource>),
            )
            .selected,
        ForumSource.shangxiang,
      );
      client.pending!.complete(<ForumBook>[]);
      await tester.pumpAndSettle();
      client.fail = true;
      await tester.tap(find.byTooltip('搜索书源'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('网站要求登录，请更新登录状态')).style,
        typography.secondary.copyWith(color: colors.danger),
      );
      expect(find.byType(Icon), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry uses project motion route and SVG back action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: BookTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openBookSourcePage(context, initialQuery: '三体'),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final ModalRoute<dynamic>? route = ModalRoute.of(
      tester.element(find.byType(BookSourcePage)),
    );
    expect(route?.settings, isA<MotionPage<void>>());
    expect(
      find.descendant(of: find.byTooltip('返回'), matching: find.byType(AppIcon)),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(BookSourcePage), findsNothing);
  });
}
