// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// @docImport 'package:cli_util/windows_compatibility.dart';
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'keys.dart';
import 'select_component_sizing.dart';

/// An option in a selection dialog, with a primary [label] and an optional
/// [description] shown when the option is hovered.
final class SelectOption {
  /// The main text displayed for this option.
  final String label;

  /// Additional description text displayed below [label] when this option
  /// is hovered.
  ///
  /// May contain newlines (`\n` or `\r\n`) and ANSI SGR styling sequences
  /// (e.g. `\x1b[...m`).
  final String? description;

  const SelectOption(this.label, {this.description});
}

/// Shows a scrollable terminal selection dialog and returns the set of
/// selected indices.
///
/// Each element in [options] must be either a [String] or a [SelectOption].
/// Only standard ASCII characters and ANSI SGR styling sequences (`\x1b[...m`)
/// should be used in the [options] (plus newlines in descriptions), as other
/// characters may break the width calculations.
///
/// Temporarily disables stdin line and echo modes, and restores them before
/// returning. Also intercepts [ProcessSignal.sigint] to cancel the dialog.
///
/// The cursor is hidden for the duration of the dialog and then re-shown. If
/// you want the cursor in a certain state after this dialog you will have to
/// restore it.
///
/// The [inputStream] is a list of input events (typically originating from
/// [stdin] or [Win32AnsiStdin]). See the `example/select_dialog.dart` for
/// recommended patterns.
///
/// The [sizing] parameter controls the maximum total height of the dialog and
/// the maximum number of lines displayed for a hovered option's description.
/// Defaults to [SelectComponentSizing.fit].
///
/// The deprecated [maxVisibleItems] parameter is not respected strictly as an
/// item count; if provided, it computes the maximum total height by adding the
/// maximum description height (`maxVisibleItems + maxDescriptionHeight`).
///
/// Returns `null` if the user aborts the dialog (e.g. by pressing Ctrl+C or
/// escape), there is no terminal attached to stdout, or the terminal is too
/// small to display the dialog.
Future<Set<int>?> showMultiSelectDialog(
  List<Object /* String|SelectOption */> options,
  Stream<List<int>> inputStream, {
  @Deprecated('Use sizing instead.') int? maxVisibleItems,
  SelectComponentSizing sizing = const SelectComponentSizing.fit(),
  Set<int> initialSelected = const {},
}) => _runDialog(
  options,
  inputStream,
  multiSelect: true,
  maxVisibleItems: maxVisibleItems,
  sizing: sizing,
  initialSelected: initialSelected,
);

/// Shows a scrollable terminal selection dialog and returns the selected index.
///
/// Each element in [options] must be either a [String] or a [SelectOption].
/// Only standard ASCII characters and ANSI SGR styling sequences (`\x1b[...m`)
/// should be used in the [options] (plus newlines in descriptions), as other
/// characters may break the width calculations.
///
/// Temporarily disables stdin line and echo modes, and restores them before
/// returning. Also intercepts [ProcessSignal.sigint] to cancel the dialog.
///
/// The cursor is hidden for the duration of the dialog and then re-shown. If
/// you want the cursor in a certain state after this dialog you will have to
/// restore it.
///
/// The [inputStream] is a list of input events (typically originating from
/// [stdin] or [Win32AnsiStdin]). See the `example/select_dialog.dart` for
/// recommended patterns.
///
/// The [sizing] parameter controls the maximum total height of the dialog and
/// the maximum number of lines displayed for a hovered option's description.
/// Defaults to [SelectComponentSizing.fit].
///
/// The deprecated [maxVisibleItems] parameter is not respected strictly as an
/// item count; if provided, it computes the maximum total height by adding the
/// maximum description height (`maxVisibleItems + maxDescriptionHeight`).
///
/// Returns `null` if the user aborts the dialog (e.g. by pressing Ctrl+C or
/// escape), there is no terminal attached to stdout, or the terminal is too
/// small to display the dialog.
Future<int?> showSingleSelectDialog(
  List<Object /* String|SelectOption */> options,
  Stream<List<int>> inputStream, {
  @Deprecated('Use sizing instead.') int? maxVisibleItems,
  SelectComponentSizing sizing = const SelectComponentSizing.fit(),
}) async {
  final selectedIndices = await _runDialog(
    options,
    inputStream,
    multiSelect: false,
    maxVisibleItems: maxVisibleItems,
    sizing: sizing,
    initialSelected: const {},
  );
  if (selectedIndices == null || selectedIndices.isEmpty) {
    return null;
  }
  return selectedIndices.single;
}

