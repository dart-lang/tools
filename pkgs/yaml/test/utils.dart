// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/src/equality.dart' as equality;
import 'package:yaml/src/scanner.dart';
import 'package:yaml/src/token.dart';
import 'package:yaml/yaml.dart';

/// A matcher that validates that a closure or Future throws a [YamlException].
final Matcher throwsYamlException = throwsA(isA<YamlException>());

/// Returns a matcher that asserts that the value equals [expected].
///
/// This handles recursive loops and considers `NaN` to equal itself.
Matcher deepEquals(Object? expected) => predicate(
    (actual) => equality.deepEquals(actual, expected), 'equals $expected');

/// Constructs a new yaml.YamlMap, optionally from a normal Map.
Map deepEqualsMap([Map? from]) {
  var map = equality.deepEqualsMap<Object?, Object?>();
  if (from != null) map.addAll(from);
  return map;
}

/// Asserts that an error has the given message and starts at the given line/col.
void expectErrorAtLineCol(
    YamlException error, String message, int line, int col) {
  expect(error.message, equals(message));
  expect(error.span!.start.line, equals(line));
  expect(error.span!.start.column, equals(col));
}

/// Asserts that a string containing a single YAML document produces a given
/// value when loaded.
void expectYamlLoads(Object? expected, String source) {
  var actual = loadYaml(cleanUpLiteral(source));
  expect(actual, deepEquals(expected));
}

/// Asserts that a string containing a stream of YAML documents produces a given
/// list of values when loaded.
void expectYamlStreamLoads(List expected, String source) {
  var actual = loadYamlStream(cleanUpLiteral(source));
  expect(actual, deepEquals(expected));
}

/// Asserts that a string containing a single YAML document throws a
/// [YamlException].
void expectYamlFails(String source) {
  expect(() => loadYaml(cleanUpLiteral(source)), throwsYamlException);
}

/// Removes eight spaces of leading indentation from a multiline string.
///
/// Note that this is very sensitive to how the literals are styled. They should
/// be:
///     '''
///     Text starts on own line. Lines up with subsequent lines.
///     Lines are indented exactly 8 characters from the left margin.
///     Close is on the same line.'''
///
/// This does nothing if text is only a single line.
String cleanUpLiteral(String text) {
  var lines = text.split('\n');
  if (lines.length <= 1) return text;

  for (var j = 0; j < lines.length; j++) {
    if (lines[j].length > 8) {
      lines[j] = lines[j].substring(8, lines[j].length);
    } else {
      lines[j] = '';
    }
  }

  return lines.join('\n');
}

/// Indents each line of [text] so that, when passed to [cleanUpLiteral], it
/// will produce output identical to [text].
///
/// This is useful for literals that need to include newlines but can't be
/// conveniently represented as multi-line strings.
String indentLiteral(String text) {
  var lines = text.split('\n');
  if (lines.length <= 1) return text;

  for (var i = 0; i < lines.length; i++) {
    lines[i] = '        ${lines[i]}';
  }

  return lines.join('\n');
}

/// Generates tokens that can be consumed by a yaml parser.
Iterable<Token> generateTokens(String source) sync* {
  final scanner = Scanner(source);

  do {
    if (scanner.peek() case Token token) {
      yield token;
      scanner.advance();
      continue;
    }

    break;
  } while (true);
}

/// Matches a [TagDirectiveToken] emitted by a [Scanner]
Matcher isATagDirective(String handle, String prefix) =>
    isA<TagDirectiveToken>()
        .having((t) => t.handle, 'handle', equals(handle))
        .having((t) => t.prefix, 'prefix', equals(prefix));

extension PadUtil on String {
  /// Applies an indent of 8 spaces to a multiline string to ensure strings
  /// are compatible with existing matchers.
  ///
  /// See [cleanUpLiteral].
  String asIndented() => split('\n')
      .map((line) => line.isEmpty ? line : '${' ' * 8}$line')
      .join('\n');
}
