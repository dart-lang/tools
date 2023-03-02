[![Dart CI](https://github.com/dart-lang/yaml_edit/actions/workflows/test-package.yml/badge.svg)](https://github.com/dart-lang/yaml_edit/actions/workflows/test-package.yml)
[![pub package](https://img.shields.io/pub/v/yaml_edit.svg)](https://pub.dev/packages/yaml_edit)
[![package publisher](https://img.shields.io/pub/publisher/yaml_edit.svg)](https://pub.dev/packages/yaml_edit/publisher)
[![Coverage Status](https://coveralls.io/repos/github/dart-lang/yaml_edit/badge.svg)](https://coveralls.io/github/dart-lang/yaml_edit)

A library for [YAML](https://yaml.org) manipulation while preserving comments.

## Usage

A simple usage example:

```dart
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final yamlEditor = YamlEditor('{YAML: YAML}');
  yamlEditor.update(['YAML'], "YAML Ain't Markup Language");
  print(yamlEditor);
  // Expected output:
  // {YAML: YAML Ain't Markup Language}
}
```

### Example: Converting JSON to YAML (block formatted)

```dart
void main() {
  final jsonString = r'''
{
  "key": "value",
  "list": [
    "first",
    "second",
    "last entry in the list"
  ],
  "map": {
    "multiline": "this is a fairly long string with\nline breaks..."
  }
}
''';
  final jsonValue = json.decode(jsonString);

  // Convert jsonValue to YAML
  final yamlEditor = YamlEditor('');
  yamlEditor.update([], jsonValue);
  print(yamlEditor.toString());
}
```

## Testing

Testing is done in two strategies: Unit testing (`/test/editor_test.dart`) and
Golden testing (`/test/golden_test.dart`). More information on Golden testing
and the input/output format can be found at `/test/testdata/README.md`.

These tests are automatically run with `pub run test`.

## Limitations

1. Users are not allowed to define tags in the modifications.
2. Map keys will always be added in the flow style.
