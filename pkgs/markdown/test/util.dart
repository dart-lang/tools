// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/expected_output.dart';

/// Runs tests defined in "*.unit" files inside directory [name].
void testDirectory(String name, {ExtensionSet? extensionSet}) {
  for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';

    final inlineSyntaxes = <InlineSyntax>[];
    final blockSyntaxes = <BlockSyntax>[];
    var enableTagfilter = false;

    if (dataCase.file.endsWith('_extension')) {
      final extension = dataCase.file.substring(
        0,
        dataCase.file.lastIndexOf('_extension'),
      );
      switch (extension) {
        case 'autolinks':
          inlineSyntaxes.add(AutolinkExtensionSyntax());
          break;
        case 'strikethrough':
          inlineSyntaxes.add(StrikethroughSyntax());
          break;
        case 'tables':
          blockSyntaxes.add(const TableSyntax());
          break;
        case 'disallowed_raw_html':
          enableTagfilter = true;
          break;
        default:
          throw UnimplementedError('Unimplemented extension "$extension"');
      }
    }

    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      extensionSet: extensionSet,
      inlineSyntaxes: inlineSyntaxes,
      blockSyntaxes: blockSyntaxes,
      enableTagfilter: enableTagfilter,
    );
  }
}

void testFile(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) {
  for (final dataCase in dataCasesInFile(
    path: p.join(p.current, 'test', file),
  )) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
    );
  }
}

void validateCore(
  String description,
  String markdown,
  String html, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
  bool enableTagfilter = false,
}) {
  test(description, () {
    final result = markdownToHtml(
      markdown,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      extensionSet: extensionSet,
      linkResolver: linkResolver,
      imageLinkResolver: imageLinkResolver,
      inlineOnly: inlineOnly,
      enableTagfilter: enableTagfilter,
    );

    markdownPrintOnFailure(markdown, html, result);

    expect(result, html);
  });
}

String whitespaceColor(String input) => input
    .replaceAll(' ', ansi.lightBlue.wrap('·')!)
    .replaceAll('\t', ansi.backgroundDarkGray.wrap('\t')!);

void markdownPrintOnFailure(String markdown, String expected, String actual) {
  printOnFailure("""
INPUT:
'''r
${whitespaceColor(markdown)}'''
           
EXPECTED:
'''r
${whitespaceColor(expected)}'''

GOT:
'''r
${whitespaceColor(actual)}'''
""");
}

// Matchers for element structures.
// --------------------------------------------------------------------

/// Matcher for an [Element] with a matching [Element.tag].
///
/// The [tag] can be a literal string or any matcher which matches as string.
/// The `tag` value can also be an [Element], in which case [children] and
/// [attributes] are ignored and the values taken from the element instead.
///
/// If [children] and [attributes] are provided,
/// they're matched against the element's [Element.children] and
/// [Element.attributes].
///
/// The [children] can be a [List] of matchers for nodes, which includes nodes
/// and [String] values, which are matched as [Text] nodes with that content,
/// or it can be any [Matcher] which matches such a list.
///
/// The [attributes] can be a [Map] of matchers for attributes,
/// or it can be any [Matcher] which matches such a map.
///
/// If [isEmpty] is true, the element is matched as self closing.
ElementMatcher isElement(
  Object tag, [
  Object? children,
  Object? attributes,
  bool? isEmpty,
]) => ElementMatcher(
  tag,
  children: children,
  attributes: attributes,
  isEmpty: isEmpty,
);

/// A matcher for a self-closing element.
///
/// Same as `isElement(tag, null, attributes, true)`.
ElementMatcher isEmptyElement(Object tag, Object? attributes) =>
    isElement(tag, null, attributes, true);

/// Matcher for a [Text] with a matching [Text.textContent].
///
/// The [isElement] `children` list interprets [String] values
/// as [Text] elements.
///
/// The [text] can be a verbatim text string, or any matcher which can
/// match a [String].
TextMatcher isText(Object text) => TextMatcher(text);

abstract class NodeMatcher extends Matcher {
  NodeMatcher();
  factory NodeMatcher.of(Node node) => node is Element
      ? ElementMatcher.of(node)
      : node is Text
      ? TextMatcher.of(node)
      : throw UnsupportedError('Unexpected node type: ${node.runtimeType}');
}

class ElementMatcher extends NodeMatcher {
  final Matcher tag;
  final Matcher? children; // Matches a list of nodes.
  final Matcher? attributes;
  bool? isEmpty;

  /// Matcher for an [Element] where [tag] matches the element's tag.
  ///
  /// If [tag] is an [Element], then [children], [attributes] and [isEmpty]
  /// are ignored and the matcher is the same as [ElementMatcher.of]
  /// of that element.
  ///
  /// The [children] must match the child nodes if supplied,
  /// and ignores them if `null`.
  /// If [children] is a list, [Node] entries match nodes
  /// and [String] entries match [Text] nodes with that text.
  /// To check that an element is empty/self closing,
  /// you can use `equals(null)` as children matcher,
  /// use pass `true` to [isEmpty].
  ///
  ///The [attributes] must match the attributes if supplied,
  /// and ignores them if `null`.
  factory ElementMatcher(
    Object tag, {
    Object? children,
    Object? attributes,
    bool? isEmpty,
  }) => tag is Element
      ? ElementMatcher.of(tag)
      : ElementMatcher._(tag, children, attributes, isEmpty);

