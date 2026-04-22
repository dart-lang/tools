// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'keys.dart';

/// Shows a scrollable terminal selection dialog and returns the set of
/// selected indices.
///
/// Temporarily disables stdin line and echo modes, and restores them before
/// returning. Also intercepts [ProcessSignal.sigint] to cancel the dialog.
///
/// The [inputStream] is a list of input events (typically originating from
/// [stdin] but it should not be exactly [stdin] since that can only be
/// listened to once). It is safe to pass a broadcast stream version of [stdin],
/// but you will likely want to ignore your own events in the meantime if you
/// are also listening to it.
///
/// The [maxVisibleItems] parameter controls how many items are visible in the
/// dialog at once.
///
/// Returns `null` if the user aborts the dialog (e.g. by pressing Ctrl+C or
/// escape), there is no terminal attached to stdout, or the terminal is too
/// small to display the dialog.
Future<Set<int>?> showMultiSelectDialog(
  List<String> options,
  Stream<List<int>> inputStream, {
  int maxVisibleItems = 5,
}) =>
    _runDialog(
      options,
      maxVisibleItems,
      inputStream,
      multiSelect: true,
    );

/// Shows a scrollable terminal selection dialog and returns the selected index.
///
/// Temporarily disables stdin line and echo modes, and restores them before
/// returning. Also intercepts [ProcessSignal.sigint] to cancel the dialog.
///
/// The [inputStream] is a list of input events (typically originating from
/// [stdin] but it should not be exactly [stdin] since that can only be
/// listened to once). It is safe to pass a broadcast stream version of [stdin],
/// but you will likely want to ignore your own events in the meantime if you
/// are also listening to it.
///
/// The [maxVisibleItems] parameter controls how many items are visible in the
/// dialog at once.
///
/// Returns `null` if the user aborts the dialog (e.g. by pressing Ctrl+C or
/// escape), there is no terminal attached to stdout, or the terminal is too
/// small to display the dialog.
Future<int?> showSingleSelectDialog(
  List<String> options,
  Stream<List<int>> inputStream, {
  int maxVisibleItems = 5,
}) async {
  final selectedIndices = await _runDialog(
    options,
    maxVisibleItems,
    inputStream,
    multiSelect: false,
  );
  if (selectedIndices == null || selectedIndices.isEmpty) {
    return null;
  }
  return selectedIndices.single;
}

