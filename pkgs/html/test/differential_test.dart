@TestOn('chrome')
library;

import 'dart:js_interop';

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// A collection of HTML test cases for differential testing.
///
/// This suite evaluates `package:html` against the browser's native `web.DOMParser`
/// (via `package:web`). For each test case, it parses the HTML payload with both
/// `web.DOMParser` and `package:html` and compares the structure of both tags
/// and attributes, with the assumption that discrepancies are likely
/// bugs that should be fixed.
final _testCases = [
  (
    name: 'sanity check: simple nesting',
    html: '<div><p>Hello <b>World</b></p></div>',
  ),
  (
    name: 'sanity check: attributes',
    html: '<a href="https://dart.dev" class="link">link</a>',
  ),
  (
    name: 'implicit tbody template foster parenting',
    html: '<table><template><tr>',
  ),
  (
    name: 'adoption agency algorithm nested formatters limit',
    html: '<b><p><b style=""><b style="font-weight:600"><b style=""><b style="font-weight:600"><b><b></b></b><b style="font-weight:600"><b style="font-weight:600"></b></b></b></b></b></b>',
  ),
  (name: 'noscript contents style dropped', html: '<noscript><style type="a">'),
  (
    name: 'isindex form expansion (prompt)',
    html: '<isindex prompt><hr><hr><hr><hr><input>',
  ),
  (name: 'frameset disallowed in template', html: '<ins><template><frameset>'),
  (name: 'anchor active formatting overlapping menu', html: '<a><menu><a>'),
  (name: 'noscript contents dropped (paragraphs)', html: '<noscript><p>'),
  (
    name: 'noscript contents dropped (anchors)',
    html: '<noscript><a></noscript>',
  ),
  (
    name: 'template implicit tbody edge case',
    html: '<table><thead><template><td>',
  ),
  (
    name: 'noscript contents dropped (images)',
    html: '<noscript><img src alt width height title style></noscript>',
  ),
  (
    name: 'noscript layout dropped (yahoo core)',
    html: '<noscript><a><img></a></noscript>',
  ),
  (
    name: 'adoption agency algorithm nested loop',
    html: '<b><em><x><x><x><p></b></em>',
  ),
  (
    name: 'isindex form expansion (action)',
    html: '<isindex action="foo" name="bar">',
  ),
  (
    name: 'template attribute mutation leak',
    html: '<template><html a="b"></template>',
  ),
];

final _knownIssues = {
  'implicit tbody template foster parenting',
  'adoption agency algorithm nested formatters limit',
  'noscript contents style dropped',
  'isindex form expansion (prompt)',
  'frameset disallowed in template',
  'anchor active formatting overlapping menu',
  'noscript contents dropped (paragraphs)',
  'noscript contents dropped (anchors)',
  'template implicit tbody edge case',
  'noscript contents dropped (images)',
  'noscript layout dropped (yahoo core)',
  'adoption agency algorithm nested loop',
  'isindex form expansion (action)',
  'template attribute mutation leak',
};

void main() {
  for (final c in _testCases) {
    test(c.name, () {
      final parser = web.DOMParser();
      final browserDoc = parser.parseFromString(c.html.toJS, 'text/html');
      final pkgDoc = html.parse(c.html);

      final webCounts = _countWebTags(browserDoc);
      final pkgCounts = _countPkgTags(pkgDoc);

      if (_knownIssues.contains(c.name)) {
        expect(
          webCounts,
          isNot(equals(pkgCounts)),
          reason: 'Expected to fail per known issues list.',
        );
      } else {
        expect(
          webCounts,
          equals(pkgCounts),
          reason: 'Should parse identically',
        );
      }
    });
  }
}

/// Counts the occurrence of every HTML tag and its attributes recursively in a Chrome [web.Document].
Map<String, int> _countWebTags(web.Document doc) {
  final counts = <String, int>{};
  final elements = doc.querySelectorAll('*');
  for (var i = 0; i < elements.length; i++) {
    final element = elements.item(i) as web.Element;
    final tag = element.tagName.toLowerCase();
    counts.update(tag, (v) => v + 1, ifAbsent: () => 1);

    final attrs = element.attributes;
    for (var j = 0; j < attrs.length; j++) {
      final attrName = attrs.item(j)!.name.toLowerCase();
      final key = '$tag.$attrName';
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

/// Counts the occurrence of every HTML tag and its attributes recursively in a Dart [html.Document].
Map<String, int> _countPkgTags(html.Document doc) {
  final counts = <String, int>{};
  void walk(html.Element node) {
    final tag = node.localName!.toLowerCase();
    counts.update(tag, (v) => v + 1, ifAbsent: () => 1);

    for (final attr in node.attributes.keys) {
      final attrName = attr.toString().toLowerCase();
      final key = '$tag.$attrName';
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(doc.documentElement!);
  return counts;
}
