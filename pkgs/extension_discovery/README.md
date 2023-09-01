[![package:extension_discovery](https://github.com/dart-lang/tools/actions/workflows/extension_discovery.yml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/extension_discovery.yml)
[![pub package](https://img.shields.io/pub/v/extension_discovery.svg)](https://pub.dev/packages/extension_discovery)
[![package publisher](https://img.shields.io/pub/publisher/extension_discovery.svg)](https://pub.dev/packages/extension_discovery/publisher)

A convention and utilities for package extension discovery.

## What's this?

A convention to allow other packages to provide extensions for your package
(or tool). Including logic for finding extensions that honor this convention.

The convention implemented in this package is that if `foo` provides an
extension for `<targetPackage>`.
Then `foo` must contain a config file `extension/<targetPackage>/config.yaml`.
This file indicates that `foo` provides an extension for `<targetPackage>`.

If `<targetPackage>` accepts extensions from other packages it must:
 * Find extensions using `findExtensions('<targetPackage>')` from this package.
 * Document how extensions are implemented:
   * What should the contents of the `extension/<targetPackage>/config.yaml` file be?
   * Should packages providing extensions have a dependency constraint on `<targetPackage>`?
   * What libraries/assets should packages that provide extensions include?
   * Should packages providing extensions specify a [topic in `pubspec.yaml`][1]
     for easy discovery on pub.dev.

The `findExtensions(targetPackage, packageConfig: ...)` function will:
 * Load `.dart_tool/package_config.json` and find all packages that contain a
   valid YAML file: `extension/<targetPackage>/config.yaml`.
 * Provide the package name, location and contents of the `config.yaml` file,
   for all detected extensions (aimed at `targetPackage`).
 * Cache the results for fast loading, comparing modification timestamps to
   ensure consistent results.

It is the responsibility package that can be extended to validate extensions,
decide when they should be enabled, and documenting how such extensions are
created.


## Packages that extend tools

You can also use this package (and associated convention), if you are developing
a tool that can be extended by packages. In this case, you would call
`findExtensions(<my_tool_package_name>, packageConfig: ...)` where
`packageConfig` points to the `.dart_tool/package_config.json` in the workspace
the tool is operating on.

If you tool is not distributed through pub.dev, you might consider publishing
a placeholder package in order to reserve a unique name (and avoid collisions).
Using a placeholder package to reserve a unique is also recommended for tools
that wish to cache files in `.dart_tool/<my_tool_package_name>/`.
See [package layout documentation][2] for details.


## Example: Hello World

Imagine that we have a `hello_world` package that defines a single method
`sayHello(String language)`, along the lines of:

```dart
void sayHello(String language) {
  if (language == 'danish') {
    print('Hej verden');
  } else {
    print('Hello world!');
  }
}
```

### Enabling packages to extend `hello_world`

If we wanted to allow other packages to provide additional languages by
extending the `hello_world` package. Then we could do:

```dart
import 'package:extension_discovery/extension_discovery.dart';

Future<void> sayHello(String language) async {
  // Find extensions for the "hello_world" package.
  // WARNING: This only works when running in JIT-mode, if running in AOT-mode
  //          you must supply the `packageConfig` argument, and have a local
  //          `.dart_tool/package_config.json` and `$PUB_CACHE`.
  //          See "Runtime limitations" section further down.
  final extensions = await findExtensions('hello_world');

  // Search extensions to see if one provides a message for language
  for (final ext in extensions) {
    final config = ext.config;
    if (config is! Map<String, Object?>) {
      continue; // ignore extensions with invalid configation
    }
    if (config['language'] == language) {
      print(config['message']);
      return; // Don't print more messages!
    }
  }

  if (language == 'danish') {
    print('Hej verden');
  } else {
    print('Hello world!');
  }
}
```

The `findExtensions` function will search other packages for
`extension/hello_world/config.yaml`, and provide the contents of this file as
well as provide the location of the extending packages.
As authors of the `hello_world` package we should also document how other
packages can extend `hello_world`. This is typically done by adding a segment
to the `README.md`.


### Extending `hello_world` from another package

If in another package `hello_world_german` we wanted to extend `hello_world`
and provide a translation for German, then we would create a
`hello_world_german` package containing an
**`extension/hello_world/config.yaml`**:

```yaml
language: german
message: "Hello Welt!"
```

Obviously, this is a contrived example. The authors of the `hello_world` package
could specify all sorts configuration options that extension authors can
specify in `extension/hello_world/config.yaml`.

The authors of `hello_world` could also specify that extensions must provide
certain assets in `extension/hello_world/` or that they must provide certain
Dart libraries implementing a specified interface somewhere in `lib/src/...`.

It is up to the authors of `hello_world` to specify what extension authors must
provide. The `extension_discovery` package only provides a utility for finding
extensions.


### Using `hello_world` and `hello_world_german`

If writing `my_hello_world_app` I can now take advantage of `hello_world` and
`hello_world_german`. Simply write a `pubspec.yaml` as follows:

```yaml
# pubspec.yaml
name: my_hello_world_app
dependencies:
  hello_world: ^1.0.0
  hello_world_german: ^1.0.0
environment:
  sdk: ^3.0.0
```

Then I can write a `bin/hello.dart` as follows:

```dart
// bin/hello.dart
import 'package:hello_world/hello_world.dart';

Future<void> main() async {
  await sayHello('german');
}
```


## What can an extension provide?

As far as the `extension_discovery` package is concerned an extension can
provide anything. Naturally, it is the authors of the extendable package that
decides what extensions can be provide.

In the example above it is the authors of the `hello_world` package that decides
what extension packages can provide. For this reason it is important that the
authors of `hello_world` very explicitly document how an extension is written.

Obviously, authors of `hello_world` should document what should be specified in
`extension/hello_world/config.yaml`. They could also specify that other files
should be provided in `extension/hello_world/`, or that certain Dart libraries
should be provided in `lib/src/hello_world/...` or something like that.

When authors of `hello_world` consumes the extensions discovered through
`findExtensions` they would naturally also be wise to validate that the
extension provides the required configuration and files.


## Compatibility considerations

When writing an extension it is strongly encouraged to have a dependency
constraint on the package being extended. This ensures that the extending
package will be incompatibility with new major versions of the extended package.

In the example above, it is strongly encouraged for `hello_world_german` to
have a dependency constraint `hello_world: ^1.0.0`. Even if `hello_world_german`
doesn't import libraries from `package:hello_world`.

Because the next major version of `hello_world` (version `2.0.0`) might change
what is required of an extension. Thus, it's fair to assume that
`hello_world_german` might not be compatible with newer versions of
`hello_world`. Hence, adding a dependency constraint `hello_world: ^1.0.0` saves
users from resolving dependencies that aren't compatible.

Naturally, after a new major version of `hello_world` is published a new
version of `hello_world_german` can then also be published, addressing any
breaking changes and bumping the dependency constraint.

**Tip:** Authors of packages that can be extended might want to force extension
authors take dependency on their package, to ensure that they have the ability
to do breaking changes in the future.


## Runtime limitations

The `findExtensions` function only works when running in JIT-mode, otherwise the
`packageConfig` parameter must be used to provide the location of
`.dart_tool/package_config.json`. Obviously, the `package_config.json` must be
present, as must the pub-cache locations referenced here.

Hence, `findExtensions` effectively **only works from project workspace!**.

You can't use `findExtensions` in a compiled Flutter application or an
AOT-compiled executable distributed to end-users. Because in these environments
you don't have a `package_config.json` nor do you have a pub-cache. You don't
even have access to your own source files.

If your deployment target a compiled Flutter application or AOT-compiled
executable, then you will have to create some code/asset-generation.
You code/asset-generation scripts can use `findExtensions` to find extensions,
and then use the assets or Dart libraries from here to generate assets or code
that is embedded in the final Flutter application (or AOT-compiled executable).

This makes `findExtensions` immediately useful, if you are writing development
tools that users will install into their project workspace. But if you're
writing a package for use in deployed applications, you'll likely need to figure
out how to embed the extensions, `findExtensions` only helps
you find the extensions during code-gen.

[1]: https://dart.dev/tools/pub/pubspec#topics
[2]: https://dart.dev/tools/pub/package-layout#project-specific-caching-for-tools
