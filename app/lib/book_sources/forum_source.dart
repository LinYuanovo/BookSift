import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'page_redirect.dart';

enum ForumSource {
  shangxiang('尚香书苑', 'https://sxsy.pw/'),
  soushu('搜书吧', 'https://soushu2025.com/');

  const ForumSource(this.label, this.navigationUrl);
  final String label;
  final String navigationUrl;

  List<String> get navigationUrls => this == ForumSource.soushu
      ? <String>[
          navigationUrl,
          'https://soushu2022.com/',
          'https://soushu2030.com/',
          'https://soushu2035.com/',
        ]
      : <String>[navigationUrl];
}

class SourceFailure implements Exception {
  const SourceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ForumBook {
  const ForumBook(this.title, this.url);
  final String title;
  final Uri url;
}

class BookAttachment {
  const BookAttachment(this.name, this.url, this.postUrl);
  final String name;
  final Uri url;
  final Uri postUrl;
}

Uri validateForumBase(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const SourceFailure('请输入 HTTPS 论坛首页地址');
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

Uri? navigationTarget(String source, Uri page, ForumSource site) {
  final Document document = html.parse(source);
  final String selector = site == ForumSource.shangxiang
      ? '#enterButton[href], a[href*="sxsy"][href]'
      : 'a.link[href], a[href]';
  for (final Element anchor in document.querySelectorAll(selector)) {
    final String label = anchor.text.trim();
    if (site == ForumSource.soushu &&
        !label.contains('搜书吧') &&
        !label.contains('最新地址') &&
        !label.contains('进入')) {
      continue;
    }
    final Uri target = page.resolve(anchor.attributes['href']!);
    if (target.scheme == 'https' &&
        target.host != page.host &&
        target.userInfo.isEmpty &&
        !<String>['t.me', 'telegram.me'].contains(target.host)) {
      return target.replace(path: '/', query: '', fragment: '');
    }
  }
  return null;
}

List<ForumBook> parseForumResults(String source, Uri base) {
  final Document document = html.parse(source);
  final Set<String> seen = <String>{};
  return <ForumBook>[
    for (final Element anchor in document.querySelectorAll(
      'h3.xs3 a[href], .slst h3 a[href]',
    ))
      if (anchor.text.trim().isNotEmpty &&
          base.resolve(anchor.attributes['href']!).origin == base.origin &&
          seen.add(base.resolve(anchor.attributes['href']!).toString()))
        ForumBook(anchor.text.trim(), base.resolve(anchor.attributes['href']!)),
  ];
}

List<BookAttachment> parseBookAttachments(String source, Uri postUrl) {
  final Document document = html.parse(source);
  final Set<String> seen = <String>{};
  final List<BookAttachment> attachments = <BookAttachment>[];
  for (final Element anchor in document.querySelectorAll('a[href]')) {
    final String href = anchor.attributes['href']!;
    if (!href.contains('mod=attachment') && !href.contains('attachment.php')) {
      continue;
    }
    final Uri target = postUrl.resolve(href);
    if (target.origin != postUrl.origin || !seen.add(target.toString())) {
      continue;
    }
    String name = anchor.text.trim().isEmpty
        ? anchor.attributes['title'] ?? ''
        : anchor.text.trim();
    if (name == '下载' || name == '下载附件') {
      Element? block = anchor.parent;
      while (block != null && block.localName != 'dd') {
        block = block.parent;
      }
      final String label = block?.querySelector('p')?.text.trim() ?? '';
      name =
          RegExp(
            r'(.+?\.(?:txt|epub|pdf|mobi|azw3|zip|7z|rar))',
            caseSensitive: false,
          ).firstMatch(label)?[1]?.trim() ??
          name;
    }
    if (!RegExp(
      r'\.(txt|epub|pdf|mobi|azw3|zip|7z|rar)$',
      caseSensitive: false,
    ).hasMatch(name)) {
      continue;
    }
    attachments.add(BookAttachment(name, target, postUrl));
  }
  return attachments;
}

class ForumSourceClient {
  ForumSourceClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio dio;
  static const int maxDownloadBytes = 64 * 1024 * 1024;
  final Map<String, Map<String, String>> _cookies =
      <String, Map<String, String>>{};

  Map<String, String> _initialCookies(String value) => <String, String>{
    for (final String part in value.split(';'))
      if (part.indexOf('=') > 0)
        part.substring(0, part.indexOf('=')).trim(): part
            .substring(part.indexOf('=') + 1)
            .trim(),
  };

  String _cookieHeader(Uri base) =>
      (_cookies[base.origin] ?? <String, String>{}).entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');

  void _acceptCookies(Uri base, Headers headers) {
    for (final String raw in headers['set-cookie'] ?? <String>[]) {
      try {
        final Cookie cookie = Cookie.fromSetCookieValue(raw);
        final Map<String, String> jar = _cookies.putIfAbsent(
          base.origin,
          () => <String, String>{},
        );
        if (cookie.maxAge == 0 ||
            (cookie.expires?.isBefore(DateTime.now()) ?? false)) {
          jar.remove(cookie.name);
        } else {
          jar[cookie.name] = cookie.value;
        }
      } catch (_) {}
    }
  }

  Future<Response<List<int>>> _request(
    Uri uri, {
    Uri? credentialOrigin,
    String cookie = '',
    String? body,
    Uri? referer,
    CancelToken? cancelToken,
    bool publicNavigation = false,
  }) async {
    for (int hop = 0; hop < 6; hop++) {
      if ((uri.scheme != 'https' &&
              !(publicNavigation && uri.scheme == 'http')) ||
          uri.userInfo.isNotEmpty ||
          (credentialOrigin != null && uri.origin != credentialOrigin.origin)) {
        throw const SourceFailure('论坛跳转到了其他地址，请重新确认最新地址和登录状态');
      }
      final Response<List<int>> response = await dio.request<List<int>>(
        uri.toString(),
        data: body,
        cancelToken: cancelToken,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) =>
              status != null &&
              (status < 400 || publicNavigation && status == 404),
          headers: <String, String>{
            'User-Agent': 'Mozilla/5.0 BookSift/1.0',
            if (credentialOrigin?.origin == uri.origin &&
                _cookieHeader(uri).isNotEmpty)
              'Cookie': _cookieHeader(uri),
            if (referer != null) 'Referer': referer.toString(),
            if (body != null)
              'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      if (credentialOrigin?.origin == uri.origin) {
        _acceptCookies(uri, response.headers);
      }
      if ((response.statusCode ?? 0) >= 300 &&
          (response.statusCode ?? 0) < 400) {
        final String? location = response.headers.value('location');
        if (location == null) throw const SourceFailure('论坛返回了无效跳转');
        uri = uri.resolve(location);
        body = null;
        continue;
      }
      if (body == null && credentialOrigin != null) {
        final Uri? signed = signedForumRedirect(_decode(response), uri);
        if (signed != null) {
          uri = signed;
          continue;
        }
      }
      return response;
    }
    throw const SourceFailure('论坛跳转次数过多');
  }

  String _decode(Response<List<int>> response) {
    final List<int> bytes = response.data ?? <int>[];
    final String probe = latin1.decode(
      bytes.take(4096).toList(),
      allowInvalid: true,
    );
    final String encoding = '${response.headers.value('content-type')} $probe';
    return RegExp(
          r'(?:charset\s*=\s*["\x27]?)(gbk|gb2312|gb18030)',
          caseSensitive: false,
        ).hasMatch(encoding)
        ? gbk.decode(bytes)
        : utf8.decode(bytes, allowMalformed: true);
  }

  void _checkPage(String source) {
    final Document document = html.parse(source);
    if (document.querySelector('input[type=password]') != null) {
      throw const SourceFailure('此书源需要登录，请在书源设置中保存该地址的登录 Cookie');
    }
    final String text = document.body?.text ?? '';
    if (text.contains('验证码') &&
        document.querySelector('input[name*=seccode]') != null) {
      throw const SourceFailure('网站要求验证码，请在浏览器完成验证后更新登录状态');
    }
    if (text.contains('搜索间隔') || text.contains('两次搜索')) {
      throw const SourceFailure('搜索过于频繁，请稍后再试');
    }
  }

  Future<Uri> resolve(ForumSource site) async {
    for (final String address in site.navigationUrls) {
      for (final String scheme in <String>[
        'https',
        if (site == ForumSource.soushu) 'http',
      ]) {
        Uri next = Uri.parse(address).replace(scheme: scheme);
        final Set<Uri> visited = <Uri>{};
        final CancelToken cancellation = CancelToken();
        final Timer deadline = Timer(
          const Duration(seconds: 18),
          () => cancellation.cancel(),
        );
        try {
          for (int hop = 0; hop < 5 && visited.add(next); hop++) {
            final Response<List<int>> response = await _request(
              next,
              publicNavigation: true,
              cancelToken: cancellation,
            );
            final String source = _decode(response);
            final Uri? target = navigationTarget(
              source,
              response.realUri,
              site,
            );
            if (target != null) {
              final Uri base = validateForumBase(
                target.toString().replaceAll(RegExp(r'[?#]+$'), ''),
              );
              final Response<List<int>> check = await _request(
                base.resolve('search.php?mod=forum'),
                cancelToken: cancellation,
              );
              final String forum = _decode(check);
              if (forum.contains('formhash') &&
                  (forum.contains('srchtxt') || forum.contains('password'))) {
                return base;
              }
            }
            final Uri? redirect = publicPageRedirect(source, response.realUri);
            if (redirect == null) break;
            next = redirect;
          }
        } on DioException {
          continue;
        } on SourceFailure {
          continue;
        } finally {
          deadline.cancel();
        }
      }
    }
    throw const SourceFailure('导航地址暂不可用，请打开导航页或填写最新地址');
  }

  Future<List<ForumBook>> search(
    Uri base,
    String query, {
    String cookie = '',
  }) async {
    _cookies[base.origin] = _initialCookies(cookie);
    final Uri endpoint = base.resolve('search.php?mod=forum');
    final Response<List<int>> form = await _request(
      endpoint,
      credentialOrigin: base,
      cookie: cookie,
    );
    final String page = _decode(form);
    _checkPage(page);
    final String? token = html
        .parse(page)
        .querySelector('input[name=formhash]')
        ?.attributes['value'];
    if (token == null || token.isEmpty) {
      throw const SourceFailure('未找到搜索表单，请检查登录状态或在浏览器搜索');
    }
    final bool legacy = RegExp(
      r'charset\s*=\s*["\x27]?(gbk|gb2312)',
      caseSensitive: false,
    ).hasMatch('${form.headers.value('content-type')} $page');
    String encode(String value) =>
        (legacy ? gbk.encode(value) : utf8.encode(value))
            .map((byte) => '%${byte.toRadixString(16).padLeft(2, '0')}')
            .join();
    final String body = <String, String>{
      'mod': 'forum',
      'searchsubmit': 'yes',
      'srchtxt': query.trim(),
      'formhash': token,
    }.entries.map((entry) => '${entry.key}=${encode(entry.value)}').join('&');
    final Response<List<int>> response = await _request(
      endpoint,
      credentialOrigin: base,
      cookie: cookie,
      body: body,
      referer: endpoint,
    );
    final String result = _decode(response);
    _checkPage(result);
    final List<ForumBook> books = parseForumResults(result, response.realUri);
    if (books.isEmpty &&
        !RegExp(
          '没有找到|无相关|抱歉.*搜索|结果.*0',
        ).hasMatch(html.parse(result).body?.text ?? '')) {
      throw const SourceFailure('未能识别搜索结果，网站可能要求登录、验证或已改变页面');
    }
    return books;
  }

  Future<List<BookAttachment>> attachments(
    Uri base,
    ForumBook book, {
    String cookie = '',
  }) async {
    _cookies.putIfAbsent(base.origin, () => _initialCookies(cookie));
    final Response<List<int>> response = await _request(
      book.url,
      credentialOrigin: base,
      cookie: cookie,
    );
    final String page = _decode(response);
    _checkPage(page);
    final List<BookAttachment> files = parseBookAttachments(
      page,
      response.realUri,
    );
    if (files.isEmpty) {
      if (page.contains('action=attachpay')) {
        throw const SourceFailure('此帖附件需要站内购买，请先打开原帖确认价格并购买，再返回重试');
      }
      if (page.trimLeft().startsWith('<script') && page.contains('getName.caller')) {
        throw const SourceFailure('网站要求浏览器验证，请打开原帖完成验证后重试');
      }
      throw const SourceFailure('没有可直接下载的附件；可能需要购买、回复或更高权限，请打开原帖处理');
    }
    return files;
  }

  Future<File> download(
    Uri base,
    BookAttachment attachment,
    Directory temporary, {
    String cookie = '',
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    if (attachment.url.origin != base.origin || base.scheme != 'https') {
      throw const SourceFailure('附件地址与当前书源不一致');
    }
    final File target = File('${temporary.path}/attachment.part');
    _cookies.putIfAbsent(base.origin, () => _initialCookies(cookie));
    Uri current = attachment.url;
    try {
      Response<ResponseBody>? response;
      for (int hop = 0; hop < 6; hop++) {
        response = await dio.get<ResponseBody>(
          current.toString(),
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
            headers: <String, String>{
              'User-Agent': 'Mozilla/5.0 BookSift/1.0',
              'Referer': attachment.postUrl.toString(),
              if (_cookieHeader(base).isNotEmpty) 'Cookie': _cookieHeader(base),
            },
          ),
        );
        _acceptCookies(base, response.headers);
        if ((response.statusCode ?? 0) < 300) break;
        await response.data!.stream.listen((_) {}).cancel();
        final String? location = response.headers.value('location');
        if (location == null) throw const SourceFailure('无效附件跳转');
        current = current.resolve(location);
        if (current.origin != base.origin || current.userInfo.isNotEmpty) {
          throw const SourceFailure('附件转向站外地址，请在浏览器下载');
        }
        response = null;
      }
      if (response == null) throw const SourceFailure('附件跳转次数过多');
      final String type = response.headers.value('content-type') ?? '';
      final int total =
          int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
      if (type.contains('text/html') || total > maxDownloadBytes) {
        await response.data!.stream.listen((_) {}).cancel();
        throw const SourceFailure('返回了网页或附件超过 64 MB，请打开原帖下载');
      }
      final RandomAccessFile output = await target.open(mode: FileMode.write);
      int received = 0;
      final List<int> prefix = <int>[];
      try {
        await for (final List<int> chunk in response.data!.stream) {
          if (cancelToken.isCancelled) throw cancelToken.cancelError!;
          received += chunk.length;
          if (received > maxDownloadBytes) {
            throw const SourceFailure('附件超过 64 MB，请在浏览器下载');
          }
          if (prefix.length < 512) {
            prefix.addAll(chunk.take(512 - prefix.length));
          }
          await output.writeFrom(chunk);
          onProgress?.call(received, total);
        }
      } finally {
        await output.close();
      }
      final String start = utf8
          .decode(prefix, allowMalformed: true)
          .trimLeft()
          .toLowerCase();
      if (received == 0 ||
          start.startsWith('<!doctype html') ||
          start.startsWith('<html') ||
          start.startsWith('<script') ||
          (total > 0 && total != received)) {
        throw const SourceFailure('附件内容不完整或返回了登录/验证页面');
      }
      return target;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }
}
