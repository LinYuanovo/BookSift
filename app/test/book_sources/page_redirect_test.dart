import 'package:booksift/book_sources/page_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Uri current = Uri.parse(
    'https://forum.example/forum.php?mod=viewthread&tid=385404',
  );
  test('resolves bounded literal redirects without executing page scripts', () {
    const String script = '''<script>
function piece(){'piece';function nested(){return 'forum.php'};return nested();}
function callerName(arg){function id(){return getName();};return id();return 'unused';}
var method='replace';var target=location;
target[method]('/'+piece()+'?mod=viewthread&t'+callerName('ignored')+'=385404&_dsign='+(function(value){return (function(other){return other;})(value);})('c99b5c9a'));
</script>''';
    expect(
      signedForumRedirect(script, current)?.queryParameters['_dsign'],
      'c99b5c9a',
    );
    expect(
      signedForumRedirect(
        "<script>location='https://other.example/forum.php?mod=viewthread&tid=385404&_dsign=c99b5c9a';</script>",
        current,
      ),
      isNull,
    );
    expect(
      signedForumRedirect(
        "<script>location=fetch('/secrets');</script>",
        current,
      ),
      isNull,
    );
    expect(
      signedForumRedirect(
        "<script>location='/forum.php?mod=viewthread&tid=9&_dsign=c99b5c9a';</script>",
        current,
      ),
      isNull,
    );
    expect(
      signedForumRedirect(
        "<script>location='/forum.php?mod=viewthread&tid=385404&action=delete&_dsign=c99b5c9a';</script>",
        current,
      ),
      isNull,
    );
    expect(
      signedForumRedirect(
        "<script>function recurse(){return recurse();} location=recurse();</script>",
        current,
      ),
      isNull,
    );
  });

  test('public redirects parse data and never execute page JavaScript', () {
    expect(
      publicPageRedirect(
        '<meta http-equiv="refresh" content="0;url=http://landing.example/o/">',
        current,
      )?.host,
      'landing.example',
    );
    expect(
      publicPageRedirect('<iframe src="/landing"></iframe>', current)?.path,
      '/landing',
    );
    expect(
      publicPageRedirect(
        '<script>location=fetch("https://other.example")</script>',
        current,
      ),
      isNull,
    );
    expect(
      publicPageRedirect(
        '<script>location="javascript:alert(1)"</script>',
        current,
      ),
      isNull,
    );
  });

}