  /// Mataches an element equivalent to [node].
  ///
  /// A matched element has the same tag, equivalent children
  /// and the same attributes as [node].
  ElementMatcher.of(Element node)
    : this._(node.tag, node.children, node.attributes, node.isEmpty);

  ElementMatcher._(
    Object tag,
    Object? children,
    Object? attributes,
    this.isEmpty,
  ) : tag = _asMatcher(tag),
      children = children == null
          ? null
          : children is List<Object?>
          ? equals([
              for (var childMatch in children)
                if (childMatch is Node)
                  NodeMatcher.of(childMatch)
                else if (childMatch is String)
                  TextMatcher(childMatch)
                else
                  childMatch,
            ])
          : _asMatcher(children),
      attributes = attributes == null ? null : _asMatcher(attributes);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      item is Element &&
      tag.matches(item.tag, matchState) &&
      (isEmpty == null || isEmpty == item.isEmpty) &&
      (children?.matches(item.children, matchState) ?? true) &&
      (attributes?.matches(item.attributes, matchState) ?? true);

  @override
  Description describe(Description description) {
    description.add('Element(');
    tag.describe(description);
    description.add(', ');
    if (children case final children?) {
      children.describe(description);
    } else {
      description.add('_');
    }
    if (attributes case final attributes?) {
      description.add(', ');
      attributes.describe(description);
    }
    if (isEmpty != null) {
      description
        ..add(', isEmpty: ')
        ..add(isEmpty.toString());
    }
    description.add(')');

    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (item is Node) {
      mismatchDescription = mismatchDescription.add('is: \n');
      mismatchDescription = mismatchDescription.add(nodeToString(item));
      mismatchDescription = mismatchDescription.add('\n');
      return mismatchDescription;
    }
    return super.describeMismatch(
      item,
      mismatchDescription,
      matchState,
      verbose,
    );
  }
}

class TextMatcher extends NodeMatcher {
  final Matcher textMatcher;

  /// Matches a [Text] object by [textMatch].
  ///
  /// The [textMatch] can be any matcher which matches a [String],
  /// or a [Text] object, in which case the matcher matches the same
  /// [Text.textContent] as the given [Text] object.
  factory TextMatcher(Object textMatch) =>
      textMatch is Text ? TextMatcher.of(textMatch) : TextMatcher._(textMatch);

  /// Matcher for a [Text] where [textMatcher] matches its [Text.textContent].
  TextMatcher._(Object textMatch) : textMatcher = _asMatcher(textMatch);

  /// Matcher for a [Text] where with the same [Text.textContent].
  TextMatcher.of(Text node) : this._(node.textContent);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      item is Text && textMatcher.matches(item.textContent, matchState);

  @override
  Description describe(Description description) {
    description.add('Text(');
    textMatcher.describe(description);
    description.add(')');
    return description;
  }
}

/// The [value] as a [Matcher], if it isn't one already.
Matcher _asMatcher(Object? value) => value is Matcher ? value : equals(value);

/// Creates a textual representation of a node, useful for debugging mis-matches
/// with the matchers above.
///
/// If [depth] is set, recursion is limited to that many levels.
String nodeToString(Node node, {int indent = 0, int depth = -1}) {
  final buffer = StringBuffer();
  _writeNode(node, buffer, ' ' * indent, depth);
  return buffer.toString();
}

void _writeNode(Node node, StringBuffer buffer, String indent, int depth) {
  if (node is Text) {
    buffer
      ..write('Text("')
      ..write(node.textContent)
      ..write('"),');
  } else if (node is Element) {
    buffer.write('Element("${node.tag}", [');
    final nextIndent = '$indent  ';
    if (node.children case final children? when children.isNotEmpty) {
      if (depth == 0) {
        buffer.write('...');
      } else {
        buffer.write('\n');
        for (final child in children) {
          buffer.write(nextIndent);
          _writeNode(child, buffer, nextIndent, depth - 1);
          buffer.write('\n');
        }
        buffer.write(indent);
      }
    }
    buffer.write(']');
    if (node.attributes.isNotEmpty) {
      buffer.write(', {\n');
      for (final MapEntry(:key, :value) in node.attributes.entries) {
        buffer
          ..write(nextIndent)
          ..write('"')
          ..write(key)
          ..write('": "')
          ..write(value)
          ..write('",\n');
      }
      buffer
        ..write(indent)
        ..write('}');
    }
    buffer.write('),');
  } else {
    throw UnsupportedError('Unexpected node type: ${node.runtimeType}');
  }
}
