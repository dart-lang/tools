// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

const _ansiEscapeLiteral = '\x1B';
const _ansiEscapeForScript = r'\033';

/// Whether formatted ANSI output is enabled for [wrapWith] and [AnsiCode.wrap].
///
/// By default, returns `true` if both `stdout.supportsAnsiEscapes` and
/// `stderr.supportsAnsiEscapes` from `dart:io` are `true`.
///
/// The default can be overridden by setting the [Zone] variable [AnsiCode] to
/// either `true` or `false`.
///
/// [overrideAnsiOutput] is provided to make this easy.
bool get ansiOutputEnabled =>
    Zone.current[AnsiCode] as bool? ??
    (io.stdout.supportsAnsiEscapes && io.stderr.supportsAnsiEscapes);

/// Whether no formatting is required for an input.
bool _isNoop(bool forScript) => !ansiOutputEnabled && !forScript;

/// Allows overriding [ansiOutputEnabled] to [enableAnsiOutput] for the code run
/// within [body].
T overrideAnsiOutput<T>(bool enableAnsiOutput, T Function() body) =>
    runZoned(body, zoneValues: <Object, Object>{AnsiCode: enableAnsiOutput});

/// The type of code represented by [AnsiCode].
enum AnsiCodeType {
  /// A background color.
  background,

  /// A foreground color.
  foreground,

  /// A reset value.
  reset,

  /// A style.
  style,
}

/// Standard ANSI escape code for customizing terminal text output.
///
/// [Source](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
class AnsiCode {
  /// The numeric value associated with this code.
  final int code;

  /// The [AnsiCode] that resets this value, if one exists.
  ///
  /// Otherwise, `null`.
  final AnsiCode? reset;

  /// A description of this code.
  final String name;

  /// The type of code that is represented.
  final AnsiCodeType type;

  const AnsiCode._(this.name, this.type, this.code, this.reset)
      : assert(identical(type, AnsiCodeType.reset) == (reset == null),
            'Reset codes cannot have a reset, non-reset codes must.');

  String get _codes => '$code';

  /// Represents the value escaped for use in terminal output.
  String get escape => '$_ansiEscapeLiteral[${_codes}m';

  /// Represents the value as an unescaped literal suitable for scripts.
  String get escapeForScript => '$_ansiEscapeForScript[${_codes}m';

  String _escapeValue({bool forScript = false}) =>
      forScript ? escapeForScript : escape;

  /// Wraps [value] with the [escape] value for this code, followed by
  /// [resetAll].
  ///
  /// If [forScript] is `true`, the return value is an unescaped literal. The
  /// value of [ansiOutputEnabled] is also ignored.
  ///
  /// Returns `value` unchanged if
  ///   * [value] is `null` or empty
  ///   * both [ansiOutputEnabled] and [forScript] are `false`.
  ///   * [type] is [AnsiCodeType.reset]
  String? wrap(String? value, {bool forScript = false}) {
    if (value == null || value.isEmpty) return value;

    if (type == AnsiCodeType.reset || _isNoop(forScript)) {
      return value;
    }
    assert(type != AnsiCodeType.reset);
    return '${_escapeValue(forScript: forScript)}$value'
        '${reset!._escapeValue(forScript: forScript)}';
  }

  /// The [escape] sequence.
  ///
  /// Allows a code to be used directly in a string literal
  /// ```dart
  /// print("I ${red}love ${brown}pie!${resetAll}");
  /// ```
  @override
  String toString() => escape;
}

