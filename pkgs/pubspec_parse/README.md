[![Build Status](https://github.com/dart-lang/tools/actions/workflows/pubspec_parse.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/pubspec_parse.yaml)
[![pub package](https://img.shields.io/pub/v/pubspec_parse.svg)](https://pub.dev/packages/pubspec_parse)
[![package publisher](https://img.shields.io/pub/publisher/pubspec_parse.svg)](https://pub.dev/packages/pubspec_parse/publisher)

## What's this?

Supports parsing `pubspec.yaml` files with robust error reporting and support
for most of the documented features.

## Usage

Parse a `pubspec.yaml` string with `Pubspec.parse`:

```dart
import 'package:pubspec_parse/pubspec_parse.dart';

void main() {
  const yaml = '''
name: my_package
version: 1.2.3
environment:
  sdk: ^3.8.0
dependencies:
  collection: ^1.19.0
  path:
    path: ../path
''';

  final pubspec = Pubspec.parse(yaml);
  print(pubspec.name); // my_package
  print(pubspec.version); // 1.2.3

  final collection = pubspec.dependencies['collection'];
  if (collection is HostedDependency) {
    print(collection.version); // ^1.19.0
  }

  final path = pubspec.dependencies['path'];
  if (path is PathDependency) {
    print(path.path); // ../path
  }
}
```

`Pubspec.parse` throws a `ParsedYamlException` from `package:checked_yaml` when
a field is invalid. Pass `lenient: true` to ignore unknown or invalid top-level
keys.

To load a file:

```dart
import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';

void main() {
  final yaml = File('pubspec.yaml').readAsStringSync();
  final pubspec = Pubspec.parse(yaml, sourceUrl: Uri.parse('pubspec.yaml'));
  print('${pubspec.name} ${pubspec.version}');
}
```

## More information

Read more about the [pubspec format](https://dart.dev/tools/pub/pubspec).
