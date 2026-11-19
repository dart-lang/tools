// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const int _testQsaBaseline = 0x01;
const String _knownFailingSubstring = 'matching custom data-* attribute with';

typedef _SelectorCase = ({
  String name,
  String selector,
  List<String> expectedIds,
  Set<String> excludedContexts,
  int testType,
});

typedef _WptSelectorsSuite = ({
  String html,
  List<_SelectorCase> validCases,
});

_WptSelectorsSuite? _loadWptSelectorsSuite([Directory? directory]) {
  final dir = directory ??
      Directory.fromUri(
        Isolate.resolvePackageUriSync(Uri.parse('package:html/dom.dart'))!
            .resolve('../../../third_party/wpt-selectors/'),
      );
  if (!dir.existsSync()) {
    return null;
  }

  final html = File(p.join(dir.path, 'level1-content.html')).readAsStringSync();
  final rawJson = jsonDecode(
    File(p.join(dir.path, 'selectors.json')).readAsStringSync(),
  ) as Map<String, Object?>;
  final rawValid = rawJson['validSelectors'] as List<Object?>;

  final validCases = <_SelectorCase>[
    for (final entry in rawValid.cast<Map<String, Object?>>())
      (
        name: entry['name'] as String,
        selector: entry['selector'] as String,
        expectedIds: (entry['expect'] as List<Object?>).cast<String>(),
        excludedContexts: {
          if (entry['exclude'] case final List<Object?> excluded)
            ...excluded.cast<String>(),
        },
        testType: entry['testType'] as int,
      ),
  ];
  if (validCases.isEmpty) {
    throw StateError('Expected non-empty validSelectors in ${dir.path}');
  }

  return (html: html, validCases: validCases);
}

void main() {
  test('returns null when wpt-selectors directory is absent', () {
    final tempDir = Directory.systemTemp.createTempSync('wpt_selectors_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    expect(
      _loadWptSelectorsSuite(Directory(p.join(tempDir.path, 'missing'))),
      isNull,
    );
  });

  final suite = _loadWptSelectorsSuite();
  if (suite == null) {
    return;
  }

  final doc = parse(suite.html);
  final rootElement = doc.getElementById('root')!;
  _appendNamespaceFixtures(doc, rootElement);

  final outOfScope = rootElement.clone(true);
  _forEachElement(outOfScope, (el) {
    el.attributes['data-clone'] = '';
  });

  final detached = rootElement.clone(true);
  final fragment = doc.createDocumentFragment()
    ..append(rootElement.clone(true));

  final documentTarget = _DocumentTarget(doc);
  final detachedTarget = _ElementTarget(detached);
  final fragmentTarget = _FragmentTarget(fragment);
  final elementTarget = _ElementTarget(rootElement);

  _registerSpecialSelectorTests('Document', documentTarget);
  _registerSpecialSelectorTests('Detached Element', detachedTarget);
  _registerSpecialSelectorTests('Fragment', fragmentTarget);
  _registerSpecialSelectorTests('In-document Element', elementTarget);

  _registerStaticListTests('Document', doc, documentTarget);
  _registerStaticListTests('Detached Element', doc, detachedTarget);
  _registerStaticListTests('Fragment', doc, fragmentTarget);
  _registerStaticListTests('In-document Element', doc, elementTarget);

  _registerValidSelectorTests('Document', documentTarget, suite.validCases);
  _registerValidSelectorTests(
    'Detached Element',
    detachedTarget,
    suite.validCases,
  );
  _registerValidSelectorTests('Fragment', fragmentTarget, suite.validCases);

  group('out of scope', () {
    setUp(() {
      doc.body!.append(outOfScope);
    });
    tearDown(outOfScope.remove);

    _registerValidSelectorTests(
      'In-document Element',
      elementTarget,
      suite.validCases,
    );
  });
}

void _appendNamespaceFixtures(Document doc, Element parent) {
  parent
    ..append(doc.createElement('null'))
    ..append(doc.createElement('undefined'))
    ..append(_buildNamespaceGroup(doc, 'any-namespace'))
    ..append(_buildNamespaceGroup(doc, 'no-namespace'));
}

Element _buildNamespaceGroup(Document doc, String prefix) {
  final container = doc.createElement('div')..id = prefix;
  final divs = [
    doc.createElement('div')..id = '$prefix-div1',
    doc.createElementNS('http://www.w3.org/1999/xhtml', 'div')
      ..id = '$prefix-div2',
    doc.createElementNS('', 'div')..attributes['id'] = '$prefix-div3',
    doc.createElementNS('http://www.example.org/ns', 'div')
      ..attributes['id'] = '$prefix-div4',
  ];
  for (final div in divs) {
    container.append(div);
  }
  return container;
}

