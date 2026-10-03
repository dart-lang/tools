// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Character code constants and character classification predicates for
/// YAML 1.2 parsing and source modification.
///
/// Constants and predicates adhere to the [YAML 1.2 specification](https://yaml.org/spec/1.2.2/).
abstract final class YamlChar {
  /// Character code for horizontal tab (`\t`).
  static const int tab = 0x09;

  /// Character code for line feed (`\n`).
  static const int lineFeed = 0x0A;

  /// Character code for carriage return (`\r`).
  static const int carriageReturn = 0x0D;

  /// Character code for space (` `).
  static const int space = 0x20;

  /// Character code for quotation mark / double quote (`"`).
  static const int doubleQuote = 0x22;

  /// Character code for number sign / hash (`#`).
  static const int hash = 0x23;

  /// Character code for apostrophe / single quote (`'`).
  static const int singleQuote = 0x27;

  /// Character code for asterisk (`*`).
  static const int asterisk = 0x2A;

  /// Character code for comma (`,`).
  static const int comma = 0x2C;

  /// Character code for hyphen-minus (`-`).
  static const int hyphen = 0x2D;

  /// Character code for colon (`:`).
  static const int colon = 0x3A;

  /// Character code for question mark (`?`).
  static const int question = 0x3F;

  /// Character code for reverse solidus / backslash (`\`).
  static const int backslash = 0x5C;

  /// Character code for left square bracket (`[`).
  static const int leftSquare = 0x5B;

  /// Character code for right square bracket (`]`).
  static const int rightSquare = 0x5D;

  /// Character code for left curly brace (`{`).
  static const int leftCurly = 0x7B;

  /// Character code for right curly brace (`}`).
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