/// Internal utility to render a single or multi select dialog and return the
/// indices of the selected items.
Future<Set<int>?> _runDialog(
  List<Object /* String|SelectOption */> options,
  Stream<List<int>> inputStream, {
  required bool multiSelect,
  required int? maxVisibleItems,
  required SelectComponentSizing sizing,
  required Set<int> initialSelected,
}) async {
  final List<SelectOption> parsedOptions;
  try {
    assert(sizing.totalHeight >= 1, 'sizing.totalHeight must be at least 1.');
    assert(
      sizing.maxDescriptionHeight >= 0,
      'sizing.maxDescriptionHeight must be non-negative.',
    );
    assert(
      maxVisibleItems == null || maxVisibleItems >= 1,
      'maxVisibleItems must be at least 1.',
    );
    parsedOptions = _parseAndValidateOptions(options);
    assert(
      initialSelected.every((index) => index >= 0 && index < options.length),
      'All initialSelected indices must be within the range '
      '[0, options.length).',
    );
  } catch (e) {
    // Tests will hang if we don't listen here.
    await inputStream.listen((_) {}).cancel();
    rethrow;
  }

  final layout = _layoutDialog(
    parsedOptions,
    multiSelect: multiSelect,
    maxVisibleItems: maxVisibleItems,
    sizing: sizing,
  );
  if (layout == null) {
    // We do need to actually listen to this stream and immediately cancel, or
    // else it will never close in some cases.
    await inputStream.listen((_) {}).cancel();
    return null;
  }

  var cursorIndex = 0;
  // The options toggled with space and Ctrl+A, only used in multi-select mode.
  var selectedIndices = {...initialSelected};
  // In single-select mode, the hovered option is always the selected one.
  Set<int> selection() => multiSelect ? selectedIndices : {cursorIndex};

  var lastRenderedLines = 0;
  void render() {
    lastRenderedLines = _render(
      layout,
      cursor: cursorIndex,
      selected: selection(),
      previousRenderedLines: lastRenderedLines,
      multiSelect: multiSelect,
    );
  }

  final cleanupTasks = <FutureOr<void> Function()>[];
  try {
    // Move the terminal into the rendering state we want.
    if (stdin.hasTerminal) {
      final savedEchoMode = stdin.echoMode;
      // If echoMode is true, we must also restore lineMode to true, especially
      // on windows (it can get into invalid states).
      final savedLineMode = stdin.lineMode || savedEchoMode;
      cleanupTasks.add(() {
        // The order here matters for windows
        stdin.lineMode = savedLineMode;
        stdin.echoMode = savedEchoMode;
      });
      // The order here matters for windows
      stdin.echoMode = false;
      stdin.lineMode = false;
    }
    // Hide the cursor
    stdout.write(_ansiHideCursor);
    cleanupTasks.add(() => stdout.write('$_ansiShowCursor$_ansiReset'));

    // Completes with the final result or null if aborted.
    final doneCompleter = Completer<Set<int>?>();

    // Handle Ctrl+C and abort the dialog.
    final sigintSub = ProcessSignal.sigint.watch().listen((_) {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete(null);
      }
    });
    cleanupTasks.add(sigintSub.cancel);

    // Initial render
    render();

    final inputSub = inputStream.keys.listen((key) {
      final lastIndex = parsedOptions.length - 1;
      final pageItems = math.max(
        1,
        layout.maxTotalHeight - layout.descriptions[cursorIndex].length,
      );
      switch (key) {
        case Key.up:
          cursorIndex = (cursorIndex - 1).clamp(0, lastIndex);
        case Key.down:
          cursorIndex = (cursorIndex + 1).clamp(0, lastIndex);
        case Key.pageUp:
          cursorIndex = (cursorIndex - pageItems).clamp(0, lastIndex);
        case Key.pageDown:
          cursorIndex = (cursorIndex + pageItems).clamp(0, lastIndex);
        case Key.home:
          cursorIndex = 0;
        case Key.end:
          cursorIndex = lastIndex;
        case Key.space:
          selectedIndices = _toggled(selectedIndices, {cursorIndex});
        case Key.selectAll:
          selectedIndices = _toggled(
            selectedIndices,
            Iterable<int>.generate(parsedOptions.length).toSet(),
          );
        case Key.enter:
          doneCompleter.complete(selection());
          return;
        case Key.quit:
          doneCompleter.complete(null);
          return;
      }
      render();
    });
    // ignore: unnecessary_lambdas
    cleanupTasks.add(() {
      // Intentionally not awaited, this can block indefinitely on ctrl+c.
      inputSub.cancel();
    });

    return await doneCompleter.future;
  } finally {
    // Try to clear the dialog from the terminal.
    if (lastRenderedLines > 0) {
      final moveToTop = _ansiMoveToDialogStart(lastRenderedLines);
      final clearLines = List.filled(lastRenderedLines, _ansiClearLine);
      stdout.write('$moveToTop${clearLines.join('\n')}$moveToTop');
    }
    await [
      for (final cleanupTask in cleanupTasks) cleanupTask(),
    ].whereType<Future<void>>().wait;
  }
}