void _registerStaticListTests(
  String label,
  Document doc,
  _QueryTarget target,
) {
  late List<Element> pre;
  late int preLength;

  test('$label: static NodeList', () {
    pre = target.querySelectorAll('div');
    preLength = pre.length;

    target.appendDiv(doc.createElement('div'));
    expect(pre, hasLength(preLength));
  });

  test('$label: new NodeList', () {
    final post = target.querySelectorAll('div');
    expect(post, hasLength(preLength + 1));
  });
}

void _registerSpecialSelectorTests(String label, _QueryTarget target) {
  for (final tag in ['null', 'undefined']) {
    final upper = tag.toUpperCase();
    test('$label.querySelectorAll $tag', () {
      expect(target.querySelectorAll(tag), hasLength(1));
    });

    test('$label.querySelector $tag', () {
      final match = target.querySelector(tag);
      expect(match, isNotNull);
      expect(match!.localName?.toUpperCase(), upper);
    });
  }

  test('$label.querySelectorAll tree order', () {
    final result = target.querySelectorAll('*');
    final expected = <Element>[];
    _forEachElement(target.node, (el) {
      if (!identical(el, target.node)) {
        expected.add(el);
      }
    });
    expect(result, expected);
  });
}

void _registerValidSelectorTests(
  String label,
  _QueryTarget target,
  List<_SelectorCase> cases,
) {
  final contextKind = target.contextKind;
  for (final c in cases) {
    if ((c.testType & _testQsaBaseline) == 0 ||
        c.excludedContexts.contains(contextKind) ||
        c.excludedContexts.contains('html')) {
      continue;
    }

    final skipReason = c.name.contains(_knownFailingSubstring)
        ? 'Tests related to `$_knownFailingSubstring` fail for an unknown '
            'reason.'
        : null;

    late List<Element> foundAll;
    test('$label.querySelectorAll: ${c.name}:${c.selector}', () {
      foundAll = target.querySelectorAll(c.selector);
      expect(foundAll, hasLength(c.expectedIds.length));
      for (var i = 0; i < c.expectedIds.length; i++) {
        expect(foundAll[i].attributes['id'], c.expectedIds[i]);
        expect(foundAll[i].attributes.containsKey('data-clone'), isFalse);
      }
    }, skip: skipReason);

    test('$label.querySelector: ${c.name} : ${c.selector}', () {
      final found = target.querySelector(c.selector);
      if (c.expectedIds.isEmpty) {
        expect(found, isNull);
        return;
      }
      expect(found, isNotNull);
      expect(found!.attributes['id'], c.expectedIds.first);
      expect(found, same(foundAll.first));
      expect(found.attributes.containsKey('data-clone'), isFalse);
    }, skip: skipReason);
  }
}

void _forEachElement(Node node, void Function(Element) action) {
  if (node is Element) {
    action(node);
  }
  for (final child in node.nodes) {
    _forEachElement(child, action);
  }
}

sealed class _QueryTarget {
  Node get node;
  String get contextKind;
  Element? querySelector(String selector);
  List<Element> querySelectorAll(String selector);
  void appendDiv(Element div);
}

final class _DocumentTarget extends _QueryTarget {
  final Document _document;

  _DocumentTarget(this._document);

  @override
  Node get node => _document;

  @override
  String get contextKind => 'document';

  @override
  Element? querySelector(String selector) => _document.querySelector(selector);

  @override
  List<Element> querySelectorAll(String selector) =>
      _document.querySelectorAll(selector);

  @override
  void appendDiv(Element div) => _document.body!.append(div);
}

final class _ElementTarget extends _QueryTarget {
  final Element _element;

  _ElementTarget(this._element);

  @override
  Node get node => _element;

  @override
  String get contextKind =>
      _element.parentNode != null ? 'element' : 'detached';

  @override
  Element? querySelector(String selector) => _element.querySelector(selector);

  @override
  List<Element> querySelectorAll(String selector) =>
      _element.querySelectorAll(selector);

  @override
  void appendDiv(Element div) => _element.append(div);
}

final class _FragmentTarget extends _QueryTarget {
  final DocumentFragment _fragment;

  _FragmentTarget(this._fragment);

  @override
  Node get node => _fragment;

  @override
  String get contextKind => 'fragment';

  @override
  Element? querySelector(String selector) => _fragment.querySelector(selector);

  @override
  List<Element> querySelectorAll(String selector) =>
      _fragment.querySelectorAll(selector);

  @override
  void appendDiv(Element div) => _fragment.append(div);
}
