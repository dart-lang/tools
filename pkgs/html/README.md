[![Build Status](https://github.com/dart-lang/tools/actions/workflows/html.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/html.yaml)
[![pub package](https://img.shields.io/pub/v/html.svg)](https://pub.dev/packages/html)
[![package publisher](https://img.shields.io/pub/publisher/html.svg)](https://pub.dev/packages/html/publisher)

A Dart implementation of an HTML5 parser.

## Usage

Parsing HTML is easy!

```dart
import 'package:html/parser.dart';

void main() {
  var document = parse(
      '<body>Hello world! <a href="www.html5rocks.com">HTML5 rocks!');
  print(document.outerHtml);
}
```

You can pass a String or list of bytes to `parse`. There's also `parseFragment`
for parsing a document fragment, and `HtmlParser` if you want more low level
control.

> [!WARNING]
> Per the [WHATWG HTML specification][whatwg-serialize] (and matching browsers
> such as Chrome), the output of `innerHtml` and `outerHtml`, if parsed with an
> HTML parser, may not return the original tree structure—even for trees
> produced by the HTML parser itself.
>
> Do not use `innerHtml` or `outerHtml` for HTML sanitization, as this can lead
> to mutation XSS (mXSS). Consider using [`package:sanitize_html`][sanitize_html]
> instead.

## Background

This package was a port of the Python
[html5lib](https://github.com/html5lib/html5lib-python) library.

[whatwg-serialize]: https://html.spec.whatwg.org/multipage/parsing.html#serializing-html-fragments
[sanitize_html]: https://pub.dev/packages/sanitize_html
