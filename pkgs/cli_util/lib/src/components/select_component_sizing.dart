// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

/// Controls the vertical sizing of a selection dialog.
///
/// Use the [SelectComponentSizing.fixed] and [SelectComponentSizing.fit]
/// constructors to create instances.
///
/// This class is final so that it can be more easily evolved in the future.
abstract final class SelectComponentSizing {
  /// Creates a fixed-size configuration with a constant [totalHeight] and
  /// [maxDescriptionHeight].
  const factory SelectComponentSizing.fixed({
    int totalHeight,
    int maxDescriptionHeight,
  }) = _FixedSizing;

  /// Creates a configuration that fits the current terminal height
  /// (`stdout.terminalLines - 2`, or `10` if unavailable).
  ///
  /// If [maxDescriptionHeight] is omitted, it defaults to `totalHeight ~/ 2`.
  const factory SelectComponentSizing.fit({int? maxDescriptionHeight}) =
      _FitSizing;

  /// The maximum total number of lines (items, the hovered item's description
  /// lines, and the bottom legend in multi-select mode) visible in the dialog
  /// at once.
  int get totalHeight;

  /// The maximum number of lines displayed for a hovered option's description
  /// before it is truncated with an ellipsis.
  int get maxDescriptionHeight;
}

final class _FixedSizing implements SelectComponentSizing {
  @override
  final int totalHeight;

  @override
  final int maxDescriptionHeight;

  const _FixedSizing({this.totalHeight = 10, this.maxDescriptionHeight = 5})
    : assert(totalHeight >= 1, 'totalHeight must be at least 1.'),
      assert(
        maxDescriptionHeight >= 0,
        'maxDescriptionHeight must be non-negative.',
      );
}

final class _FitSizing implements SelectComponentSizing {
  final int? _maxDescriptionHeight;

  const _FitSizing({int? maxDescriptionHeight})
    : assert(
        maxDescriptionHeight == null || maxDescriptionHeight >= 0,
        'maxDescriptionHeight must be non-negative.',
      ),
      _maxDescriptionHeight = maxDescriptionHeight;

  @override
  int get totalHeight {
    try {
      if (stdout.hasTerminal) {
        // We want one line for the title and one for terminals which render
        // the previous command as a sticky header.
        return math.max(1, stdout.terminalLines - 2);
      }
    } catch (_) {}
    return 10;
  }

  @override
  int get maxDescriptionHeight => _maxDescriptionHeight ?? (totalHeight ~/ 2);
}