/// Returns a copy of [selected] with [indices] removed if they are all
/// selected, or added otherwise.
Set<int> _toggled(Set<int> selected, Set<int> indices) =>
    selected.containsAll(indices)
        ? selected.difference(indices)
        : selected.union(indices);

/// The display strings and dimensions of a dialog, see [_layoutDialog].
typedef _DialogLayout =
    ({
      List<String> items,
      List<List<String>> descriptions,
      int maxTotalHeight,
      bool isScrollable,
      int maxItemLength,
    });

/// Truncates the labels and word-wraps the descriptions of [options] to fit
/// the terminal, and computes the dimensions of the dialog.
///
/// The returned `items` and `descriptions` hold the display lines for each
/// option, `maxTotalHeight` is the maximum number of item and description
/// lines visible at once, `isScrollable` is whether a scrollbar is needed, and
/// `maxItemLength` is the visible length of the longest item or description
/// line.
///
/// Returns `null` if there are no [options], there is no terminal attached to
/// stdout, or the terminal is too small to display the dialog.
_DialogLayout? _layoutDialog(
  List<SelectOption> options, {
  required bool multiSelect,
  required int? maxVisibleItems,
  required SelectComponentSizing sizing,
}) {
  final legendLines = multiSelect ? 1 : 0;
  final maxRenderableLines = _terminalHeight - 1 - legendLines;
  final width = _terminalWidth;

  // Note that we just assume all terminals support ansii escapes because it
  // very rare nowadays not to, and the built in detection has a lot of false
  // negative cases (https://github.com/dart-lang/sdk/issues/31606).
  if (options.isEmpty || !stdout.hasTerminal || maxRenderableLines < 1) {
    return null;
  }

  final requestedItemAndDescHeight = math.max(
    1,
    sizing.totalHeight - legendLines,
  );
  final cappedMaxTotalHeight =
      maxVisibleItems == null
          ? math.min(requestedItemAndDescHeight, maxRenderableLines)
          : null;
  var effectiveMaxDescriptionLines =
      cappedMaxTotalHeight != null
          ? math.min(
            sizing.maxDescriptionHeight,
            requestedItemAndDescHeight > maxRenderableLines
                ? maxRenderableLines ~/ 2
                : cappedMaxTotalHeight - 1,
          )
          : math.min(sizing.maxDescriptionHeight, maxRenderableLines - 1);

  // First pass: wrap assuming non-scrollable or scrollable based on an initial
  // estimate to determine maxDescriptionHeight.
  final initialIsScrollable =
      options.length > (cappedMaxTotalHeight ?? maxVisibleItems!);
  var descriptions = _wrapDescriptions(
    options,
    _maxLineLength(width, multiSelect, initialIsScrollable),
    effectiveMaxDescriptionLines,
  );
  final maxDescriptionHeight = descriptions.fold(
    0,
    (max, lines) => math.max(max, lines.length),
  );

  var effectiveMaxTotalHeight =
      cappedMaxTotalHeight ?? (maxVisibleItems! + maxDescriptionHeight);
  if (effectiveMaxTotalHeight > maxRenderableLines) {
    effectiveMaxDescriptionLines = math.min(
      maxDescriptionHeight,
      maxRenderableLines ~/ 2,
    );
    final clampedBaseItems = math.min(
      maxVisibleItems!,
      maxRenderableLines - effectiveMaxDescriptionLines,
    );
    effectiveMaxDescriptionLines = math.min(
      maxDescriptionHeight,
      maxRenderableLines - clampedBaseItems,
    );
    effectiveMaxTotalHeight = clampedBaseItems + effectiveMaxDescriptionLines;
  }

  final minVisibleItems = math.max(
    1,
    effectiveMaxTotalHeight -
        math.min(maxDescriptionHeight, effectiveMaxDescriptionLines),
  );
  final isScrollable = options.length > minVisibleItems;
  // Now that we know if there is a scrollbar, check that the dialog fits.
  if (width < _minimumTerminalWidth(multiSelect, isScrollable)) return null;

  // Second pass: re-wrap if the scrollbar changed the line length limit, or
  // the descriptions need to be truncated to fewer lines.
  final limit = _maxLineLength(width, multiSelect, isScrollable);
  if (isScrollable != initialIsScrollable ||
      effectiveMaxDescriptionLines < maxDescriptionHeight) {
    descriptions = _wrapDescriptions(
      options,
      limit,
      effectiveMaxDescriptionLines,
    );
  }

  final items = [
    for (final option in options) _truncateLine(option.label, limit),
  ];
  final maxItemLength = [
    ...items,
    ...descriptions.expand((lines) => lines),
  ].map(_visibleLength).fold(0, math.max);
  return (
    items: items,
    descriptions: descriptions,
    maxTotalHeight: effectiveMaxTotalHeight,
    isScrollable: isScrollable,
    maxItemLength: maxItemLength,
  );
}

