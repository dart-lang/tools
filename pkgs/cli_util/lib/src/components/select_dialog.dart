// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

/// Shows a scrollable terminal selection dialog and returns the list of
/// selected values.
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
Future<List<String>?> showMultiSelectDialog(
  List<String> options,
  Stream<List<int>> inputStream, {
  int maxVisibleItems = 5,
}) async {
  final selectedIndices = await _runDialog(
    options,
    maxVisibleItems,
    inputStream,
    multiSelect: true,
  );
  if (selectedIndices == null) return null;
  final sortedIndices = selectedIndices.toList()..sort();
  return sortedIndices.map((index) => options[index]).toList();
}

/// Shows a scrollable terminal selection dialog and returns the selected value.
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
Future<String?> showSingleSelectDialog(
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
  return options[selectedIndices.single];
}

/// Internal utility to render a single or multi select dialog and return the
/// indices of the selected items.
Future<Set<int>?> _runDialog(
  List<String> options,
  int maxVisibleItems,
  Stream<List<int>> inputStream, {
  required bool multiSelect,
}) async {
  final selectedIndices = <int>{if (!multiSelect) 0};
  var cursorIndex = 0;
  final cleanupTasks = <FutureOr<void> Function()>[
    () {
      // Try to clear the dialog from the terminal
      final start = options.length <= maxVisibleItems
          ? 0
          : (cursorIndex - (maxVisibleItems ~/ 2))
              .clamp(0, options.length - maxVisibleItems);
      final end = (start + maxVisibleItems).clamp(0, options.length);
      final visibleCount = end - start;

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
      options,
      cursorIndex,
      selectedIndices,
      maxVisibleItems,
      isFirst: true,
      multiSelect: multiSelect,
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
        options,
        cursorIndex,
        selectedIndices,
        maxVisibleItems,
        multiSelect: multiSelect,
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

/// Renders the menu with a sliding window (pagination) and a scrollbar.
void _render(
  List<String> items,
  int cursor,
  Set<int> selected,
  int height, {
  bool isFirst = false,
  required bool multiSelect,
}) {
  final start = items.length <= height
      ? 0
      : (cursor - (height ~/ 2)).clamp(0, items.length - height);
  final end = (start + height).clamp(0, items.length);
  final visibleCount = end - start;

  if (!isFirst) {
    stdout.write('\x1b[${visibleCount}A');
  }

  final isScrollable = items.length > height;
  var thumbHeight = 0;
  var thumbStart = 0;
  if (isScrollable) {
    thumbHeight = (visibleCount * visibleCount / items.length)
        .round()
        .clamp(1, visibleCount);
    thumbStart = (start * visibleCount / items.length).round();
    thumbStart = thumbStart.clamp(0, visibleCount - thumbHeight);
  }

  for (var i = start; i < end; i++) {
    stdout.write('\x1b[2K'); // Clear current line

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
      final maxLen = items.fold(0, (max, e) => e.length > max ? e.length : max);
      line = line.padRight(maxLen + 10);
      line += isThumb ? ' █' : ' │';
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
        72 => _Key.home,
        70 => _Key.end,
        53 => _Key.pageUp,
        54 => _Key.pageDown,
        49 => _Key.home,
        52 => _Key.end,
        13 => _Key.enter,
        10 => _Key.enter,
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
