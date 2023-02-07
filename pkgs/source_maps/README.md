[![Dart CI](https://github.com/dart-lang/source_maps/actions/workflows/test-package.yml/badge.svg)](https://github.com/dart-lang/source_maps/actions/workflows/test-package.yml)
[![pub package](https://img.shields.io/pub/v/source_maps.svg)](https://pub.dev/packages/source_maps)
[![package publisher](https://img.shields.io/pub/publisher/source_maps.svg)](https://pub.dev/packages/source_maps/publisher)

This project implements a Dart pub package to work with source maps.

## Docs and usage

The implementation is based on the [source map version 3 spec][spec] which was
originated from the [Closure Compiler][closure] and has been implemented in
Chrome and Firefox.

In this package we provide:

  * Data types defining file locations and spans: these are not part of the
    original source map specification. These data types are great for tracking
    source locations on source maps, but they can also be used by tools to
    reporting useful error messages that include on source locations.
  * A builder that creates a source map programatically and produces the encoded
    source map format.
  * A parser that reads the source map format and provides APIs to read the
    mapping information.

[closure]: https://github.com/google/closure-compiler/wiki/Source-Maps
[spec]: https://docs.google.com/a/google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit
