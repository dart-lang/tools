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
    final typeRef = TypeReference((b) => b..symbol = 'Foo');

    test('properties should be exposed', () {
      final localTypeRef = TypeReference(
        (b) =>
            b
              ..symbol = 'Foo'
              ..url = 'package:foo/foo.dart',
      );
      expect(localTypeRef.symbol, 'Foo');
      expect(localTypeRef.url, 'package:foo/foo.dart');
      expect(localTypeRef.type, same(localTypeRef));
    });

    test('should support newInstance', () {
      expect(
        typeRef.newInstance([literal(42)], {'bar': literal('baz')}, [
          refer('int'),
        ]),
        equalsDart(r"Foo<int>(42, bar: 'baz', )"),
      );
    });

    test('should support newInstanceNamed', () {
      expect(
        typeRef.newInstanceNamed(
          'fromMap',
          [literal(42)],
          {'bar': literal('baz')},
          [refer('int')],
        ),
        equalsDart(r"Foo.fromMap<int>(42, bar: 'baz', )"),
      );
    });

    test('should support constInstance', () {
      expect(
        typeRef.constInstance([literal(42)], {'bar': literal('baz')}, [
          refer('int'),
        ]),
        equalsDart(r"const Foo<int>(42, bar: 'baz', )"),
      );
    });

    test('should support constInstanceNamed', () {
      expect(
        typeRef.constInstanceNamed(
          'fromMap',
          [literal(42)],
          {'bar': literal('baz')},
          [refer('int')],
        ),
        equalsDart(r"const Foo.fromMap<int>(42, bar: 'baz', )"),
      );
    });
  });
}
