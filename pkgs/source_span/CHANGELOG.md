# 1.1.4

* Eliminated dart2js warning about overriding `==`, but not `hashCode`.

# 1.1.3

* `FileSpan.compareTo`, `FileSpan.==`, `FileSpan.union`, and `FileSpan.expand`
  no longer throw exceptions for external implementations of `FileSpan`.

* `FileSpan.hashCode` now fully agrees with `FileSpan.==`.

# 1.1.2

* Fixed validation in `SourceSpanWithContext` to allow multiple occurrences of
  `text` within `context`.

# 1.1.1

* Fixed `FileSpan`'s context to include the full span text, not just the first
  line of it.

# 1.1.0

* Added `SourceSpanWithContext`: a span that also includes the full line of text
  that contains the span.

# 1.0.3

* Cleanup equality operator to accept any Object rather than just a
  `SourceLocation`.

# 1.0.2

* Avoid unintentionally allocating extra objects for internal `FileSpan`
  operations.

* Ensure that `SourceSpan.operator==` works on arbitrary `Object`s.

# 1.0.1

* Use a more compact internal representation for `FileSpan`.

# 1.0.0

This package was extracted from the
[`source_maps`](http://pub.dartlang.org/packages/source_maps) package, but the
API has many differences. Among them:

* `Span` has been renamed to `SourceSpan` and `Location` has been renamed to
  `SourceLocation` to clarify their purpose and maintain consistency with the
  package name. Likewise, `SpanException` is now `SourceSpanException` and
  `SpanFormatException` is not `SourceSpanFormatException`.

* `FixedSpan` and `FixedLocation` have been rolled into the `Span` and
  `Location` classes, respectively.

* `SourceFile` is more aggressive about validating its arguments. Out-of-bounds
  lines, columns, and offsets will now throw errors rather than be silently
  clamped.

* `SourceSpan.sourceUrl`, `SourceLocation.sourceUrl`, and `SourceFile.url` now
  return `Uri` objects rather than `String`s. The constructors allow either
  `String`s or `Uri`s.

* `Span.getLocationMessage` and `SourceFile.getLocationMessage` are now
  `SourceSpan.message` and `SourceFile.message`, respectively. Rather than
  taking both a `useColor` and a `color` parameter, they now take a single
  `color` parameter that controls both whether and which color is used.

* `Span.isIdentifier` has been removed. This property doesn't make sense outside
  of a source map context.

* `SourceFileSegment` has been removed. This class wasn't widely used and was
  inconsistent in its choice of which parameters were considered relative and
  which absolute.
