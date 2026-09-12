[![Build Status](https://github.com/dart-lang/tools/actions/workflows/pubspec_parse.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/pubspec_parse.yaml)
[![pub package](https://img.shields.io/pub/v/pubspec_parse.svg)](https://pub.dev/packages/pubspec_parse)
[![package publisher](https://img.shields.io/pub/publisher/pubspec_parse.svg)](https://pub.dev/packages/pubspec_parse/publisher)

## What's this?

Supports parsing `pubspec.yaml` files with robust error reporting and support
for most of the documented features.

## Usage

Parse a `pubspec.yaml` string with `Pubspec.parse`. Hosted and path
dependencies come back as `HostedDependency` and `PathDependency`.

`Pubspec.parse` throws a `ParsedYamlException` from `package:checked_yaml` when
a field is invalid. Pass `lenient: true` to ignore unknown or invalid top-level
keys.

A complete example, including loading from a file, is in
[example/example.dart](example/example.dart).

## More information

Read more about the [pubspec format](https://dart.dev/tools/pub/pubspec).
