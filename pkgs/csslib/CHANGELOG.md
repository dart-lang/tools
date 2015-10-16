## 0.12.2

 * Fix to handle calc functions however, the expressions are treated as a
   LiteralTerm and not fully parsed into the AST.

## 0.12.1

 * Fix to handling of escapes in strings.

## 0.12.0+1

* Allow the lastest version of `logging` package.

## 0.12.0

* Top-level methods in `parser.dart` now take `PreprocessorOptions` instead of
  `List<String>`.

* `PreprocessorOptions.inputFile` is now final.

## 0.11.0+4

* Cleanup some ambiguous and some incorrect type signatures.

## 0.11.0+3

* Improve the speed and memory efficiency of parsing.

## 0.11.0+2

* Fix another test that was failing on IE10.

## 0.11.0+1

* Fix a test that was failing on IE10.

## 0.11.0

* Switch from `source_maps`' `Span` class to `source_span`'s `SourceSpan` class.
