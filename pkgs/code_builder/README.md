[![Dart CI](https://github.com/dart-lang/code_builder/actions/workflows/test-package.yml/badge.svg)](https://github.com/dart-lang/code_builder/actions/workflows/test-package.yml)
[![Pub package](https://img.shields.io/pub/v/code_builder.svg)](https://pub.dev/packages/code_builder)
[![package publisher](https://img.shields.io/pub/publisher/code_builder.svg)](https://pub.dev/packages/code_builder/publisher)
[![Gitter chat](https://badges.gitter.im/dart-lang/build.svg)](https://gitter.im/dart-lang/build)

A fluent, builder-based library for generating valid Dart code.

## Usage

`code_builder` has a narrow and user-friendly API.

See the `example` and `test` folders for additional examples.

For example creating a class with a method:

```dart
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

void main() {
  final animal = Class((b) => b
    ..name = 'Animal'
    ..extend = refer('Organism')
    ..methods.add(Method.returnsVoid((b) => b
      ..name = 'eat'
      ..body = const Code("print('Yum!');"))));
  final emitter = DartEmitter();
  print(
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format('${animal.accept(emitter)}'),
  );
}
```

Outputs:

```dart
class Animal extends Organism {
  void eat() => print('Yum!');
}
```

Have a complicated set of dependencies for your generated code? `code_builder`
supports automatic scoping of your ASTs to automatically use prefixes to avoid
symbol conflicts:

```dart
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

void main() {
  final library = Library((b) => b.body.addAll([
        Method((b) => b
          ..body = const Code('')
          ..name = 'doThing'
          ..returns = refer('Thing', 'package:a/a.dart')),
        Method((b) => b
          ..body = const Code('')
          ..name = 'doOther'
          ..returns = refer('Other', 'package:b/b.dart')),
      ]));
  final emitter = DartEmitter.scoped();
  print(
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format('${library.accept(emitter)}'),
  );
}
```

Outputs:

```dart
import 'package:a/a.dart' as _i1;
import 'package:b/b.dart' as _i2;

_i1.Thing doThing() {}
_i2.Other doOther() {}
```

## Contributing

- Read and help us document common patterns over [at the wiki][wiki].
- Is there a _bug_ in the code? [File an issue][issue].

If a feature is missing (the Dart language is always evolving) or you'd like an
easier or better way to do something, consider [opening a pull request][pull].
You can always [file an issue][issue], but generally speaking, feature requests
will be on a best-effort basis.

> **NOTE**: Due to the evolving Dart SDK the local `dartfmt` must be used to
> format this repository. You can run it simply from the command-line:
>
> ```sh
> $ dart run dart_style:format -w .
> ```

[wiki]: https://github.com/dart-lang/code_builder/wiki
[issue]: https://github.com/dart-lang/code_builder/issues
[pull]: https://github.com/dart-lang/code_builder/pulls

### Updating generated (`.g.dart`) files

> **NOTE**: There is currently a limitation in `build_runner` that requires a
> workaround for developing this package since it is a dependency of the build
> system.

Make a snapshot of the generated [`build_runner`][build_runner] build script and
run from the snapshot instead of from source to avoid problems with deleted
files. These steps must be run without deleting the source files.

```bash
./tool/regenerate.sh
```

[build_runner]: https://pub.dev/packages/build_runner
