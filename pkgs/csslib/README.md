[![Dart CI](https://github.com/dart-lang/csslib/actions/workflows/test-package.yml/badge.svg)](https://github.com/dart-lang/csslib/actions/workflows/test-package.yml)
[![pub package](https://img.shields.io/pub/v/csslib.svg)](https://pub.dev/packages/csslib)
[![package publisher](https://img.shields.io/pub/publisher/csslib.svg)](https://pub.dev/packages/csslib/publisher)

A Dart [CSS](https://developer.mozilla.org/en-US/docs/Web/CSS) parser.

## Usage

Parsing CSS is easy!

```dart
import 'package:csslib/parser.dart';

main() {
  var stylesheet = parse(
      '.foo { color: red; left: 20px; top: 20px; width: 100px; height:200px }');
  print(stylesheet.toDebugString());
}
```

You can pass a `String` or `List<int>` to `parse`.