final _ansiSgrRegex = RegExp(r'\x1b\[[0-9;]*m');
final _newlineRegex = RegExp(r'\r?\n');

/// Parses [options] into [SelectOption]s and validates their characters.
List<SelectOption> _parseAndValidateOptions(
  List<Object /* String|SelectOption */> options,
) {
  final parsed = <SelectOption>[];
  for (final option in options) {
    final selectOption = switch (option) {
      String() => SelectOption(option),
      SelectOption() => option,
      _ =>
        throw ArgumentError.value(
          option,
          'options',
          'All options must be either a String or a SelectOption.',
        ),
    };
    assert(
      _isValidAsciiLine(selectOption.label),
      'All options must contain only standard ASCII and ANSI SGR escape '
      'sequences.',
    );
    final description = selectOption.description;
    if (description != null) {
      assert(
        description.split(_newlineRegex).every(_isValidAsciiLine),
        'All option descriptions must contain only standard ASCII, newlines, '
        'and ANSI SGR escape sequences.',
      );
    }
    parsed.add(selectOption);
  }
  return parsed;
}

bool _isValidAsciiLine(String line) {
  final stripped = line.replaceAll(_ansiSgrRegex, '');
  return stripped.codeUnits.every((c) => c >= 0x20 && c <= 0x7e);
}

int _visibleLength(String text) => text.replaceAll(_ansiSgrRegex, '').length;

