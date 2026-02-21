[![Build Status](https://github.com/dart-lang/tools/actions/workflows/code_builder.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/code_builder.yaml)
[![Pub package](https://img.shields.io/pub/v/code_builder.svg)](https://pub.dev/packages/code_builder)
[![package publisher](https://img.shields.io/pub/publisher/code_builder.svg)](https://pub.dev/packages/code_builder/publisher)
[![Gitter chat](https://badges.gitter.im/dart-lang/build.svg)](https://gitter.im/dart-lang/build)

A fluent, builder-based library for generating valid Dart code.

## Basic Usage

`code_builder` has a narrow and user-friendly API.

Most Dart syntax structures are created using builders. For example, an empty class:

```dart
final animal = Class((builder) => builder
    ..name = 'Animal'
    ..extend = refer('Organism')
);
```

Will produce:

```dart
class Animal extends Organism {}
```

If you're not a fan of nesting, you can create a builder directly and then call the `build` function. For example, adding a method to our class:

```dart
final method = MethodBuilder()
  ..name = 'eat'
  ..body = refer('print').call([literal('Yum!')]).statement // print('Yum!');
  ..lambda = true;

final animal = Class((builder) => builder
    ..name = 'Animal'
    ..extend = refer('Organism')
    ..methods.add(method.build()) // MethodBuilder -> Method
);
```

Will produce:

```dart
class Animal extends Organism {
  void eat() => print('Yum!');
}
```

Then, when finished, use a `DartEmitter` and the `accept` method to build the `code_builder` structures into valid Dart code. For example:

```dart
import 'package:dart_style/dart_style.dart';

// ... //

final emitter = DartEmitter();

// Generate code for 'animal' into a new StringBuffer 
final StringSink result = animal.accept(emitter);

// or, add it to an existing one
final buffer = StringBuffer();
animal.accept(emitter, buffer);

// format the output using package:dart_style
final String formatted = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion)
    .format(result.toString());

// voilà
print(formatted);
```

Will output the code from above.

For more usage examples see the [example] and [test] folders.

[example]: https://github.com/dart-lang/tools/tree/main/pkgs/code_builder/example
[test]: https://github.com/dart-lang/tools/tree/main/pkgs/code_builder/test

## Automatic Scoping

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

  // use a scoped DartEmitter to enable automatic prefixing
  // using Allocator.simplePrefixing
  final emitter = DartEmitter.scoped();

  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion)
        .format(library.accept(emitter).toString());

  print(formatted);
}
```

Will output:

```dart
import 'package:a/a.dart' as _i1;
import 'package:b/b.dart' as _i2;

_i1.Thing doThing() {}
_i2.Other doOther() {}
```

## Contributing

- Read and help us document common patterns over [in the docs][docs].
- Is there a _bug_ in the code? [File an issue][issue].

If a feature is missing (the Dart language is always evolving) or you'd like an
easier or better way to do something, consider [opening a pull request][pull].
You can always [file an issue][issue], but generally speaking, feature requests
will be on a best-effort basis.

> **NOTE**: Due to the evolving Dart SDK the local `dartfmt` must be used to
> format this repository. You can run it simply from the command-line:
>
> ```sh
> dart run dart_style:format -w .
> ```

[issue]: https://github.com/dart-lang/tools/issues
[pull]: https://github.com/dart-lang/tools/pulls
[docs]: https://pub.dev/documentation/code_builder/latest/

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
