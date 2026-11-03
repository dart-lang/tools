// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

import 'exception.dart';
import 'line_scanner.dart';
import 'span_scanner.dart';
import 'string_scanner.dart';
import 'utils.dart';

/// A [SpanScanner] that scans within an existing [FileSpan].
///
/// This re-implements chunks of [SpanScanner] rather than using a dummy span or
/// inheritance because scanning is often a performance-critical operation, so
/// it's important to avoid adding extra overhead when relative scanning isn't
/// needed.
class RelativeSpanScanner extends StringScanner implements SpanScanner {
  /// The source of the scanner.
  ///
  /// This caches line break information and is used to generate [SourceSpan]s.
  final SourceFile _sourceFile;

  /// The start location of the span within which this scanner is scanning.
  ///
  /// This is used to convert between span-relative and file-relative fields.
  final FileLocation _startLocation;

  @override
  int get line => _lineFor(position);

  @override
  int get column => _columnFor(position);

  int _lineFor(int position) =>
      _sourceFile.getLine(_startLocation.offset + position) -
      _startLocation.line;

  int _columnFor(int position) {
    final offset = _startLocation.offset + position;
    final line = _sourceFile.getLine(offset);
    final column = _sourceFile.getColumn(offset, line: line);
    return line == _startLocation.line
        ? column - _startLocation.column
        : column;
  }

  @override
  LineScannerState get state => _SpanScannerState(this, position);

  @override
  set state(LineScannerState state) {
    if (state is! _SpanScannerState || !identical(state._scanner, this)) {
      throw ArgumentError('The given LineScannerState was not returned by '
          'this LineScanner.');
    }

    position = state.position;
  }

  @override
  FileSpan? get lastSpan {
    if (lastMatch == null) _lastSpan = null;
    return _lastSpan;
  }

  FileSpan? _lastSpan;

  @override
  FileLocation get location =>
      _sourceFile.location(_startLocation.offset + position);

  @override
  FileSpan get emptySpan => location.pointSpan();

  RelativeSpanScanner(FileSpan span)
      : _sourceFile = span.file,
        _startLocation = span.start,
        super(span.text, sourceUrl: span.sourceUrl);

  @override
  FileSpan spanFrom(LineScannerState startState, [LineScannerState? endState]) {
    final endPosition = endState == null ? position : endState.position;
    return _sourceFile.span(_startLocation.offset + startState.position,
        _startLocation.offset + endPosition);
  }

  @override
  FileSpan spanFromPosition(int startPosition, [int? endPosition]) {
    endPosition ??= position;
    RangeError.checkValidRange(startPosition, endPosition, string.length,
        'startPosition', 'endPosition');
    return _sourceFile.span(_startLocation.offset + startPosition,
        _startLocation.offset + endPosition);
  }

  @override
  bool matches(Pattern pattern) {
    if (!super.matches(pattern)) {
      _lastSpan = null;
      return false;
    }

    _lastSpan = _sourceFile.span(_startLocation.offset + position,
        _startLocation.offset + lastMatch!.end);
    return true;
  }

  @override
  Never error(String message, {Match? match, int? position, int? length}) {
    if (match == null && position == null && length == null) match = lastMatch;
    (position, length) =
        resolveErrorArgs(string, match, position, length, this.position);

    final span = _sourceFile.span(_startLocation.offset + position,
        _startLocation.offset + position + length);
    throw StringScannerException(message, span, string);
  }
}

/// A class representing the state of a [SpanScanner].
class _SpanScannerState implements LineScannerState {
  /// The [SpanScanner] that created this.
  final RelativeSpanScanner _scanner;

  @override
  final int position;
  @override
  int get line => _scanner._lineFor(position);
  @override
  int get column => _scanner._columnFor(position);

  _SpanScannerState(this._scanner, this.position);
}
