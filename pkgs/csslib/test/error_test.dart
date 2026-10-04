// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/src/messages.dart';
import 'package:csslib/visitor.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';

import 'testing.dart';

/// Test for unsupported font-weights values of bolder, lighter and inherit.
void testUnsupportedFontWeights() {
  var errors = <Message>[];

  // TODO(terry): Need to support bolder.
  // font-weight value bolder.
  var input = '.foobar { font-weight: bolder; }';
  var stylesheet = parseCss(input, errors: errors);

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unknown property value bolder
  ,
1 | .foobar { font-weight: bolder; }
  |                        ^^^^^^
  \'''');

  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: bolder;
}''');

  // TODO(terry): Need to support lighter.
  // font-weight value lighter.
  input = '.foobar { font-weight: lighter; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unknown property value lighter
  ,
1 | .foobar { font-weight: lighter; }
  |                        ^^^^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: lighter;
}''');

  // TODO(terry): Need to support inherit.
  // font-weight value inherit.
  input = '.foobar { font-weight: inherit; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unknown property value inherit
  ,
1 | .foobar { font-weight: inherit; }
  |                        ^^^^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: inherit;
}''');
}

/// Test for unsupported line-height values of units other than px, pt and
/// inherit.
void testUnsupportedLineHeights() {
  var errors = <Message>[];

  // line-height value in percentage unit.
  var input = '.foobar { line-height: 120%; }';
  var stylesheet = parseCss(input, errors: errors);

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unexpected value for line-height
  ,
1 | .foobar { line-height: 120%; }
  |                        ^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: 120%;
}''');

  // TODO(terry): Need to support all units.
  // line-height value in cm unit.
  input = '.foobar { line-height: 20cm; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unexpected unit for line-height
  ,
1 | .foobar { line-height: 20cm; }
  |                        ^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: 20cm;
}''');

  // TODO(terry): Need to support inherit.
  // line-height value inherit.
  input = '.foobar { line-height: inherit; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 24: Unknown property value inherit
  ,
1 | .foobar { line-height: inherit; }
  |                        ^^^^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: inherit;
}''');
}

/// Test for bad selectors.
void testBadSelectors() {
  var errors = <Message>[];

  // Invalid id selector.
  var input = '# foo { color: #ff00ff; }';
  parseCss(input, errors: errors);

  expect(errors, isNotEmpty);
  expect(errors[0].toString(), '''
error on line 1, column 1: Not a valid ID selector expected #id
  ,
1 | # foo { color: #ff00ff; }
  | ^
  \'''');

  // Invalid class selector.
  input = '. foo { color: #ff00ff; }';
  parseCss(input, errors: errors..clear());

  expect(errors, isNotEmpty);
  expect(errors[0].toString(), '''
error on line 1, column 1: Not a valid class selector expected .className
  ,
1 | . foo { color: #ff00ff; }
  | ^
  \'''');
}

/// Test for bad hex values.
void testBadHexValues() {
  var errors = <Message>[];

  // Invalid hex value.
  var input = '.foobar { color: #AH787; }';
  var stylesheet = parseCss(input, errors: errors);

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 18: Bad hex number
  ,
1 | .foobar { color: #AH787; }
  |                  ^^^^^^
  \'''');
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: #AH787;
}''');

  // Bad color constant.
  input = '.foobar { color: redder; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 18: Unknown property value redder
  ,
1 | .foobar { color: redder; }
  |                  ^^^^^^
  \'''');

  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: redder;
}''');

  // Bad hex color #<space>ffffff.
  input = '.foobar { color: # ffffff; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 18: Expected hex number
  ,
1 | .foobar { color: # ffffff; }
  |                  ^
  \'''');

  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: # ffffff;
}''');

  // Bad hex color #<space>123fff.
  input = '.foobar { color: # 123fff; }';
  stylesheet = parseCss(input, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(errors[0].toString(), '''
error on line 1, column 18: Expected hex number
  ,
1 | .foobar { color: # 123fff; }
  |                  ^
  \'''');

  // Formating is off with an extra space.  However, the entire value is bad
  // and isn't processed anyway.
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: # 123 fff;
}''');
}

void testBadUnicode() {
  var errors = <Message>[];
  final input = '''
@font-face {
  src: url(fonts/BBCBengali.ttf) format("opentype");
  unicode-range: U+400-200;
}''';

  parseCss(input, errors: errors);

  expect(errors.isEmpty, false);
  expect(
      errors[0].toString(),
      'error on line 3, column 20: unicode first range can not be greater than '
      'last\n'
      '  ,\n'
      '3 |   unicode-range: U+400-200;\n'
      '  |                    ^^^^^^^\n'
      '  \'');

  final input2 = '''
@font-face {
  src: url(fonts/BBCBengali.ttf) format("opentype");
  unicode-range: U+12FFFF;
}''';

  parseCss(input2, errors: errors..clear());

  expect(errors.isEmpty, false);
  expect(
      errors[0].toString(),
      'error on line 3, column 20: unicode range must be less than 10FFFF\n'
      '  ,\n'
      '3 |   unicode-range: U+12FFFF;\n'
      '  |                    ^^^^^^\n'
      '  \'');
}

