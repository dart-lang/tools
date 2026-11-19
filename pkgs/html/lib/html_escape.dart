// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

// TODO(jmesserly): reconcile this with dart:web htmlEscape.
// This one might be more useful, as it is HTML5 spec compliant.
/// Escapes [text] for use in the
/// [HTML fragment serialization algorithm][1]. In particular, as described
/// in the [specification][2]:
///
/// - Replace any occurrence of the `&` character by the string `&amp;`.
/// - Replace any occurrences of the U+00A0 NO-BREAK SPACE character by the
///   string `&nbsp;`.
/// - If the algorithm was invoked in [attributeMode], replace any occurrences
///   of the `"` character by the string `&quot;`.
/// - Replace any occurrences of the `<` character by the string `&lt;`.
/// - Replace any occurrences of the `>` character by the string `&gt;`.
///
/// [1]: https://html.spec.whatwg.org/multipage/parsing.html#serializing-html-fragments
/// [2]: https://html.spec.whatwg.org/multipage/parsing.html#escapingString
String htmlSerializeEscape(String text, {bool attributeMode = false}) {
  // Copy unchanged runs at once instead of one-character strings.
  StringBuffer? result;
  var last = 0;
  for (var i = 0; i < text.length; i++) {
    String? replacement;
    switch (text.codeUnitAt(i)) {
      case 0x26: // &
        replacement = '&amp;';
      case 0xA0: // NO-BREAK SPACE
        replacement = '&nbsp;';
      case 0x22: // "
        if (attributeMode) replacement = '&quot;';
      case 0x3C: // <
        replacement = '&lt;';
      case 0x3E: // >
        replacement = '&gt;';
    }
    if (replacement != null) {
      result ??= StringBuffer();
      result.write(text.substring(last, i));
      result.write(replacement);
      last = i + 1;
    }
  }

  if (result == null) return text;
  result.write(text.substring(last));
  return result.toString();
}
