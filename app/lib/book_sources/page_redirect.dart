import 'package:html/parser.dart' as html;

Uri? publicPageRedirect(String source, Uri current) {
  final document = html.parse(source);
  final String? refresh = document
      .querySelector('meta[http-equiv="refresh"], meta[http-equiv="Refresh"]')
      ?.attributes['content'];
  final String? meta = refresh == null
      ? null
      : RegExp(r'url\s*=\s*(.+)', caseSensitive: false).firstMatch(refresh)?[1];
  final String? literal = RegExp(
    r'''(?:window\.)?location(?:\.href)?\s*=\s*['"]([^'"\r\n]+)['"]''',
  ).firstMatch(source)?[1];
  final String? target =
      meta ??
      literal ??
      document.querySelector('iframe[src]')?.attributes['src'];
  if (target == null) return null;
  final Uri? next = Uri.tryParse(
    target.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), ''),
  );
  if (next == null) return null;
  final Uri resolved = current.resolveUri(next);
  return <String>['http', 'https'].contains(resolved.scheme) &&
          resolved.userInfo.isEmpty
      ? resolved
      : null;
}

Uri? signedForumRedirect(String source, Uri current) {
  if (source.length > 50000 || !source.trimLeft().startsWith('<script') ||
      current.queryParameters.containsKey('_dsign')) {
    return null;
  }
  for (final script
      in html.parse(source).querySelectorAll('script:not([src])')) {
    try {
      final _LiteralReader reader = _LiteralReader(
        _tokens(script.text),
        <String, Object>{},
      );
      for (final String candidate in reader.redirects()) {
        final Uri target = current.resolve(candidate);
        if (target.origin == current.origin &&
            target.userInfo.isEmpty &&
            !target.hasFragment &&
            target.path == current.path &&
            target.queryParameters.keys.every(
              (key) =>
                  key == '_dsign' || current.queryParameters.containsKey(key),
            ) &&
            target.queryParameters['mod'] == current.queryParameters['mod'] &&
            target.queryParameters['tid'] == current.queryParameters['tid'] &&
            RegExp(
              r'^[a-fA-F0-9]{8,64}$',
            ).hasMatch(target.queryParameters['_dsign'] ?? '')) {
          return target;
        }
      }
    } on FormatException {
      continue;
    }
  }
  return null;
}

