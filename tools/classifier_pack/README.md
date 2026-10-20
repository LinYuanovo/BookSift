# BooksSift classifier source package

This package contains the pure-Dart classifier implementation, the book-entry label integration, the classifier's book-name dictionary (`assets/dict/book_dict.txt`), and a standalone regression probe. The classifier rules are compiled into lib/classify/src/rules.dart; there is no external rule service or model dependency.

After extracting the archive, run the standalone examples from the archive root with: dart test/entry_kind_smoke.dart

To apply the source to a BooksSift checkout, copy lib/classify/, assets/dict/book_dict.txt, and lib/data/repo/queries.dart to the same paths under app/, then copy app_test/classify/entry_kind_test.dart to app/test/classify/entry_kind_test.dart. From the repository root, run: pwsh tools/run_tests_safe.ps1 -TestTarget test/classify/entry_kind_test.dart

app_test/classify/entry_kind_test.dart is the Flutter/SQLite integration regression test.