void testBadNesting() {
  var errors = <Message>[];

  // Test for bad declaration in a nested rule.
  final input = '''
div {
  width: 20px;
  span + ul { color: blue; }
  span + ul > #aaaa {
    color: #ffghghgh;
  }
  background-color: red;
}
''';

  parseCss(input, errors: errors);
  expect(errors.length, 1);
  var errorMessage = messages.messages[0];
  expect(errorMessage.message, contains('Bad hex number'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 4);
  expect(errorMessage.span!.start.column, 11);
  expect(errorMessage.span!.text, '#ffghghgh');

  // Test for bad selector syntax.
  final input2 = '''
div {
  span + ul #aaaa > (3333)  {
    color: #ffghghgh;
  }
}
''';
  parseCss(input2, errors: errors..clear());
  expect(errors.length, 4);
  errorMessage = messages.messages[0];
  expect(errorMessage.message, contains(':, but found +'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 1);
  expect(errorMessage.span!.start.column, 7);
  expect(errorMessage.span!.text, '+');

  errorMessage = messages.messages[1];
  expect(errorMessage.message, contains('Unknown property value ul'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 1);
  expect(errorMessage.span!.start.column, 9);
  expect(errorMessage.span!.text, 'ul');

  errorMessage = messages.messages[2];
  expect(errorMessage.message, contains('expected }, but found >'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 1);
  expect(errorMessage.span!.start.column, 18);
  expect(errorMessage.span!.text, '>');

  errorMessage = messages.messages[3];
  expect(errorMessage.message, contains('premature end of file unknown CSS'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 1);
  expect(errorMessage.span!.start.column, 20);
  expect(errorMessage.span!.text, '(');

  // Test for missing close braces and bad declaration.
  final input3 = '''
div {
  span {
    color: #green;
}
''';
  parseCss(input3, errors: errors..clear());
  expect(errors.length, 2);
  errorMessage = messages.messages[0];
  expect(errorMessage.message, contains('Bad hex number'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 2);
  expect(errorMessage.span!.start.column, 11);
  expect(errorMessage.span!.text, '#green');

  errorMessage = messages.messages[1];
  expect(errorMessage.message, contains('expected }, but found end of file'));
  expect(errorMessage.span, isNotNull);
  expect(errorMessage.span!.start.line, 3);
  expect(errorMessage.span!.start.column, 1);
  expect(errorMessage.span!.text, '\n');
}

void _exerciseAllEntryPoints(String input) {
  const checkedLessOptions = PreprocessorOptions(
    useColors: false,
    checked: true,
    warningsAsErrors: false,
    lessSupport: true,
    inputFile: 'memory',
  );
  const uncheckedOptions = PreprocessorOptions(
    useColors: false,
    checked: false,
    warningsAsErrors: false,
    lessSupport: true,
    inputFile: 'memory',
  );

  void exerciseTree(StyleSheet tree) {
    final cloned = tree.clone();
    Visitor().visitTree(tree);
    Visitor().visitTree(cloned);
    (CssPrinter()..visitTree(tree, pretty: true)).toString();
    (CssPrinter()..visitTree(tree, pretty: false)).toString();
    (CssPrinter()..visitTree(cloned, pretty: true)).toString();
    treeToDebugString(tree);
  }

  final errors = <Message>[];
  exerciseTree(
      parse(input, errors: errors..clear(), options: uncheckedOptions));
  exerciseTree(
      parse(input, errors: errors..clear(), options: checkedLessOptions));
  exerciseTree(compile(input,
      errors: errors..clear(), options: uncheckedOptions, polyfill: false));
  exerciseTree(compile(input,
      errors: errors..clear(), options: checkedLessOptions, polyfill: true));
  exerciseTree(selector(input, errors: errors..clear()));

  final selGroup = parseSelectorGroup(input, errors: errors..clear());
  if (selGroup != null) {
    final clonedGroup = selGroup.clone();
    Visitor().visitSelectorGroup(selGroup);
    Visitor().visitSelectorGroup(clonedGroup);
    (CssPrinter()..visitSelectorGroup(selGroup)).toString();
  }
}

void main() {
  glyph.ascii = true;
  test('font-weight value errors', testUnsupportedFontWeights);
  test('line-height value errors', testUnsupportedLineHeights);
  test('bad selectors', testBadSelectors);
  test('bad Hex values', testBadHexValues);
  test('bad unicode ranges', testBadUnicode);
  test('nested rules', testBadNesting);

  group('malformed input resilience (fuzz regressions)', () {
    test('out-of-range hex escapes in identifiers clamp without RangeError',
        () {
      _exerciseAllEntryPoints(r'.\110000 .\ffffff .\999999 { color: red; }');
    });

    test('malformed @import, @keyframes, @stylet, and @namespace directives',
        () {
      _exerciseAllEntryPoints('@import foo; @import ;');
      _exerciseAllEntryPoints('@keyframes { 0% { top: 0; } }');
      _exerciseAllEntryPoints('@keyframes k { @foo { top: 0; } }');
      _exerciseAllEntryPoints(
          '@keyframes k {\u00a00%, from { top: 0%; } 50% { top: 5px; } }');
      _exerciseAllEntryPoints('@stylet foo { a { color: red; } } @stylet { }');
      _exerciseAllEntryPoints('@namespace prefix; @namespace ;');
    });

    test('malformed @mixin, @include, and variable definitions do not hang',
        () {
      _exerciseAllEntryPoints('@mixin m(123) { color: red; }');
      _exerciseAllEntryPoints(
          '@mixin box-shadow(@shadows...) { box-shadow: @shadows; }');
      _exerciseAllEntryPoints('@mixin m(@: 1px, var-: 2px) { color: red; }');
      _exerciseAllEntryPoints('@: 1px; a { var-: 2px; }');
      _exerciseAllEntryPoints(
          '@mixin m(@a) { color: @a; } @include ; a { @include m(); }');
    });

    test('malformed @-moz-document and @supports directives', () {
      _exerciseAllEntryPoints(
          '@-moz-document regexp(".*"), foo(1), url-prefix() '
          '{ a { top: 0; } }');
      _exerciseAllEntryPoints('@-moz-document { }');
      _exerciseAllEntryPoints('@supports () { } @supports not () { }');
      _exerciseAllEntryPoints('@supports (a: 1) and () { }');
      _exerciseAllEntryPoints('@supports (a: 1) or () { }');
      final deepParens = '${'(' * 40}a: 1${')' * 40}';
      _exerciseAllEntryPoints('@supports $deepParens { a { color: red; } }');
    });

    test('malformed @page and @media unary operators', () {
      _exerciseAllEntryPoints('@page { 123 } @page :top { + color: red; }');
      _exerciseAllEntryPoints(
          '@page :first { @top-left { color: red; } width: 10px; }');
      final errors = <Message>[];
      parseCss('@media only screen { a { color: red; } }', errors: errors);
      expect(errors, isEmpty);
    });

    test('malformed selectors, namespace selectors, and selector expressions',
        () {
      _exerciseAllEntryPoints('ns| { color: red; } | { color: blue; }');
      _exerciseAllEntryPoints(':not() { color: red; }');
      _exerciseAllEntryPoints(':nth-child(99999999999999999999999) { }');
      _exerciseAllEntryPoints(':nth-child(n%) { }');
    });

    test('malformed declarations, expressions, and integer overflows', () {
      _exerciseAllEntryPoints(
          'a { font-weight: ; border-width: ; margin-left: ; '
          'font-size: 10cm; }');
      _exerciseAllEntryPoints(
          'a { margin: [foo]; font-weight: [bar]; line-height: [baz]; }');
      _exerciseAllEntryPoints(r'a { width: 99999999999999999999999px; '
          r'top: 1px\99999999999999999999999; }');
      _exerciseAllEntryPoints(
          'a { unicode-range: U+99999999999999999999-999999999999999999999; }');
      _exerciseAllEntryPoints(
          'a { color: #@foo; width: (@foo); height: [@foo]; top: @; }');
      _exerciseAllEntryPoints('a { color: var(); background: var(123); }');
    });

    test('nested selectors inside directives and cyclic @extend / var()', () {
      _exerciseAllEntryPoints('@host { a { b { color: red; } } }');
      _exerciseAllEntryPoints('@supports (a: 1) { a { b { color: red; } } }');
      _exerciseAllEntryPoints(
          '@-moz-document url-prefix() { a { b { color: red; } } }');
      _exerciseAllEntryPoints('@stylet s { a { b { color: red; } } }');
      _exerciseAllEntryPoints(
          '@media screen { @media print { a { b { color: red; } } } }');
      _exerciseAllEntryPoints('a { @extend .b; } .b { @extend a; }');
      _exerciseAllEntryPoints('var-a: var(a); var-b: var(c); var-c: var(b); '
          'a { color: var(a); width: var(b, var(c)); '
          'height: var(u, 1px var(a)); }');
    });
  });
}