/// Returns a [String] formatted with [codes].
///
/// If [forScript] is `true`, the return value is an unescaped literal. The
/// value of [ansiOutputEnabled] is also ignored.
///
/// Returns `value` unchanged if
///   * [value] is `null` or empty.
///   * both [ansiOutputEnabled] and [forScript] are `false`.
///   * [codes] is empty.
///
/// Throws an [ArgumentError] if
///   * [codes] contains more than one value of type [AnsiCodeType.foreground].
///   * [codes] contains more than one value of type [AnsiCodeType.background].
///   * [codes] contains any value of type [AnsiCodeType.reset].
String? wrapWith(String? value, Iterable<AnsiCode> codes,
    {bool forScript = false}) {
  if (value == null || value.isEmpty) return value;
  // Eliminate duplicates
  final myCodes = codes.toSet();

  if (myCodes.isEmpty || _isNoop(forScript)) {
    return value;
  }

  var foreground = 0, background = 0;
  for (var code in myCodes) {
    switch (code.type) {
      case AnsiCodeType.foreground:
        foreground++;
        if (foreground > 1) {
          throw ArgumentError.value(codes, 'codes',
              'Cannot contain more than one foreground color code.');
        }
      case AnsiCodeType.background:
        background++;
        if (background > 1) {
          throw ArgumentError.value(codes, 'codes',
              'Cannot contain more than one foreground color code.');
        }
      case AnsiCodeType.reset:
        throw ArgumentError.value(
            codes, 'codes', 'Cannot contain reset codes.');
      case AnsiCodeType.style:
      // Ignore.
    }
  }

  final sortedCodes = myCodes.toList()
    ..sort((a, b) => a.code.compareTo(b.code));
  final resets = <AnsiCode>{}; // Include each reset only once.
  for (var code in sortedCodes.reversed) {
    final resetCode = code.reset!;
    if (!identical(resetCode, resetAll)) {
      resets.add(resetCode);
    } else {
      resets
        ..clear()
        ..add(resetAll);
      break;
    }
  }
  final escapeValue = forScript ? _ansiEscapeForScript : _ansiEscapeLiteral;
  final buffer = StringBuffer();
  buffer
    ..write(escapeValue)
    ..write('[')
    ..writeAll(sortedCodes.map((c) => c._codes), ';')
    ..write('m')
    ..write(value)
    ..write(escapeValue)
    ..write('[')
    ..writeAll(resets.map((c) => c._codes), ';')
    ..write('m');
  return buffer.toString();
}

//
// Style values
//

const styleBold = AnsiCode._('bold', AnsiCodeType.style, 1, resetBold);
const styleDim = AnsiCode._('dim', AnsiCodeType.style, 2, resetDim);
const styleItalic = AnsiCode._('italic', AnsiCodeType.style, 3, resetItalic);
const styleUnderlined =
    AnsiCode._('underlined', AnsiCodeType.style, 4, resetUnderlined);
const styleBlink = AnsiCode._('blink', AnsiCodeType.style, 5, resetBlink);
const styleReverse = AnsiCode._('reverse', AnsiCodeType.style, 7, resetReverse);

/// Not widely supported.
const styleHidden = AnsiCode._('hidden', AnsiCodeType.style, 8, resetHidden);

/// Not widely supported.
const styleCrossedOut =
    AnsiCode._('crossed out', AnsiCodeType.style, 9, resetCrossedOut);

//
// Reset values
//

const resetAll = AnsiCode._('all', AnsiCodeType.reset, 0, null);

// NOTE: Bold and dim(/faint) are both reset using code 22.
// Code 21 is "double underline" in some specifications.
// See https://gitlab.com/gnachman/iterm2/issues/3208
const resetBold = AnsiCode._('bold', AnsiCodeType.reset, 22, null);
const resetDim = AnsiCode._('dim', AnsiCodeType.reset, 22, null);
const resetItalic = AnsiCode._('italic', AnsiCodeType.reset, 23, null);
const resetUnderlined = AnsiCode._('underlined', AnsiCodeType.reset, 24, null);
const resetBlink = AnsiCode._('blink', AnsiCodeType.reset, 25, null);
const resetReverse = AnsiCode._('reverse', AnsiCodeType.reset, 27, null);
const resetHidden = AnsiCode._('hidden', AnsiCodeType.reset, 28, null);
const resetCrossedOut = AnsiCode._('crossed out', AnsiCodeType.reset, 29, null);

//
// Foreground values
//

const black = AnsiCode._('black', AnsiCodeType.foreground, 30, resetAll);
const red = AnsiCode._('red', AnsiCodeType.foreground, 31, resetAll);
const green = AnsiCode._('green', AnsiCodeType.foreground, 32, resetAll);
const yellow = AnsiCode._('yellow', AnsiCodeType.foreground, 33, resetAll);
const blue = AnsiCode._('blue', AnsiCodeType.foreground, 34, resetAll);
const magenta = AnsiCode._('magenta', AnsiCodeType.foreground, 35, resetAll);
const cyan = AnsiCode._('cyan', AnsiCodeType.foreground, 36, resetAll);
const lightGray =
    AnsiCode._('light gray', AnsiCodeType.foreground, 37, resetAll);
