import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reading_session.dart';
import 'repo/database_provider.dart';

final readingSessionProvider = Provider<ReadingSessionStore>((ref) {
  final ReadingSessionStore store = ReadingSessionStore(ref.watch(appDatabaseProvider));
  ref.onDispose(store.dispose);
  return store;
});

final readingSessionPromptedProvider = StateProvider<bool>((ref) => false);