/// Renders the selection menu to the terminal and returns the total number of
/// lines rendered.
///
/// This function handles:
///
/// - **Pagination**: It displays a window of items and the hovered item's
///   description within `layout.maxTotalHeight` lines, attempting to keep the
///   [cursor] centered.
/// - **Descriptions**: Renders any description lines for the hovered item
///   directly below it, aligned with the item label.
/// - **Scrollbar Rendering**: If `layout.isScrollable` is true, a scrollbar is
///   drawn on the right. The scrollbar physics ensure that the thumb only
///   reaches the top/bottom extremes when the list is actually at the extremes,
///   while moving consistently in between.
/// - **Selection Markers**: Renders checkboxes for multi-select mode, and bolds
///   the hovered option, as well as marking it with a pointer (`>`).
///
/// Parameters:
/// - [layout]: The display lines and dimensions of the dialog, see
///   [_layoutDialog]. Its `maxItemLength` is used for consistent spacing
///   between the text and the scrollbar.
/// - [cursor]: The current hovered index in the list.
/// - [selected]: The set of indices that are currently selected.
/// - [previousRenderedLines]: The number of lines rendered in the previous
///   frame (`0` on the initial render).
/// - [multiSelect]: If true, renders checkboxes.
int _render(
  _DialogLayout layout, {
  required int cursor,
  required Set<int> selected,
  required int previousRenderedLines,
  required bool multiSelect,
}) {
  final (
    :items,
    :descriptions,
    :maxTotalHeight,
    :isScrollable,
    :maxItemLength,
  ) = layout;

  // Calculate the window of items to display given the hovered item's
  // description height, keeping the cursor centered where possible.
  final hoveredDescriptions = descriptions[cursor];
  final windowHeight = math.max(1, maxTotalHeight - hoveredDescriptions.length);
  final maxStart = math.max(0, items.length - windowHeight);
  final start = (cursor - windowHeight ~/ 2).clamp(0, maxStart);
  final end = math.min(start + windowHeight, items.length);

  // Each item gets a pointer (`>` if hovered) and, in multi-select mode, a
  // checkbox. Description lines are aligned with the item labels.
  final (checked, unchecked) = multiSelect ? ('[x] ', '[ ] ') : ('', '');
  String itemRow(String pointer, int i) =>
      '$pointer${selected.contains(i) ? checked : unchecked}${items[i]}';
  final prefixWidth = _pointerWidth + unchecked.length;
  final descriptionIndent = ' ' * prefixWidth;

  // The visible items, with the hovered item's description below it.
  final rows = [
    for (var i = start; i < cursor; i++) itemRow('  ', i),
    itemRow('> ', cursor),
    for (final line in hoveredDescriptions)
      line.isEmpty ? '' : '$descriptionIndent$line',
    for (var i = cursor + 1; i < end; i++) itemRow('  ', i),
  ];

  // Add the scrollbar (if any) to the right of each row.
  final scrollbar =
      isScrollable ? _scrollbar(start, end, items.length, rows.length) : null;
  final scrollbarColumn = prefixWidth + maxItemLength + _scrollbarLeftMargin;
  String addScrollbar(String row, int index) {
    if (scrollbar == null) return row;
    final padding = math.max(0, scrollbarColumn - _visibleLength(row));
    return '$row${' ' * padding}${scrollbar[index]}';
  }

  final lines = List.generate(rows.length, (i) => addScrollbar(rows[i], i));

  // Bold the hovered item, re-applying bold after any resets within it.
  final hovered = cursor - start;
  final boldLine = lines[hovered].replaceAll(
    _ansiReset,
    '$_ansiReset$_ansiBold',
  );
  lines[hovered] = '$_ansiBold$boldLine$_ansiReset';

  if (multiSelect) lines.add('$_ansiDim$multiSelectLegend$_ansiReset');

  // Draw over the previous render (if any).
  final clearPrefix = previousRenderedLines == 0 ? '' : _ansiClearLine;
  stdout.write(
    '${_ansiMoveToDialogStart(previousRenderedLines)}'
    '${lines.map((line) => '$clearPrefix$line').join('\n')}',
  );

  // If the previous render had more lines than this render, clear the extra
  // lines below and move the cursor back up to the bottom of the current
  // render.
  final extraLines = previousRenderedLines - lines.length;
  if (extraLines > 0) {
    stdout.write(
      '${'\n$_ansiClearLine' * extraLines}${_ansiMoveCursorUp(extraLines)}',
    );
  }

  return lines.length;
}