const defaultForeground =
    AnsiCode._('default', AnsiCodeType.foreground, 39, resetAll);
const darkGray = AnsiCode._('dark gray', AnsiCodeType.foreground, 90, resetAll);
const lightRed = AnsiCode._('light red', AnsiCodeType.foreground, 91, resetAll);
const lightGreen =
    AnsiCode._('light green', AnsiCodeType.foreground, 92, resetAll);
const lightYellow =
    AnsiCode._('light yellow', AnsiCodeType.foreground, 93, resetAll);
const lightBlue =
    AnsiCode._('light blue', AnsiCodeType.foreground, 94, resetAll);
const lightMagenta =
    AnsiCode._('light magenta', AnsiCodeType.foreground, 95, resetAll);
const lightCyan =
    AnsiCode._('light cyan', AnsiCodeType.foreground, 96, resetAll);
const white = AnsiCode._('white', AnsiCodeType.foreground, 97, resetAll);

//
// Background values
//

const backgroundBlack =
    AnsiCode._('black', AnsiCodeType.background, 40, resetAll);
const backgroundRed = AnsiCode._('red', AnsiCodeType.background, 41, resetAll);
const backgroundGreen =
    AnsiCode._('green', AnsiCodeType.background, 42, resetAll);
const backgroundYellow =
    AnsiCode._('yellow', AnsiCodeType.background, 43, resetAll);
const backgroundBlue =
    AnsiCode._('blue', AnsiCodeType.background, 44, resetAll);
const backgroundMagenta =
    AnsiCode._('magenta', AnsiCodeType.background, 45, resetAll);
const backgroundCyan =
    AnsiCode._('cyan', AnsiCodeType.background, 46, resetAll);
const backgroundLightGray =
    AnsiCode._('light gray', AnsiCodeType.background, 47, resetAll);
const backgroundDefault =
    AnsiCode._('default', AnsiCodeType.background, 49, resetAll);
const backgroundDarkGray =
    AnsiCode._('dark gray', AnsiCodeType.background, 100, resetAll);
const backgroundLightRed =
    AnsiCode._('light red', AnsiCodeType.background, 101, resetAll);
const backgroundLightGreen =
    AnsiCode._('light green', AnsiCodeType.background, 102, resetAll);
const backgroundLightYellow =
    AnsiCode._('light yellow', AnsiCodeType.background, 103, resetAll);
const backgroundLightBlue =
    AnsiCode._('light blue', AnsiCodeType.background, 104, resetAll);
const backgroundLightMagenta =
    AnsiCode._('light magenta', AnsiCodeType.background, 105, resetAll);
const backgroundLightCyan =
    AnsiCode._('light cyan', AnsiCodeType.background, 106, resetAll);
const backgroundWhite =
    AnsiCode._('white', AnsiCodeType.background, 107, resetAll);

/// All of the [AnsiCode] values that represent [AnsiCodeType.style].
const List<AnsiCode> styles = [
  styleBold,
  styleDim,
  styleItalic,
  styleUnderlined,
  styleBlink,
  styleReverse,
  styleHidden,
  styleCrossedOut
];

/// All of the [AnsiCode] values that represent [AnsiCodeType.foreground].
const List<AnsiCode> foregroundColors = [
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  lightGray,
  defaultForeground,
  darkGray,
  lightRed,
  lightGreen,
  lightYellow,
  lightBlue,
  lightMagenta,
  lightCyan,
  white
];

/// All of the [AnsiCode] values that represent [AnsiCodeType.background].
const List<AnsiCode> backgroundColors = [
  backgroundBlack,
  backgroundRed,
  backgroundGreen,
  backgroundYellow,
  backgroundBlue,
  backgroundMagenta,
  backgroundCyan,
  backgroundLightGray,
  backgroundDefault,
  backgroundDarkGray,
  backgroundLightRed,
  backgroundLightGreen,
  backgroundLightYellow,
  backgroundLightBlue,
  backgroundLightMagenta,
  backgroundLightCyan,
  backgroundWhite
];
