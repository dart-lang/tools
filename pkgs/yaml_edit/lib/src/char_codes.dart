// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Character code constants and character classification predicates for
/// YAML 1.2 parsing and source modification.
///
/// Constants and predicates adhere to the [YAML 1.2 specification](https://yaml.org/spec/1.2.2/).
abstract final class YamlChar {
  /// Character code for horizontal tab (`\t`, `#x09`).
  static const int tab = 0x09;

  /// Character code for line feed (`\n`, `#x0A`).
  static const int lineFeed = 0x0A;

  /// Character code for carriage return (`\r`, `#x0D`).
  static const int carriageReturn = 0x0D;

  /// Character code for space (` `, `#x20`).
  static const int space = 0x20;

  /// Character code for number sign / hash (`#`, `#x23`).
  static const int hash = 0x23;

  /// Character code for asterisk (`*`, `#x2A`).
  static const int asterisk = 0x2A;

  /// Character code for comma (`,`, `#x2C`).
  static const int comma = 0x2C;

  /// Character code for hyphen-minus (`-`, `#x2D`).
  static const int hyphen = 0x2D;

  /// Character code for colon (`:`, `#x3A`).
  static const int colon = 0x3A;

  /// Character code for question mark (`?`, `#x3F`).
  static const int question = 0x3F;

  /// Character code for left square bracket (`[`, `#x5B`).
  static const int leftSquare = 0x5B;

  /// Character code for right square bracket (`]`, `#x5D`).
  static const int rightSquare = 0x5D;

  /// Character code for left curly brace (`{`, `#x7B`).
  static const int leftCurly = 0x7B;

  /// Character code for right curly brace (`}`, `#x7D`).
  static const int rightCurly = 0x7D;

  /// Returns `true` if [codeUnit] represents YAML whitespace (`space`
  /// or `tab`).
  ///
  /// See [YAML 1.2 rule 26 (s-white)](https://yaml.org/spec/1.2.2/#rule-s-white).
  ///
  /// Runs in O(1) constant time.
  static bool isWhitespace(int codeUnit) =>
      codeUnit == space || codeUnit == tab;

  /// Returns `true` if [codeUnit] represents a YAML line break (`LF` or `CR`).
  ///
  /// See [YAML 1.2 rule 29 (b-char)](https://yaml.org/spec/1.2.2/#rule-b-char).
  ///
  /// Runs in O(1) constant time.
  static bool isLineBreak(int codeUnit) =>
      codeUnit == lineFeed || codeUnit == carriageReturn;

  /// Returns `true` if [codeUnit] represents a YAML flow indicator
  /// (`,`, `[`, `]`, `{`, or `}`).
  ///
  /// See [YAML 1.2 rule 23 (c-flow-indicator)](https://yaml.org/spec/1.2.2/#rule-c-flow-indicator).
  ///
  /// Runs in O(1) constant time.
  static bool isFlowIndicator(int codeUnit) =>
      codeUnit == comma ||
      codeUnit == leftSquare ||
      codeUnit == rightSquare ||
      codeUnit == leftCurly ||
      codeUnit == rightCurly;

  /// Returns `true` if [codeUnit] can be part of a YAML anchor or alias name.
  ///
  /// Anchor characters cannot be whitespace, line breaks, or flow indicators.
  /// See [YAML 1.2 rule 102 (ns-anchor-char)](https://yaml.org/spec/1.2.2/#rule-ns-anchor-char).
  ///
  /// Runs in O(1) constant time.
  static bool isAnchorChar(int codeUnit) =>
      !isWhitespace(codeUnit) &&
      !isLineBreak(codeUnit) &&
      !isFlowIndicator(codeUnit);
}