/// Returns the scrollbar glyph for each of the [trackHeight] rows of a dialog
/// that shows the items from [start] (inclusive) to [end] (exclusive) out of
/// [itemCount] items: `█` for the thumb, and `│` for the rest of the track.
///
/// The thumb only reaches the top/bottom of the track when the list is
/// actually scrolled to the top/bottom, while moving consistently in between.
List<String> _scrollbar(int start, int end, int itemCount, int trackHeight) {
  final visibleCount = end - start;
  // If all the items are visible, the thumb fills the whole track.
  if (visibleCount == itemCount) return List.filled(trackHeight, '█');

  // Calculate thumb height proportional to visible area, leaving room for at
  // least one track glyph (since not all items are visible).
  final maxThumbHeight = math.max(1, trackHeight - 1);
  final thumbHeight = (visibleCount * trackHeight / itemCount).round().clamp(
    1,
    maxThumbHeight,
  );
  // The max valid start index for the list window.
  final maxStart = itemCount - visibleCount;
  // The max valid start index for the thumb based on its size.
  final maxThumbStart = trackHeight - thumbHeight;

  // We want to ensure that the thumb reaches the absolute extremes
  // (top/bottom) ONLY when the list is actually scrolled to the extremes.
  // For intermediate values, we distribute them as equally as possible
  // among the remaining positions to ensure smooth, consistent movement.
  final int thumbStart;
  if (start == 0) {
    // Actual top of scroll range.
    thumbStart = 0;
  } else if (start == maxStart) {
    // Actual bottom of scroll range.
    thumbStart = maxThumbStart;
  } else if (maxThumbStart <= 1) {
    // Very small lists, only one of two positions available. The window isn't
    // at either end of the list here, so the cursor is centered in it.
    final cursor = start + visibleCount ~/ 2;
    thumbStart = cursor > itemCount / 2 ? maxThumbStart : 0;
  } else {
    // Map from 1..maxThumbStart-1 linearly
    thumbStart = 1 + ((start - 1) * (maxThumbStart - 1)) ~/ (maxStart - 1);
  }

  return [
    ...List.filled(thumbStart, '│'),
    ...List.filled(thumbHeight, '█'),
    ...List.filled(trackHeight - thumbStart - thumbHeight, '│'),
  ];
}

/// The legend text displayed at the bottom of multi-select dialogs, trimmed
/// to the terminal width.
@visibleForTesting
String get multiSelectLegend {
  const fullText =
      'Toggle: Space | Toggle All: Ctrl+A | Submit: Enter | Abort: Esc';
  final width = _terminalWidth;
  final limit = math.max(0, width - 1);
  return fullText.length > limit ? fullText.substring(0, limit) : fullText;
}

/// Returns the minimum width required to display a dialog with the given
/// configuration.
///
/// Does not take into account the actual options, but the margin of difference
/// there is small (this assumes options take the minimum option length plus
/// the length of the ellipsis).
int _minimumTerminalWidth(bool multiSelect, bool isScrollable) {
  final checkboxWidth = multiSelect ? 4 : 0;
  final scrollbarWidth = isScrollable ? (1 + _scrollbarLeftMargin) : 0;
  final totalNeeded =
      _pointerWidth +
      checkboxWidth +
      _minimumOptionLength +
      '...'.length +
      scrollbarWidth;
  return totalNeeded;
}

/// Returns the width of the terminal or 80 if it cannot be determined.
int get _terminalWidth {
  try {
    if (stdout.hasTerminal) {
      return stdout.terminalColumns;
    }
  } catch (_) {}
  // The default width if we fail to compute it.
  return 80;
}

/// Returns the height of the terminal or 10 if it cannot be determined.
int get _terminalHeight {
  try {
    if (stdout.hasTerminal) {
      return stdout.terminalLines;
    }
  } catch (_) {}
  // The default height if we fail to compute it.
  return 10;
}

/// Returns the maximum visible character length for an option or description
/// line given the terminal configuration, down to a minimum of
/// [_minimumOptionLength].
int _maxLineLength(int terminalWidth, bool multiSelect, bool isScrollable) {
  final selectionMarkerLength = multiSelect ? 4 /* ' [ ]' */ : 0;
  final scrollbarWidth = isScrollable ? 1 : 0;
  var maxOptionLength = terminalWidth - _pointerWidth - selectionMarkerLength;
  if (isScrollable) {
    maxOptionLength -= _scrollbarLeftMargin + scrollbarWidth;
  }
  return math.max(_minimumOptionLength, maxOptionLength);
}

