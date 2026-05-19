// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  useDartfmt();

  test('should create a nullable type in a pre-Null Safety library', () {
    expect(
      TypeReference(
        (b) =>
            b
              ..symbol = 'Foo'
              ..isNullable = true,
      ),
      equalsDart(r'''
        Foo
      '''),
    );
  });

  group('in a Null Safety library', () {
    late DartEmitter emitter;

    setUp(() => emitter = DartEmitter.scoped(useNullSafetySyntax: true));

    test('should create a nullable type', () {
      expect(
        TypeReference(
          (b) =>
              b
                ..symbol = 'Foo'
                ..isNullable = true,
        ),
        equalsDart(r'Foo?', emitter),
      );
    });

    test('should create a non-nullable type', () {
      expect(
        TypeReference((b) => b.symbol = 'Foo'),
        equalsDart(r'Foo', emitter),
      );
    });

    test('should create a type with nullable type arguments', () {
      expect(
        TypeReference(
          (b) =>
              b
                ..symbol = 'List'
                ..types.add(
                  TypeReference(
                    (b) =>
                        b
                          ..symbol = 'int'
                          ..isNullable = true,
                  ),
                ),
        ),
        equalsDart(r'List<int?>', emitter),
      );
    });

    test('should support generic bound', () {
      expect(
        TypeReference(
          (b) =>
              b
                ..symbol = 'T'
                ..bound = refer('num'),
        ),
        equalsDart(r'T extends num', emitter),
      );
    });
  });

  group('TypeReference API', () {
    test('properties should be exposed', () {
      final typeRef = TypeReference(
        (b) =>
            b
              ..symbol = 'Foo'
              ..url = 'package:foo/foo.dart',
      );
      expect(typeRef.symbol, 'Foo');
      expect(typeRef.url, 'package:foo/foo.dart');
      expect(typeRef.type, same(typeRef));
    });

    test('should support newInstance', () {
      final typeRef = TypeReference((b) => b..symbol = 'Foo');
      expect(
        typeRef.newInstance([literal(42)], {'bar': literal('baz')}),
        equalsDart(r"Foo(42, bar: 'baz', )"),
      );
    });

    test('should support newInstanceNamed', () {
      final typeRef = TypeReference((b) => b..symbol = 'Foo');
      expect(
        typeRef.newInstanceNamed(
          'fromMap',
          [literal(42)],
          {'bar': literal('baz')},
        ),
        equalsDart(r"Foo.fromMap(42, bar: 'baz', )"),
      );
    });

    test('should support constInstance', () {
      final typeRef = TypeReference((b) => b..symbol = 'Foo');
      expect(
        typeRef.constInstance([literal(42)], {'bar': literal('baz')}),
        equalsDart(r"const Foo(42, bar: 'baz', )"),
      );
    });

    test('should support constInstanceNamed', () {
      final typeRef = TypeReference((b) => b..symbol = 'Foo');
      expect(
        typeRef.constInstanceNamed(
          'fromMap',
          [literal(42)],
          {'bar': literal('baz')},
        ),
        equalsDart(r"const Foo.fromMap(42, bar: 'baz', )"),
      );
    });
  });
}
