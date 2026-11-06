import 'dart:convert';
import 'dart:io';

import 'package:booksift/book_sources/forum_source.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/check_live_book_source.dart <base> <browser-state-file> <query> [post-url]',
    );
    exitCode = 64;
    return;
  }
  final Uri base = validateForumBase(arguments[0]);
  final Map<String, dynamic> state =
      jsonDecode(await File(arguments[1]).readAsString())
          as Map<String, dynamic>;
  final String cookie = (state['cookies'] as List)
      .cast<Map<String, dynamic>>()
      .where((item) {
        final String domain = item['domain'] as String;
        return domain == base.host ||
            (domain.startsWith('.') && base.host.endsWith(domain));
      })
      .map((item) => '${item['name']}=${item['value']}')
      .join('; ');
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
  final String? proxy = Platform.environment['BOOKSIFT_TEST_PROXY'];
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final HttpClient client = HttpClient();
      client.findProxy = (_) => proxy == null ? 'DIRECT' : 'PROXY $proxy';
      return client;
    },
  );
  int responseIndex = 0;
  final String? diagnostics = Platform.environment['BOOKSIFT_TEST_DIAGNOSTICS'];
  if (diagnostics != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final Object? data = response.data;
          if (data is List<int>) {
            File(
              '$diagnostics/response-${responseIndex++}.html',
            ).writeAsBytesSync(data);
          }
          stdout.writeln(
            'http_status=${response.statusCode} path=${response.realUri.path} bytes=${data is List ? data.length : 0}',
          );
          handler.next(response);
        },
      ),
    );
  }
  final ForumSourceClient client = ForumSourceClient(dio: dio);
  try {
    if (arguments[2] == ':resolve:ss') {
      stdout.writeln('resolved=${await client.resolve(ForumSource.soushu)}');
    } else if (arguments.length > 3) {
      final List<BookAttachment> files = await client.attachments(
        base,
        ForumBook('acceptance', Uri.parse(arguments[3])),
        cookie: cookie,
      );
      stdout.writeln('attachments=${files.length}');
      if (files.isNotEmpty) {
        final String? destination =
            Platform.environment['BOOKSIFT_TEST_DOWNLOAD_DIR'];
        if (destination != null) {
          final File downloaded = await client.download(
            base,
            files.first,
            Directory(destination),
            cookie: cookie,
            cancelToken: CancelToken(),
          );
          stdout.writeln('download_bytes=${await downloaded.length()}');
        }
      }
    } else {
      final List<ForumBook> books = await client.search(
        base,
        arguments[2],
        cookie: cookie,
      );
      stdout.writeln('results=${books.length}');
      for (final ForumBook book in books) {
        stdout.writeln(
          jsonEncode(<String, String>{
            'title': book.title,
            'url': book.url.toString(),
          }),
        );
      }
    }
  } on SourceFailure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on DioException catch (error) {
    stderr.writeln(
      'network=${error.type.name} status=${error.response?.statusCode}',
    );
    exitCode = 1;
  } finally {
    dio.close(force: true);
  }
}