/// Word-wraps the description of each of [options] to at most [maxLines] lines
/// of at most [limit] visible characters.
List<List<String>> _wrapDescriptions(
  List<SelectOption> options,
  int limit,
  int maxLines,
) => [
  for (final SelectOption(:description) in options)
    description == null || description.isEmpty
        ? const <String>[]
        : _wordWrapDescription(description, limit, maxLines),
];

/// Word-wraps [description] so each line has at most [limit] visible
/// characters, while preserving explicit newlines (`\n` or `\r\n`) and ANSI
/// SGR styling sequences across wrapped lines.
///
/// Returns at most [maxLines] lines. If the description exceeds [maxLines],
/// the last line is wrapped to `limit - 3` visible characters and suffixed
/// with `'...'`.
List<String> _wordWrapDescription(String description, int limit, int maxLines) {
  final paragraphs = description.split(_newlineRegex);
  final wrapped = <String>[];
  // Tracks active ANSI SGR styling sequences (e.g. `\x1b[32m`) across wrapped
  // lines and paragraphs. [_consumeLine] resets any active style at the end of
  // each line, which prevents open styles from bleeding into the scrollbar
  // (`█`/`│`) or the next line's indentation, and re-applies `activeStyle` at
  // the start of the next line to keep multi-line ANSI spans styled.
  var activeStyle = '';

  for (var p = 0; p < paragraphs.length && wrapped.length < maxLines; p++) {
    final paragraph = paragraphs[p];
    final hasMoreParagraphs = p < paragraphs.length - 1;
    var rawIndex = 0;

    do {
      final isLastLine = wrapped.length == maxLines - 1;
      final (:line, :nextIndex, activeStyle: nextStyle) = _consumeLine(
        paragraph,
        rawIndex,
        isLastLine ? math.max(0, limit - 3) : limit,
        activeStyle: activeStyle,
      );
      final ellipsis =
          isLastLine && (hasMoreParagraphs || nextIndex < paragraph.length)
              ? '...'
              : '';
      wrapped.add('$line$ellipsis');
      rawIndex = nextIndex;
      activeStyle = nextStyle;
    } while (rawIndex < paragraph.length && wrapped.length < maxLines);
  }
  return wrapped;
}

/// Consumes up to [maxVisibleChars] visible characters from [paragraph]
/// starting at [startIndex], breaking at the last space if the paragraph
/// overflows [maxVisibleChars], and preserving ANSI SGR styling sequences.
///
/// The returned `line` starts by re-applying [activeStyle], and ends with
/// [_ansiReset] if a style is still active. The returned `nextIndex` skips any
/// spaces at the line break.
({String line, int nextIndex, String activeStyle}) _consumeLine(
  String paragraph,
  int startIndex,
  int maxVisibleChars, {
  String activeStyle = '',
}) {
  final buffer = StringBuffer(activeStyle);
  var rawIndex = startIndex;
  var visibleCount = 0;
  // The buffer length, index, and style just after the last space on this
  // line, which is where we break the line if it overflows.
  ({int bufferLength, int rawIndex, String activeStyle})? lastSpace;

  while (rawIndex < paragraph.length) {
    final match = _ansiSgrRegex.matchAsPrefix(paragraph, rawIndex);
    if (match != null) {
      final seq = match.group(0)!;
      buffer.write(seq);
      activeStyle = _applySgr(activeStyle, seq);
      rawIndex = match.end;
      continue;
    }
    if (visibleCount == maxVisibleChars) break;

    final char = paragraph[rawIndex++];
    if (char == ' ' && visibleCount > 0) {
      lastSpace = (
        bufferLength: buffer.length,
        rawIndex: rawIndex,
        activeStyle: activeStyle,
      );
    }
    buffer.write(char);
    visibleCount++;
  }

  // If the line overflowed, rewind to the last space if one was seen on this
  // line, otherwise hard-break here.
  var line = buffer.toString();
  if (rawIndex < paragraph.length && lastSpace != null) {
    line = line.substring(0, lastSpace.bufferLength);
    rawIndex = lastSpace.rawIndex;
    activeStyle = lastSpace.activeStyle;
  }
  // Skip any spaces at the line break, so the next line doesn't start with
  // them.
  final next = _skipSpaces(paragraph, rawIndex, activeStyle);
  final reset = next.activeStyle.isEmpty ? '' : _ansiReset;
  return (
    line: visibleCount == 0 ? '' : '$line$reset',
    nextIndex: next.index,
    activeStyle: next.activeStyle,
  );
}

