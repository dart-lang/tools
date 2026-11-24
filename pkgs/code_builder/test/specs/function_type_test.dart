// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  late DartEmitter emitter;

  useDartfmt();

  setUp(() => emitter = DartEmitter.scoped(useNullSafetySyntax: true));

  group('FunctionType API contracts', () {
    test('properties should be correct', () {
      final funcType = FunctionType();
      expect(funcType.url, isNull);
      expect(funcType.symbol, isNull);
      expect(funcType.type, same(funcType));
    });

    test('newInstance should throw UnsupportedError', () {
      final funcType = FunctionType();
      expect(() => funcType.newInstance([]), throwsUnsupportedError);
    });

    test('newInstanceNamed should throw UnsupportedError', () {
      final funcType = FunctionType();
      expect(
        () => funcType.newInstanceNamed('name', []),
        throwsUnsupportedError,
      );
    });

    test('constInstance should throw UnsupportedError', () {
      final funcType = FunctionType();
      expect(() => funcType.constInstance([]), throwsUnsupportedError);
    });

    test('constInstanceNamed should throw UnsupportedError', () {
      final funcType = FunctionType();
      expect(
        () => funcType.constInstanceNamed('name', []),
        throwsUnsupportedError,
      );
    });

    test('should support toTypeDef', () {
      final funcType = FunctionType(
        (b) => b
          ..returnType = refer('String')
          ..requiredParameters.add(refer('int')),
      );
      expect(
        funcType.toTypeDef('MyFunc'),
        equalsDart('typedef MyFunc = String Function(int);', emitter),
      );
    });
  });
}