/// Internal utility to render a single or multi select dialog and return the
/// indices of the selected items.
Future<Set<int>?> _runDialog(
  List<String> options,
  int maxVisibleItems,
  Stream<List<int>> inputStream, {
  required bool multiSelect,
}) async {
  final isScrollable = options.length > maxVisibleItems;
  final width = _terminalWidth;

  // Note that we just assume all terminals support ansii escapes because it
  // very rare nowadays not to, and the built in detection has a lot of false
  // negative cases (https://github.com/dart-lang/sdk/issues/31606).
  if (options.isEmpty ||
      !stdout.hasTerminal ||
      width < _minimumTerminalWidth(multiSelect, isScrollable)) {
    // We do need to actually listen to this stream and immediately cancel, or
    // else it will never close in come cases.
    await inputStream.listen((_) {}).cancel();
    return null;
  }

  final displayOptions =
      _truncateOptions(options, width, multiSelect, isScrollable);

  final maxItemLength =
      displayOptions.fold(0, (max, e) => e.length > max ? e.length : max);
  final selectedIndices = <int>{if (!multiSelect) 0};
  var cursorIndex = 0;
  final cleanupTasks = <FutureOr<void> Function()>[
    () {
      // Try to clear the dialog from the terminal
      final visibleCount = math.min(options.length, maxVisibleItems);
      stdout.write('\x1b[${visibleCount}A'); // Move cursor to top
      for (var i = 0; i < visibleCount; i++) {
        stdout.write('\x1b[2K\n'); // Clear each line
      }
      stdout.write('\x1b[${visibleCount}A'); // Move back
    }
  ];
  try {
    // Move the terminal into the rendering state we want.
    if (stdin.hasTerminal) {
      final savedLineMode = stdin.lineMode;
      // On Windows, if line mode is enabled then echo mode also is, but this
      // gets reported incorrectly.
      final savedEchoMode = stdin.echoMode || savedLineMode;
      cleanupTasks.add(() {
        // NOTE: Line mode must be enabled before echo mode on Windows.
        if (stdin.lineMode != savedLineMode) stdin.lineMode = savedLineMode;
        if (stdin.echoMode != savedEchoMode) stdin.echoMode = savedEchoMode;
      });
      // NOTE: Echo mode must be set false before line mode on Windows.
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
    _render(
      items: displayOptions,
      cursor: cursorIndex,
      selected: selectedIndices,
      height: maxVisibleItems,
      isFirstRender: true,
      multiSelect: multiSelect,
      maxItemLength: maxItemLength,
    );

    final inputSub = inputStream.keys.listen((key) {
      final oldIndex = cursorIndex;
      switch (key) {
        case Key.up:
          cursorIndex = (cursorIndex - 1).clamp(0, options.length - 1);
        case Key.down:
          cursorIndex = (cursorIndex + 1).clamp(0, options.length - 1);
        case Key.pageUp:
          cursorIndex =
              (cursorIndex - maxVisibleItems).clamp(0, options.length - 1);
        case Key.pageDown:
          cursorIndex =
              (cursorIndex + maxVisibleItems).clamp(0, options.length - 1);
        case Key.home:
          cursorIndex = 0;
        case Key.end:
          cursorIndex = options.length - 1;
        case Key.space:
          if (multiSelect) {
            if (selectedIndices.contains(cursorIndex)) {
              selectedIndices.remove(cursorIndex);
            } else {
              selectedIndices.add(cursorIndex);
            }
          }
        case Key.enter:
          if (!doneCompleter.isCompleted) {
            doneCompleter.complete(selectedIndices);
          }
          return;
        case Key.quit:
          if (!doneCompleter.isCompleted) {
            doneCompleter.complete(null);
          }
          return;
      }

      if (!multiSelect && oldIndex != cursorIndex) {
        selectedIndices.clear();
        selectedIndices.add(cursorIndex);
      }

      _render(
        items: displayOptions,
        cursor: cursorIndex,
        selected: selectedIndices,
        height: maxVisibleItems,
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

/// Renders the selection menu to the terminal.
///
/// This function handles:
///
/// - **Pagination**: It displays a window of [height] items, attempting to
///   keep the [cursor] centered.
/// - **Scrollbar Rendering**: If the total number of items exceeds the visible
///   height, a scrollbar is drawn on the right. The scrollbar physics ensure
///   that the thumb only reaches the top/bottom extremes when the list is
///   actually at the extremes, while moving consistently in between.
/// - **Selection Markers**: Renders checkboxes for multi-select mode, and bolds
///   the hovered option, as well as marking it with a pointer (`>`).
///
/// Parameters:
/// - [items]: The list of strings to display as options.
/// - [cursor]: The current hovered index in the list.
/// - [selected]: The set of indices that are currently selected.
/// - [height]: The max number of visible items (window size).
/// - [isFirstRender]: Whether this is the initial render. If true, the cursor
///   will not be moved up before rendering.
/// - [multiSelect]: If true, renders checkboxes.
/// - [maxItemLength]: The length of the longest item, used for consistent
///   spacing between the option text and the scrollbar.
void _render({
  required List<String> items,
  required int cursor,
  required Set<int> selected,
  required int height,
  bool isFirstRender = false,
  required bool multiSelect,
  required int maxItemLength,
}) {
  // Calculate the window of items to display.
  final isScrollable = items.length > height;
  final start = isScrollable
      ? (cursor - (height ~/ 2)).clamp(0, items.length - height)
      : 0;
  final end =
      isScrollable ? math.min(start + height, items.length) : items.length;
  final visibleCount = end - start;

  // Move the cursor to the top of the dialog if we're not on the first render.
  if (!isFirstRender) {
    stdout.write('\x1b[${visibleCount}A');
  }

  var thumbHeight = 0;
  var thumbStart = 0;
  // Calculate scrollbar thumb position and height if enabled.
  if (isScrollable) {
    // Calculate thumb height proportional to visible area.
    thumbHeight = (visibleCount * visibleCount / items.length)
        .round()
        .clamp(1, math.max(1, visibleCount - 1));
    // The max valid start index for the list window.
    final maxStart = items.length - visibleCount;
    // The max valid start index for the thumb based on its size.
    final maxThumbStart = visibleCount - thumbHeight;

    // We want to ensure that the thumb reaches the absolute extremes (top/bottom)
    // ONLY when the list is actually scrolled to the extremes.
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

  // Render each visible line.
  for (var i = start; i < end; i++) {
    final isHovered = (i == cursor);
    final isChecked = selected.contains(i);

    final pointer = isHovered ? '> ' : '  ';

    // Show checkbox only for multiselect.
    final selectionMarker = multiSelect ? (isChecked ? '[x] ' : '[ ] ') : '';

    var line = '$pointer$selectionMarker${items[i]}';
    if (isScrollable) {
      // Scrollbar on the right
      final relativeI = i - start;
      final isThumb =
          relativeI >= thumbStart && relativeI < thumbStart + thumbHeight;
      final scrollbarXPosition = _pointerWidth +
          selectionMarker.length +
          maxItemLength +
          _scrollbarLeftMargin;
      line = '${line.padRight(scrollbarXPosition)}${isThumb ? '█' : '│'}';
    }

    if (isHovered) {
      stdout.write('\x1b[1m$line\x1b[0m\n'); // bold  the selected item
    } else {
      stdout.write('$line\n');
    }
  }
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
  final totalNeeded = _pointerWidth +
      checkboxWidth +
      _minmumOptionLength +
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

/// Truncates the options to fit within the terminal width, down to a minimum
/// of 3 characters.
///
/// If the options are truncated, the ellipsis '...' is added to the end of
/// the option.
///
/// Accounts for the space that the scrollbar and checkboxes take up.
List<String> _truncateOptions(
  List<String> options,
  int terminalWidth,
  bool multiSelect,
  bool isScrollable,
) {
  final selectionMarkerLength = multiSelect ? 4 /* ' [ ]' */ : 0;
  final scrollbarWidth = isScrollable ? 1 : 0;
  var maxOptionLength = terminalWidth - _pointerWidth - selectionMarkerLength;
  if (isScrollable) {
    maxOptionLength -= _scrollbarLeftMargin + scrollbarWidth;
  }

  // We don't want to truncate to less than 3 characters.
  var limit = math.max(_minmumOptionLength, maxOptionLength);
  if (options.every((option) => option.length <= limit)) {
    return options;
  }

  // We are truncating, account for the space that the '...' will take up,
  // while still showing at least the minimum number of characters.
  limit = math.max(_minmumOptionLength, limit - 3);
  return options.map((option) {
    if (option.length > limit) {
      return '${option.substring(0, limit)}...';
    }
    return option;
  }).toList();
}

const _pointerWidth = 2; // '  ' or '>
const _scrollbarLeftMargin = 6;
const _minmumOptionLength = 3;