List<String> _tokens(String source) => RegExp(
  r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[a-zA-Z_$][\w$]*|\d+|[^\s]''',
).allMatches(source).map((match) => match[0]!).toList();

class _LiteralFunction {
  const _LiteralFunction(
    this.name,
    this.parameters,
    this.body,
    this.environment,
  );
  final String name;
  final List<String> parameters;
  final List<String> body;
  final Map<String, Object> environment;
}

enum _Reference { location, window }

class _ParseBudget {
  int remaining = 20000;
}

class _LiteralReader {
  _LiteralReader(
    this.tokens,
    this.environment, {
    this.depth = 0,
    this.functionName = '',
    _ParseBudget? budget,
  }) : budget = budget ?? _ParseBudget();
  final List<String> tokens;
  final Map<String, Object> environment;
  final int depth;
  final String functionName;
  final _ParseBudget budget;
  int position = 0;

  String get peek => position < tokens.length ? tokens[position] : '';
  String take() {
    if (--budget.remaining < 0) {
      throw const FormatException('Parsing budget exceeded');
    }
    if (position >= tokens.length) {
      throw const FormatException('Unexpected end');
    }
    return tokens[position++];
  }

  void expect(String token) {
    if (take() != token) throw const FormatException('Unsupported syntax');
  }

  List<String> group(String opening, String closing) {
    expect(opening);
    final int start = position;
    int nesting = 1;
    while (position < tokens.length) {
      final String token = take();
      if (token == opening) nesting++;
      if (token == closing) nesting--;
      if (nesting == 0) return tokens.sublist(start, position - 1);
    }
    throw const FormatException('Unclosed group');
  }

  _LiteralFunction function() {
    expect('function');
    final String name = peek == '(' ? '' : take();
    final List<String> parameters = group(
      '(',
      ')',
    ).where((token) => token != ',').toList();
    final List<String> body = group('{', '}');
    return _LiteralFunction(name, parameters, body, environment);
  }

  Object expression() {
    Object value = atom();
    while (peek == '+') {
      take();
      final Object next = atom();
      if (value is! String ||
          next is! String ||
          value.length + next.length > 8192) {
        throw const FormatException(
          'Only bounded string concatenation is supported',
        );
      }
      value += next;
    }
    return value;
  }

  Object atom() {
    if (depth > 20) throw const FormatException('Too deeply nested');
    Object value;
    if (peek == '(') {
      take();
      value = expression();
      expect(')');
    } else if (peek == 'function') {
      value = function();
    } else {
      final String token = take();
      if (token.startsWith("'") || token.startsWith('"')) {
        value = token.substring(1, token.length - 1).replaceAllMapped(
          RegExp(r'\\(x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|.)'),
          (match) {
            final String escape = match[1]!;
            if (escape.startsWith('x') || escape.startsWith('u')) {
              return String.fromCharCode(
                int.parse(escape.substring(1), radix: 16),
              );
            }
            return switch (escape) {
              'n' => '\n',
              'r' => '\r',
              't' => '\t',
              _ => escape,
            };
          },
        );
      } else if (token == 'getName' && functionName.isNotEmpty && peek == '(') {
        expect('(');
        expect(')');
        return functionName;
      } else {
        value = switch (token) {
          'location' => _Reference.location,
          'window' => _Reference.window,
          _ =>
            environment[token] ??
                (throw const FormatException('Unknown identifier')),
        };
      }
    }
    while (peek == '(') {
      take();
      final List<Object> arguments = <Object>[];
      while (peek != ')') {
        arguments.add(expression());
        if (peek != ',') break;
        take();
      }
      expect(')');
      if (value is! _LiteralFunction) {
        throw const FormatException('Unknown function');
      }
      final Map<String, Object> locals = Map<String, Object>.of(
        value.environment,
      );
      for (
        int index = 0;
        index < value.parameters.length && index < arguments.length;
        index++
      ) {
        locals[value.parameters[index]] = arguments[index];
      }
      value = _LiteralReader(
        value.body,
        locals,
        depth: depth + 1,
        functionName: value.name,
        budget: budget,
      ).returnValue();
    }
    return value;
  }

  Object returnValue() {
    while (position < tokens.length) {
      if (peek == 'return') {
        take();
        return expression();
      }
      statement();
    }
    throw const FormatException('Missing return');
  }

  void statement() {
    if (peek == ';') {
      take();
    } else if (peek == 'function') {
      final _LiteralFunction value = function();
      environment[value.name] = value;
    } else if (peek.startsWith("'") || peek.startsWith('"')) {
      take();
    } else {
      if (<String>['var', 'let', 'const'].contains(peek)) take();
      final String name = take();
      expect('=');
      environment[name] = expression();
    }
  }

  Iterable<String> redirects() sync* {
    while (position < tokens.length) {
      final int start = position;
      try {
        if ((peek == 'location' || environment[peek] == _Reference.location) &&
            position + 1 < tokens.length &&
            <String>['=', '.', '['].contains(tokens[position + 1])) {
          take();
          final String operation = take();
          bool call = false;
          if (operation == '.' || operation == '[') {
            final Object member = operation == '[' ? expression() : take();
            if (operation == '[') expect(']');
            if (member == 'href') {
              expect('=');
            } else if (<String>['replace', 'assign'].contains(member)) {
              expect('(');
              call = true;
            } else {
              throw const FormatException('Unsupported location member');
            }
          }
          final Object value = expression();
          if (call) expect(')');
          if (value is String) yield value;
        } else {
          statement();
        }
      } on FormatException {
        if (budget.remaining < 0) return;
        position = start;
        while (position < tokens.length && take() != ';') {}
      }
    }
  }
}