/// Skips spaces and ANSI SGR sequences in [paragraph] starting at [index].
///
/// Returns the index of the next visible non-space character (or the end of
/// [paragraph]), and the style that is active at that index.
({int index, String activeStyle}) _skipSpaces(
  String paragraph,
  int index,
  String activeStyle,
) {
  while (index < paragraph.length) {
    final match = _ansiSgrRegex.matchAsPrefix(paragraph, index);
    if (match != null) {
      activeStyle = _applySgr(activeStyle, match.group(0)!);
      index = match.end;
    } else if (paragraph[index] == ' ') {
      index++;
    } else {
      break;
    }
  }
  return (index: index, activeStyle: activeStyle);
}

/// Returns the style that is active after applying the ANSI SGR [sequence] on
/// top of [activeStyle].
String _applySgr(String activeStyle, String sequence) =>
    sequence == _ansiReset || sequence == _ansiResetShort
        ? ''
        : '$activeStyle$sequence';

/// Truncates [line] so its visible length (excluding ANSI SGR sequences) is at
/// most [limit].
///
/// If [line] exceeds [limit] visible characters, or if [forceEllipsis] is
/// `true`, the returned string ends with `'...'` (and [_ansiReset] if [line]
/// contained ANSI escape codes) while remaining within [limit] visible
/// characters.
String _truncateLine(String line, int limit, {bool forceEllipsis = false}) {
  final hasAnsi = _ansiSgrRegex.hasMatch(line);
  final visibleLen = _visibleLength(line);
  if (!forceEllipsis && visibleLen <= limit) {
    if (hasAnsi && !line.endsWith(_ansiReset)) {
      return '$line$_ansiReset';
    }
    return line;
  }

  final maxPrefixChars = math.max(0, limit - 3);
  if (!hasAnsi) {
    final prefix =
        line.length > maxPrefixChars ? line.substring(0, maxPrefixChars) : line;
    return '$prefix...';
  }

  // Walk through the string, preserving ANSI SGR sequences and up to
  // maxPrefixChars visible characters.
  final buffer = StringBuffer();
  var visibleCount = 0;
  var lastIndex = 0;
  for (final match in _ansiSgrRegex.allMatches(line)) {
    final segment = line.substring(lastIndex, match.start);
    final remaining = maxPrefixChars - visibleCount;
    if (segment.length >= remaining) {
      buffer.write(segment.substring(0, remaining));
      visibleCount += remaining;
      break;
    }
    buffer.write(segment);
    visibleCount += segment.length;
    buffer.write(match.group(0));
    lastIndex = match.end;
  }
  if (visibleCount < maxPrefixChars && lastIndex < line.length) {
    final segment = line.substring(lastIndex);
    final remaining = maxPrefixChars - visibleCount;
    buffer.write(
      segment.length > remaining ? segment.substring(0, remaining) : segment,
    );
  }
  buffer.write('...$_ansiReset');
  return buffer.toString();
}

const _pointerWidth = 2; // '  ' or '> '
const _scrollbarLeftMargin = 6;
const _minimumOptionLength = 3;

const _ansiReset = '\x1b[0m';
const _ansiResetShort = '\x1b[m';
const _ansiBold = '\x1b[1m';
const _ansiDim = '\x1b[2m';
const _ansiClearLine = '\x1b[2K';
const _ansiHideCursor = '\x1b[?25l';
const _ansiShowCursor = '\x1b[?25h';

String _ansiMoveCursorUp(int lines) => '\x1b[${lines}A';

/// Moves the cursor from the last line of a dialog with [renderedLines] lines
/// to the start of its first line.
String _ansiMoveToDialogStart(int renderedLines) => switch (renderedLines) {
  0 => '',
  1 => '\r',
  _ => '${_ansiMoveCursorUp(renderedLines - 1)}\r',
};
