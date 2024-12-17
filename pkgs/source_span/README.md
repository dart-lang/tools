[![Build Status](https://github.com/dart-lang/tools/actions/workflows/source_span.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/source_span.yaml)
[![pub package](https://img.shields.io/pub/v/source_span.svg)](https://pub.dev/packages/source_span)
[![package publisher](https://img.shields.io/pub/publisher/source_span.svg)](https://pub.dev/packages/source_span/publisher)

## About this package

`source_span` is a library for tracking locations in source code. It's designed
to provide a standard representation for source code locations and spans so that
disparate packages can easily pass them among one another, and to make it easy
to generate human-friendly messages associated with a given piece of code.

The most commonly-used class is the package's namesake, `SourceSpan`. It
represents a span of characters in some source file, and is often attached to an
object that has been parsed to indicate where it was parsed from. It provides
access to the text of the span via `SourceSpan.text` and can be used to produce
human-friendly messages using `SourceSpan.message()`.

When parsing code from a file, `SourceFile` is useful. Not only does it provide
an efficient means of computing line and column numbers, `SourceFile.span()`
returns special `FileSpan`s that are able to provide more context for their
error messages.
