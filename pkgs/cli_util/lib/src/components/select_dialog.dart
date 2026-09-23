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
  final int sizingTotalHeight;
  final int sizingMaxDescriptionHeight;
  try {
    sizingTotalHeight = sizing.totalHeight;
    sizingMaxDescriptionHeight = sizing.maxDescriptionHeight;
    assert(sizingTotalHeight >= 1, 'sizing.totalHeight must be at least 1.');
    assert(
      sizingMaxDescriptionHeight >= 0,
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

  final maxRenderableLines = _terminalHeight - 1;
  final width = _terminalWidth;

  // Note that we just assume all terminals support ansii escapes because it
  // very rare nowadays not to, and the built in detection has a lot of false
  // negative cases (https://github.com/dart-lang/sdk/issues/31606).
  if (parsedOptions.isEmpty || !stdout.hasTerminal || maxRenderableLines < 1) {
    // We do need to actually listen to this stream and immediately cancel, or
    // else it will never close in some cases.
    await inputStream.listen((_) {}).cancel();
    return null;
  }

  final cappedMaxTotalHeight =
      maxVisibleItems == null
          ? math.min(sizingTotalHeight, maxRenderableLines)
          : null;
  var effectiveMaxDescriptionLines =
      cappedMaxTotalHeight != null
          ? math.min(
            sizingMaxDescriptionHeight,
            sizingTotalHeight > maxRenderableLines
                ? maxRenderableLines ~/ 2
                : cappedMaxTotalHeight - 1,
          )
          : math.min(sizingMaxDescriptionHeight, maxRenderableLines - 1);

  // First pass: wrap assuming non-scrollable or scrollable based on an initial
  // estimate to determine maxDescriptionHeight.
  var isScrollable =
      parsedOptions.length > (cappedMaxTotalHeight ?? maxVisibleItems!);
  if (width < _minimumTerminalWidth(multiSelect, isScrollable)) {
    await inputStream.listen((_) {}).cancel();
    return null;
  }

  var limit = _maxLineLength(width, multiSelect, isScrollable);
  var displayDescriptions = [
    for (final option in parsedOptions)
      if (option.description == null ||
          option.description!.isEmpty ||
          effectiveMaxDescriptionLines <= 0)
        const <String>[]
      else
        _wordWrapDescription(
          option.description!,
          limit,
          effectiveMaxDescriptionLines,
        ),
  ];

  var maxDescriptionHeight = displayDescriptions.fold(
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
  final newIsScrollable = parsedOptions.length > minVisibleItems;
  if (newIsScrollable != isScrollable ||
      effectiveMaxDescriptionLines < maxDescriptionHeight) {
    isScrollable = newIsScrollable;
    if (width < _minimumTerminalWidth(multiSelect, isScrollable)) {
      await inputStream.listen((_) {}).cancel();
      return null;
    }
    limit = _maxLineLength(width, multiSelect, isScrollable);
    displayDescriptions = [
      for (final option in parsedOptions)
        if (option.description == null ||
            option.description!.isEmpty ||
            effectiveMaxDescriptionLines <= 0)
          const <String>[]
        else
          _wordWrapDescription(
            option.description!,
            limit,
            effectiveMaxDescriptionLines,
          ),
    ];
    maxDescriptionHeight = displayDescriptions.fold(
      0,
      (max, lines) => math.max(max, lines.length),
    );
  }

  final displayOptions = [
    for (final option in parsedOptions) _truncateLine(option.label, limit),
  ];

  var maxItemLength = displayOptions.fold(
    0,
    (max, e) => math.max(max, _visibleLength(e)),
  );
  for (final descLines in displayDescriptions) {
    for (final line in descLines) {
      maxItemLength = math.max(maxItemLength, _visibleLength(line));
    }
  }

  final selectedIndices = {
    if (initialSelected.isEmpty && !multiSelect) 0,
    ...initialSelected,
  };
  var cursorIndex = 0;
  var lastRenderedLines = 0;
  final cleanupTasks = <FutureOr<void> Function()>[
    () {
      if (lastRenderedLines > 0) {
        // Try to clear the dialog from the terminal
        if (lastRenderedLines > 1) {
          stdout.write('\x1b[${lastRenderedLines - 1}A'); // Move cursor to top
        }
        stdout.write('\r');
        for (var i = 0; i < lastRenderedLines; i++) {
          stdout.write('\x1b[2K${i == lastRenderedLines - 1 ? '' : '\n'}');
        }
        if (lastRenderedLines > 1) {
          stdout.write('\x1b[${lastRenderedLines - 1}A'); // Move back
        }
        stdout.write('\r');
      }
    },
  ];
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
    stdout.write('\x1b[?25l');
    cleanupTasks.add(() => stdout.write('\x1b[?25h\x1b[0m'));

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
    lastRenderedLines = _render(
      items: displayOptions,
      descriptions: displayDescriptions,
      cursor: cursorIndex,
      selected: selectedIndices,
      maxTotalHeight: effectiveMaxTotalHeight,
      isScrollable: isScrollable,
      previousRenderedLines: lastRenderedLines,
      multiSelect: multiSelect,
      maxItemLength: maxItemLength,
    );

    final inputSub = inputStream.keys.listen((key) {
      final oldIndex = cursorIndex;
      final pageItems = math.max(
        1,
        effectiveMaxTotalHeight - displayDescriptions[cursorIndex].length,
      );
      switch (key) {
        case Key.up:
          cursorIndex = (cursorIndex - 1).clamp(0, parsedOptions.length - 1);
        case Key.down:
          cursorIndex = (cursorIndex + 1).clamp(0, parsedOptions.length - 1);
        case Key.pageUp:
          cursorIndex = (cursorIndex - pageItems).clamp(
            0,
            parsedOptions.length - 1,
          );
        case Key.pageDown:
          cursorIndex = (cursorIndex + pageItems).clamp(
            0,
            parsedOptions.length - 1,
          );
        case Key.home:
          cursorIndex = 0;
        case Key.end:
          cursorIndex = parsedOptions.length - 1;
        case Key.space:
          if (multiSelect) {
            if (selectedIndices.contains(cursorIndex)) {
              selectedIndices.remove(cursorIndex);
            } else {
              selectedIndices.add(cursorIndex);
            }
          }
        case Key.selectAll:
          if (multiSelect) {
            if (selectedIndices.length == parsedOptions.length) {
              selectedIndices.clear();
            } else {
              selectedIndices.addAll(
                Iterable<int>.generate(parsedOptions.length),
              );
            }
          }
        case Key.enter:
          doneCompleter.complete(selectedIndices);
          return;
        case Key.quit:
          doneCompleter.complete(null);
          return;
      }

      if (!multiSelect && oldIndex != cursorIndex) {
        selectedIndices.clear();
        selectedIndices.add(cursorIndex);
      }

      lastRenderedLines = _render(
        items: displayOptions,
        descriptions: displayDescriptions,
        cursor: cursorIndex,
        selected: selectedIndices,
        maxTotalHeight: effectiveMaxTotalHeight,
        isScrollable: isScrollable,
        previousRenderedLines: lastRenderedLines,
        multiSelect: multiSelect,
        maxItemLength: maxItemLength,
      );
    });
    // ignore: unnecessary_lambdas
    cleanupTasks.add(() {
      // Intentionally not awaited, this can block indefinitely on ctrl+c.
      inputSub.cancel();
    });

    return await doneCompleter.future;
  } finally {
    await [
      for (final cleanupTask in cleanupTasks) cleanupTask(),
    ].whereType<Future<void>>().wait;
  }
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
///   description within [maxTotalHeight] lines, attempting to keep the [cursor]
///   centered.
/// - **Descriptions**: Renders any description lines for the hovered item
///   directly below it, aligned with the item label.
/// - **Scrollbar Rendering**: If [isScrollable] is true, a scrollbar is drawn
///   on the right. The scrollbar physics ensure that the thumb only reaches the
///   top/bottom extremes when the list is actually at the extremes, while
///   moving consistently in between.
/// - **Selection Markers**: Renders checkboxes for multi-select mode, and bolds
///   the hovered option, as well as marking it with a pointer (`>`).
///
/// Parameters:
/// - [items]: The list of strings to display as options.
/// - [descriptions]: The formatted description lines for each option.
/// - [cursor]: The current hovered index in the list.
/// - [selected]: The set of indices that are currently selected.
/// - [maxTotalHeight]: The maximum total number of visible lines (items plus
///   the hovered item's description).
/// - [isScrollable]: Whether a scrollbar should be rendered.
/// - [previousRenderedLines]: The number of lines rendered in the previous
///   frame (`0` on the initial render).
/// - [multiSelect]: If true, renders checkboxes.
/// - [maxItemLength]: The length of the longest item or description line, used
///   for consistent spacing between the text and the scrollbar.
int _render({
  required List<String> items,
  required List<List<String>> descriptions,
  required int cursor,
  required Set<int> selected,
  required int maxTotalHeight,
  required bool isScrollable,
  required int previousRenderedLines,
  required bool multiSelect,
  required int maxItemLength,
}) {
  // Calculate the window of items to display given the hovered item's
  // description height.
  final hoveredDescriptions = descriptions[cursor];
  final itemWindowHeight = math.max(
    1,
    maxTotalHeight - hoveredDescriptions.length,
  );
  final windowScrollable = items.length > itemWindowHeight;
  final start =
      windowScrollable
          ? (cursor - (itemWindowHeight ~/ 2)).clamp(
            0,
            items.length - itemWindowHeight,
          )
          : 0;
  final end =
      windowScrollable
          ? math.min(start + itemWindowHeight, items.length)
          : items.length;
  final visibleCount = end - start;
  final itemAndDescLines = visibleCount + hoveredDescriptions.length;
  final totalLines = itemAndDescLines + (multiSelect ? 1 : 0);

  // Move the cursor to the top of the dialog if we're not on the first render.
  final isFirstRender = previousRenderedLines == 0;
  if (!isFirstRender) {
    if (previousRenderedLines > 1) {
      stdout.write('\x1b[${previousRenderedLines - 1}A');
    }
    stdout.write('\r');
  }

  var thumbHeight = 0;
  var thumbStart = 0;
  // Calculate scrollbar thumb position and height if enabled.
  if (isScrollable) {
    if (!windowScrollable) {
      thumbHeight = itemAndDescLines;
      thumbStart = 0;
    } else {
      // Calculate thumb height proportional to visible area.
      thumbHeight = (visibleCount * itemAndDescLines / items.length)
          .round()
          .clamp(1, math.max(1, itemAndDescLines - 1));
      // The max valid start index for the list window.
      final maxStart = items.length - visibleCount;
      // The max valid start index for the thumb based on its size.
      final maxThumbStart = itemAndDescLines - thumbHeight;

      // We want to ensure that the thumb reaches the absolute extremes
      // (top/bottom) ONLY when the list is actually scrolled to the extremes.
      // For intermediate values, we distribute them as equally as possible
      // among the remaining positions to ensure smooth, consistent movement.
      if (start == 0) {
        // Actual top of scroll range.
        thumbStart = 0;
      } else if (start == maxStart) {
        // Actual bottom of scroll range.
        thumbStart = maxThumbStart;
      } else if (maxThumbStart <= 1) {
        // Very small lists, only one of two positions available.
        thumbStart = cursor > items.length / 2 ? maxThumbStart : 0;
      } else {
        // Map from 1..maxThumbStart-1 linearly
        thumbStart = 1 + ((start - 1) * (maxThumbStart - 1)) ~/ (maxStart - 1);
      }
    }
  }

  final selectionMarkerLength = multiSelect ? 4 : 0;
  final scrollbarXPosition =
      _pointerWidth +
      selectionMarkerLength +
      maxItemLength +
      _scrollbarLeftMargin;
  final clearPrefix = isFirstRender ? '' : '\x1b[2K';

  String addScrollbar(String line, int rowIndex) {
    if (!isScrollable) return line;
    final isThumb =
        rowIndex >= thumbStart && rowIndex < thumbStart + thumbHeight;
    final padding = math.max(0, scrollbarXPosition - _visibleLength(line));
    return '$line${' ' * padding}${isThumb ? '█' : '│'}';
  }

  var currentLineIndex = 0;
  final descriptionIndent = ' ' * (_pointerWidth + selectionMarkerLength);

  void writeRenderedLine(String text) {
    final isLastLine = currentLineIndex == totalLines;
    stdout.write('$clearPrefix$text${isLastLine ? '' : '\n'}');
  }

  // Render each visible line.
  for (var i = start; i < end; i++) {
    final isHovered = (i == cursor);
    final isChecked = selected.contains(i);

    final pointer = isHovered ? '> ' : '  ';

    // Show checkbox only for multiselect.
    final selectionMarker = multiSelect ? (isChecked ? '[x] ' : '[ ] ') : '';

    final line = addScrollbar(
      '$pointer$selectionMarker${items[i]}',
      currentLineIndex++,
    );

    if (isHovered) {
      final boldLine = line.replaceAll('\x1b[0m', '\x1b[0m\x1b[1m');
      writeRenderedLine('\x1b[1m$boldLine\x1b[0m');
      for (final descLine in hoveredDescriptions) {
        final indented = descLine.isEmpty ? '' : '$descriptionIndent$descLine';
        final fullDescLine = addScrollbar(indented, currentLineIndex++);
        writeRenderedLine(fullDescLine);
      }
    } else {
      writeRenderedLine(line);
    }
  }

  if (multiSelect) {
    currentLineIndex++;
    writeRenderedLine('\x1b[2m$multiSelectLegend\x1b[0m');
  }

  // If the previous render had more lines than this render, clear the extra
  // lines below and move the cursor back up to the bottom of the current
  // render.
  if (!isFirstRender && previousRenderedLines > totalLines) {
    final extraLines = previousRenderedLines - totalLines;
    for (var i = 0; i < extraLines; i++) {
      stdout.write('\n\x1b[2K');
    }
    stdout.write('\x1b[${extraLines}A');
  }

  return totalLines;
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

/// Returns the height of the terminal or 24 if it cannot be determined.
int get _terminalHeight {
  try {
    if (stdout.hasTerminal) {
      return stdout.terminalLines;
    }
  } catch (_) {}
  // The default height if we fail to compute it.
  return 24;
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

/// Word-wraps [description] so each line has at most [limit] visible
/// characters, while preserving explicit newlines (`\n` or `\r\n`) and ANSI
/// SGR styling sequences across wrapped lines.
///
/// Returns at most [maxLines] lines. If the description exceeds [maxLines],
/// the last line is wrapped to `limit - 3` visible characters and suffixed
/// with `'...'`.
List<String> _wordWrapDescription(String description, int limit, int maxLines) {
  if (maxLines <= 0) return const <String>[];
  final paragraphs = description.split(_newlineRegex);
  final wrapped = <String>[];
  var activeStyle = '';

  for (var pIndex = 0; pIndex < paragraphs.length; pIndex++) {
    final hasMoreParagraphs = pIndex < paragraphs.length - 1;
    final (:chars, :endStyle) = _parseStyledChars(
      paragraphs[pIndex],
      initialStyle: activeStyle,
    );
    activeStyle = endStyle;

    if (chars.isEmpty) {
      if (wrapped.length == maxLines - 1 && hasMoreParagraphs) {
        wrapped.add('...');
        return wrapped;
      }
      wrapped.add('');
      if (wrapped.length >= maxLines) return wrapped;
      continue;
    }

    var start = 0;
    while (start < chars.length) {
      final isLastAllowedLine = wrapped.length == maxLines - 1;
      final remainingChars = chars.length - start;
      final willOverflowLines =
          isLastAllowedLine && (remainingChars > limit || hasMoreParagraphs);

      final lineLimit = willOverflowLines ? math.max(0, limit - 3) : limit;

      if (!willOverflowLines && remainingChars <= lineLimit) {
        wrapped.add(_renderStyledChars(chars.sublist(start)));
        break;
      }

      if (willOverflowLines && remainingChars <= lineLimit) {
        wrapped.add(_renderStyledChars(chars.sublist(start), suffix: '...'));
        return wrapped;
      }

      // Find the last space within [start, start + lineLimit].
      var breakIndex = -1;
      for (var i = start + lineLimit; i > start; i--) {
        if (chars[i].char == ' ') {
          breakIndex = i;
          break;
        }
      }

      if (breakIndex > start) {
        wrapped.add(
          _renderStyledChars(
            chars.sublist(start, breakIndex),
            suffix: willOverflowLines ? '...' : '',
          ),
        );
        if (willOverflowLines) return wrapped;
        start = breakIndex + 1;
        // Skip any additional spaces at the wrap point.
        while (start < chars.length && chars[start].char == ' ') {
          start++;
        }
      } else {
        // Single word exceeds lineLimit; break at lineLimit.
        wrapped.add(
          _renderStyledChars(
            chars.sublist(start, start + lineLimit),
            suffix: willOverflowLines ? '...' : '',
          ),
        );
        if (willOverflowLines) return wrapped;
        start += lineLimit;
      }
    }
  }
  return wrapped;
}

typedef _StyledChar = ({String char, String style});

({List<_StyledChar> chars, String endStyle}) _parseStyledChars(
  String text, {
  String initialStyle = '',
}) {
  final chars = <_StyledChar>[];
  var currentStyle = initialStyle;
  var lastIndex = 0;
  for (final match in _ansiSgrRegex.allMatches(text)) {
    for (var i = lastIndex; i < match.start; i++) {
      chars.add((char: text[i], style: currentStyle));
    }
    final seq = match.group(0)!;
    if (seq == '\x1b[0m' || seq == '\x1b[m') {
      currentStyle = '';
    } else {
      currentStyle += seq;
    }
    lastIndex = match.end;
  }
  for (var i = lastIndex; i < text.length; i++) {
    chars.add((char: text[i], style: currentStyle));
  }
  return (chars: chars, endStyle: currentStyle);
}

String _renderStyledChars(List<_StyledChar> slice, {String suffix = ''}) {
  if (slice.isEmpty) return suffix;
  final buffer = StringBuffer();
  var activeStyle = '';
  for (final item in slice) {
    if (item.style != activeStyle) {
      if (activeStyle.isNotEmpty) {
        buffer.write('\x1b[0m');
      }
      buffer.write(item.style);
      activeStyle = item.style;
    }
    buffer.write(item.char);
  }
  buffer.write(suffix);
  if (activeStyle.isNotEmpty) {
    buffer.write('\x1b[0m');
  }
  return buffer.toString();
}

/// Truncates [line] so its visible length (excluding ANSI SGR sequences) is at
/// most [limit].
///
/// If [line] exceeds [limit] visible characters, or if [forceEllipsis] is
/// `true`, the returned string ends with `'...'` (and `\x1b[0m` if [line]
/// contained ANSI escape codes) while remaining within [limit] visible
/// characters.
String _truncateLine(String line, int limit, {bool forceEllipsis = false}) {
  final hasAnsi = _ansiSgrRegex.hasMatch(line);
  final visibleLen = _visibleLength(line);
  if (!forceEllipsis && visibleLen <= limit) {
    if (hasAnsi && !line.endsWith('\x1b[0m')) {
      return '$line\x1b[0m';
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
  buffer.write('...\x1b[0m');
  return buffer.toString();
}

const _pointerWidth = 2; // '  ' or '>
const _scrollbarLeftMargin = 6;
const _minimumOptionLength = 3;
