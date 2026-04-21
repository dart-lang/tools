// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
/// escape).
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
/// Returns `null` if the user aborts the dialog (e.g. by pressing Ctrl-C or
/// escape).
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
  if (options.isEmpty) return null;

  final maxItemLength =
      options.fold(0, (max, e) => e.length > max ? e.length : max);
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
      final savedEchoMode = stdin.echoMode;
      cleanupTasks.add(() {
        stdin.lineMode = savedLineMode;
        stdin.echoMode = savedEchoMode;
      });
      stdin.lineMode = false;
      stdin.echoMode = false;
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
      items: options,
      cursor: cursorIndex,
      selected: selectedIndices,
      height: maxVisibleItems,
      isFirstRender: true,
      multiSelect: multiSelect,
      maxItemLength: maxItemLength,
    );

    final inputSub = _getKeys(inputStream).listen((key) {
      final oldIndex = cursorIndex;
      switch (key) {
        case _Key.up:
          cursorIndex = (cursorIndex - 1).clamp(0, options.length - 1);
        case _Key.down:
          cursorIndex = (cursorIndex + 1).clamp(0, options.length - 1);
        case _Key.pageUp:
          cursorIndex =
              (cursorIndex - maxVisibleItems).clamp(0, options.length - 1);
        case _Key.pageDown:
          cursorIndex =
              (cursorIndex + maxVisibleItems).clamp(0, options.length - 1);
        case _Key.home:
          cursorIndex = 0;
        case _Key.end:
          cursorIndex = options.length - 1;
        case _Key.space:
          if (multiSelect) {
            if (selectedIndices.contains(cursorIndex)) {
              selectedIndices.remove(cursorIndex);
            } else {
              selectedIndices.add(cursorIndex);
            }
          }
        case _Key.enter:
          doneCompleter.complete(selectedIndices);
          return;
        case _Key.quit:
          doneCompleter.complete(null);
          return;
      }

      if (!multiSelect && oldIndex != cursorIndex) {
        selectedIndices.clear();
        selectedIndices.add(cursorIndex);
      }

      _render(
        items: options,
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
      line = '${line.padRight(maxItemLength + selectionMarker.length + 10)}'
          '${isThumb ? ' █' : ' │'}';
    }

    if (isHovered) {
      stdout.write('\x1b[1m$line\x1b[0m\n'); // bold  the selected item
    } else {
      stdout.write('$line\n');
    }
  }
}

/// Listens for terminal byte sequences and maps them to key commands.
Stream<_Key> _getKeys(Stream<List<int>> inputStream) {
  // Note that we cannot use async* here because the returned stream will not
  // actually complete when cancelled if the user hits ctrl+c.
  final streamController = StreamController<_Key>();
  final subscription = inputStream.listen((bytes) {
    for (var b = 0; b < bytes.length; b++) {
      final key = switch (bytes[b]) {
        65 => _Key.up,
        66 => _Key.down,
        49 || 72 => _Key.home, // 1, H
        52 || 70 => _Key.end, // 4, F
        53 => _Key.pageUp, // 5
        54 => _Key.pageDown, // 6
        10 || 13 => _Key.enter, // newline/carraige return
        32 => _Key.space,
        // End of text/end of transmission
        3 || 4 => _Key.quit,
        // Escape key but not escape sequence
        27 when b + 1 >= bytes.length || bytes[b + 1] != 91 => _Key.quit,
        _ => null,
      };
      if (key != null) {
        streamController.add(key);
      }
    }
  });
  streamController.onCancel = subscription.cancel;
  return streamController.stream;
}

enum _Key { up, down, pageUp, pageDown, home, end, space, enter, quit }
