// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class _CustomErrorListener implements ErrorListener {
  final List<String> messages = [];

  @override
  void onError(YamlException error) {
    messages.add(error.message);
  }
}

void main() {
  const invalidYamlWithMissingPrefix = '''
linter:
  rules:
    - annotate_overrides
    alway
''';

  test('ErrorCollector collects errors during recovery parsing', () {
    final collector = ErrorCollector();
    final result = loadYaml(
      invalidYamlWithMissingPrefix,
      recover: true,
      errorListener: collector,
    );

    expect(
      result,
      equals({
        'linter': {
          'rules': ['annotate_overrides', 'alway'],
        },
      }),
    );
    expect(collector.errors, hasLength(1));
    expect(
      collector.errors.first.message,
      contains("Expected ':'"),
    );
  });

  test(
      'custom ErrorListener implementation receives errors during recovery '
      'parsing', () {
    final listener = _CustomErrorListener();
    final result = loadYaml(
      invalidYamlWithMissingPrefix,
      recover: true,
      errorListener: listener,
    );

    expect(
      result,
      equals({
        'linter': {
          'rules': ['annotate_overrides', 'alway'],
        },
      }),
    );
    expect(listener.messages, hasLength(1));
    expect(
      listener.messages.first,
      contains("Expected ':'"),
    );
  });
}
