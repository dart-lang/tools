/// @docImport 'link_syntax.dart';
library;

import '../ast.dart' show Element, Node, Text;
import '../charcode.dart';
import '../document.dart' show DocumentFootnotes;
import 'link_syntax.dart' show LinkContext;

/// The spec of GFM about footnotes is
/// [missing](https://github.com/github/cmark-gfm/issues/283#issuecomment-1378868725).
/// For source code of cmark-gfm, see the `noMatch` label of the
/// `handle_close_bracket` function in [master@c32ef78](https://github.com/github/cmark-gfm/blob/c32ef78/src/inlines.c#L1236).
/// A Rust implementation is also [available](https://github.com/wooorm/markdown-rs/blob/2498e31eecead798efc649502bbf5f86feaa94be/src/construct/gfm_label_start_footnote.rs).
/// Footnotes shares the same syntax with [LinkSyntax],
/// but have a different branch of handling the close bracket.
class FootnoteRefSyntax {
  static String? _footnoteLabel(String key) {
    if (key.isEmpty || key.codeUnitAt(0) != $caret) {
      return null;
    }
    key = key.substring(1).trim().toLowerCase();
    if (key.isEmpty) {
      return null;
    }
    return key;
  }

  static Iterable<Node>? tryCreateFootnoteLink(
    LinkContext context,
    String text, {
    bool? secondary,
  }) {
    secondary ??= false;
    final parser = context.parser;
    final refs = parser.document.footnoteReferences;
    if (refs.isEmpty) {
      return null;
    }
    final key = _footnoteLabel(text);
    if (key == null) {
      return null;
    }
    // `label` is what footnoteReferences stored, it is case sensitive.
    final label = parser.document.findFootnoteLabel(key);
    // `count != null` means footnote was valid.
    var count = label == null ? null : refs[label];
    // And then check if footnote was matched.
    if (label == null || count == null) {
      return null;
    }
    final result = <Node>[];
    // There are 4 cases here: ![^...], [^...], ![...][^...], [...][^...]
    if (context.opener.char == $exclamation) {
      result.add(Text('!'));
    }
    refs[label] = ++count;
    final pos = parser.document.footnoteLabelOrdinal(key);

    // `children` are text segments after '[^' before ']'.
    final children = context.getChildren();
    if (secondary) {
      result.add(Text('['));
      result.addAll(children);
      result.add(Text(']'));
    }
    final id = Uri.encodeComponent(label);
    final suffix = count > 1 ? '-$count' : '';
    final link = Element('a', [Text('${pos + 1}')])
      // Ignore GitHub's attribute: <data-footnote-ref>.
      ..attributes['href'] = '#fn-$id'
      ..attributes['id'] = 'fnref-$id$suffix';
    final sup = Element('sup', [link])..attributes['class'] = 'footnote-ref';
    result.add(sup);
    return result;
  }
}
