import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/demo_data.dart';
import '../support/harness.dart';

class _MutableCollectNotifier extends FakeCollectRunNotifier {
  _MutableCollectNotifier(CollectRunState initial)
      : _current = initial,
        super(initial: initial);

  CollectRunState _current;

  @override
  CollectRunState build() => _current;

  void emit(CollectRunState next) {
    _current = next;
    state = next;
  }
}

Post _collectedPost({
  required int id,
  required String date,
  required String title,
}) {
  return Post(
    id: id,
    tid: id,
    title: title,
    author: '采集人',
    portrait: '',
    date: date,
    channel: 'yy小说吧',
    postType: CategoryKind.scan,
    postKind: CategoryKind.scan,
    recommendFlag: 1,
    floorCount: 1,
    imageCount: 0,
    origin: Origin.collected,
  );
}

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  testWidgets('采集成功后首页自动重新查询时间线', (WidgetTester tester) async {
    final _MutableCollectNotifier collect = _MutableCollectNotifier(
      const CollectRunState(
        phase: CollectPhase.running,
        forums: <ForumRunState>[
          ForumRunState(fname: 'yy小说吧', status: ForumStatus.parsing),
        ],
      ),
    );
    useSurface(tester);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const HomePage(),
        extraOverrides: collectTestOverrides(notifier: collect),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('【扫书】yy小说吧四月下旬合集'), findsOneWidget);
    final int before = repo.calls['timelinePosts'] ?? 0;

    repo.lib.posts.add(
      _collectedPost(id: 99999, date: '2026-10-17', title: '【自采】刷新后可见'),
    );
    collect.emit(
      CollectRunState(
        phase: CollectPhase.idle,
        finishedAt: DateTime(2026, 10, 17, 12),
        forums: const <ForumRunState>[
          ForumRunState(fname: 'yy小说吧', status: ForumStatus.done),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.calls['timelinePosts'], greaterThan(before));
    expect(find.text('【自采】刷新后可见'), findsOneWidget);
  });

  testWidgets('取消收尾不触发首页刷新', (WidgetTester tester) async {
    final _MutableCollectNotifier collect = _MutableCollectNotifier(
      const CollectRunState(
        phase: CollectPhase.running,
        forums: <ForumRunState>[
          ForumRunState(fname: 'yy小说吧', status: ForumStatus.parsing),
        ],
      ),
    );
    useSurface(tester);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const HomePage(),
        extraOverrides: collectTestOverrides(notifier: collect),
      ),
    );
    await tester.pumpAndSettle();
    final int before = repo.calls['timelinePosts'] ?? 0;

    collect.emit(
      CollectRunState(
        phase: CollectPhase.idle,
        finishedAt: DateTime(2026, 10, 17, 12),
        forums: const <ForumRunState>[
          ForumRunState(fname: 'yy小说吧', status: ForumStatus.canceled),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.calls['timelinePosts'], before);
  });

  testWidgets('点击自采提示：留在首页刷新并清除提示', (WidgetTester tester) async {
    final FakeLibrary library = demoLibrary();
    repo = FakeBookRepository(
      library: FakeLibrary(
        posts: library.posts,
        floors: library.floors,
        entries: library.entries,
        groups: library.groups,
        newContentCount: 3,
      ),
    );
    useSurface(tester, height: 1200);
    await tester.pumpWidget(
      testApp(repo, home: const HomePage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('自采新内容 +3 条'), findsOneWidget);
    final int before = repo.calls['timelinePosts'] ?? 0;

    await tester.tap(find.text('自采新内容 +3 条'));
    await tester.pumpAndSettle();

    expect(repo.calls['timelinePosts'], greaterThan(before));
    expect(repo.calls['clearNewContentCount'], 1);
    expect(find.text('自采新内容 +3 条'), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
