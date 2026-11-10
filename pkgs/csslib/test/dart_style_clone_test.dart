// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/visitor.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  test('font clones own their family list and retain priority', () {
    final span = SourceFile.fromString('font').span(0, 4);
    final names = <String>['Frank Ruhl', 'serif'];
    final style = FontExpression(span, family: names)..priority = 37;
    final clone = style.clone();

    names[0] = 'different font';
    names.add('fallback');
    expect(clone.font.family, ['Frank Ruhl', 'serif']);
    expect(clone.priority, 37);

    clone.font.family!.add('separate');
    expect(style.font.family, ['different font', 'serif', 'fallback']);
  });

  test('declaration clones own the style payload and keep priority', () {
    final span = SourceFile.fromString('font-size').span(0, 9);
    final families = <String>['Alef'];
    final original = Declaration(
      Identifier('font-family', span),
      null,
      FontExpression(span, family: families)..priority = 31,
      span,
      important: true,
      ie7: true,
    );
    final copy = original.clone();
    final originalStyle = original.dartStyle! as FontExpression;
    final copiedStyle = copy.dartStyle! as FontExpression;

    expect(copy.property, '*font-family');
    expect(copy.important, isTrue);
    expect(identical(copiedStyle, originalStyle), isFalse);
    expect(copiedStyle.priority, 31);

    copiedStyle.priority = 9;
    copiedStyle.font.family!.add('serif');
    expect(originalStyle.priority, 31);
    expect(originalStyle.font.family, ['Alef']);
    expect(families, ['Alef']);
  });

  test('all Dart style subclasses retain priority when cloned', () {
    final span = SourceFile.fromString('margin').span(0, 6);
    final styles = <DartStyleExpression>[
      MarginExpression(span, left: 1),
      BorderExpression(span, right: 2),
      PaddingExpression(span, top: 3),
      HeightExpression(span, 4),
      WidthExpression(span, 5),
    ];
    for (final style in styles) {
      style.priority = 42;
      final copy = style.clone() as DartStyleExpression;
      expect(copy.priority, 42, reason: style.runtimeType.toString());
      copy.priority = 7;
      expect(style.priority, 42);
    }
  });
}
