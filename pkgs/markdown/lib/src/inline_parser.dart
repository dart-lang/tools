// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'ast.dart';
import 'charcode.dart';
import 'document.dart';
import 'inline_syntaxes/autolink_syntax.dart';
import 'inline_syntaxes/code_syntax.dart';
import 'inline_syntaxes/decode_html_syntax.dart';
import 'inline_syntaxes/delimiter_syntax.dart';
import 'inline_syntaxes/email_autolink_syntax.dart';
import 'inline_syntaxes/emphasis_syntax.dart';
import 'inline_syntaxes/escape_html_syntax.dart';
import 'inline_syntaxes/escape_syntax.dart';
import 'inline_syntaxes/image_syntax.dart';
import 'inline_syntaxes/inline_syntax.dart';
import 'inline_syntaxes/line_break_syntax.dart';
import 'inline_syntaxes/link_syntax.dart';
import 'inline_syntaxes/soft_line_break_syntax.dart';
import 'inline_syntaxes/text_syntax.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
class InlineParser {
  static final List<InlineSyntax>
  _defaultSyntaxes = List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    EmailAutolinkSyntax(),
    AutolinkSyntax(),
    LineBreakSyntax(),
    // Parse "**strong**" and "*emphasis*" tags.
    EmphasisSyntax.asterisk(),
    // Parse "__strong__" and "_emphasis_" tags.
    EmphasisSyntax.underscore(),
    CodeSyntax(),
    SoftLineBreakSyntax(),
    // We will add the LinkSyntax once we know about the specific link resolver.
  ]);

  /// The string of Markdown being parsed.
  final String source;

  /// The Markdown document this parser is parsing.
  final Document document;

  final syntaxes = <InlineSyntax>[];

  /// The current read position.
  int pos = 0;

  /// Starting position of the last unconsumed text.
  int start = 0;

  /// The delimiter stack tracking possible opening delimiters and closing
  /// delimiters for [DelimiterSyntax] nodes.
  final _delimiterStack = LinkedList<_DelimiterNode>();

  /// Top of the open bracket stack (`[` or `![` delimiters).
  _DelimiterNode? _topBracket;

  /// Top of the active link bracket stack (`[` delimiters with `isActive`).
  _DelimiterNode? _topActiveLinkBracket;

  int _nextDelimiterPos = 0;

  /// The tree of parsed HTML nodes.
  final _tree = LinkedList<_TreeNode>();

  InlineParser(this.source, this.document) {
    // User specified syntaxes are the first syntaxes to be evaluated.
    syntaxes.addAll(document.inlineSyntaxes);

    // This first RegExp matches plain text to accelerate parsing. It's written
    // so that it does not match any prefix of any following syntaxes. Most
    // Markdown is plain text, so it's faster to match one RegExp per 'word'
    // rather than fail to match all the following RegExps at each non-syntax
    // character position.
    // The `(?=\s|$)` lookahead lets the run stop before whitespace or at the
    // end of a line. Without the `$` alternative a run that reaches the end of
    // a line without a trailing whitespace (for example a single long word)
    // fails the lookahead only after the greedy `*`/`+` has consumed the rest
    // of the line, then backtracks one character at a time, and the parser
    // retries from the next position, giving quadratic behavior on long
    // unbroken runs. Allowing the run to end at `$` makes it match in one step.
    if (document.hasCustomInlineSyntaxes) {
      // We should be less aggressive in blowing past "words".
      syntaxes.add(TextSyntax(r'[A-Za-z0-9]+(?=\s|$)'));
    } else {
      syntaxes.add(TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9](?=\s|$)'));
    }

    if (document.withDefaultInlineSyntaxes) {
      // Custom link resolvers go after the generic text syntax.
      syntaxes.addAll([
        EscapeSyntax(),
        DecodeHtmlSyntax(),
        LinkSyntax(linkBuilder: document.linkBuilder),
        ImageSyntax(linkBuilder: document.imageLinkBuilder),
      ]);

      syntaxes.addAll(_defaultSyntaxes);
    }

    if (encodeHtml) {
      syntaxes.addAll([
        EscapeHtmlSyntax(),
        // Leave already-encoded HTML entities alone. Ensures we don't turn
        // "&amp;" into "&amp;amp;"
        TextSyntax('&[#a-zA-Z0-9]*;', startCharacter: $ampersand),
      ]);
    }
  }

  List<Node> parse() {
    while (!isDone) {
      // A right bracket (']') is special. Hitting this character triggers the
      // "look for link or image" procedure.
      // See https://spec.commonmark.org/0.30/#an-algorithm-for-parsing-nested-emphasis-and-links.
      if (charAt(pos) == $rbracket) {
        writeText();
        _linkOrImage();
        continue;
      }

      // See if the current text matches any defined Markdown syntax.
      if (syntaxes.any((syntax) => syntax.tryMatch(this))) continue;

      // If we got here, it's just text.
      advanceBy(1);
    }

    // Write any trailing text content to a Text node.
    writeText();
    _processDelimiterRun(null);
    final result = [for (final treeNode in _tree) treeNode.node];
    _combineAdjacentText(result);
    return result;
  }

  /// Look back through the delimiter stack to see if we've found a link or
  /// image.
  ///
  /// This is the "look for link or image" routine from the CommonMark spec:
  /// https://spec.commonmark.org/0.31.2/#look-for-link-or-image.
  void _linkOrImage() {
    final bracketNode = _topBracket;
    if (bracketNode == null) {
      // Never found a possible open bracket. This is just a literal "]".
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    final delimiter = bracketNode.delimiter as SimpleDelimiter;
    if (!delimiter.isActive) {
      _topBracket = bracketNode.previousBracket;
      bracketNode.unlink();
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    final syntax = delimiter.syntax;
    if (syntax is LinkSyntax && syntaxes.any((e) => e is LinkSyntax)) {
      final delimiterTreeNode = bracketNode.treeNode!;
      final linkNodes = syntax.close(
        this,
        delimiter,
        null,
        getChildren: () {
          _processDelimiterRun(bracketNode);
          // All of the nodes which lie past [bracketNode] are children of this
          // link/image.
          final children = <Node>[];
          while (delimiterTreeNode.next != null) {
            children.add(delimiterTreeNode.next!.node);
            delimiterTreeNode.next!.unlink();
          }
          return children;
        },
      );
      if (linkNodes != null) {
        _topBracket = bracketNode.previousBracket;
        while (bracketNode.next != null) {
          bracketNode.next!.unlink();
        }
        bracketNode.unlink();
        if (delimiter.char == $lbracket) {
          for (
            var b = _topActiveLinkBracket;
            b != null;
            b = b.previousActiveLinkBracket
          ) {
            b.delimiter.isActive = false;
          }
          _topActiveLinkBracket = null;
        }
        while (delimiterTreeNode.next != null) {
          delimiterTreeNode.next!.unlink();
        }
        delimiterTreeNode.unlink();
        for (final node in linkNodes) {
          _tree.add(_TreeNode(node));
        }
        advanceBy(1);
        start = pos;
      } else {
        _topBracket = bracketNode.previousBracket;
        bracketNode.unlink();
        pos = start;
        advanceBy(1);
      }
    } else {
      throw StateError(
        'Non-link syntax delimiter found with character '
        '"${delimiter.char}"',
      );
    }
  }

  /// Rules 9 and 10.
  bool _canFormEmphasis(Delimiter opener, Delimiter closer) {
    if ((opener.canOpen && opener.canClose) ||
        (closer.canOpen && closer.canClose)) {
      return (opener.length + closer.length) % 3 != 0 ||
          (opener.length % 3 == 0 && closer.length % 3 == 0);
    } else {
      return true;
    }
  }

  /// Processes [DelimiterRun] type delimiters from [bottom] and up.
  ///
  /// This is the same strategy as "process emphasis" routine according to the
  /// CommonMark spec: https://spec.commonmark.org/0.31.2/#phase-2-inline-structure.
  void _processDelimiterRun(_DelimiterNode? bottom) {
    final bottomIndex = bottom?.pos ?? -1;
    var next = bottom == null ? _delimiterStack.firstOrNull : bottom.next;
    // Track the lowest index where we might find an open delimiter given a
    // closing delimiter length modulo 3.
    // Each key in this map is an open delimiter character. Each value is a
    // 3-element list. Each value in the list is the lowest index for the given
    // delimiter length modulo 3 (0, 1, 2).
    final openersBottom = <int, List<int>>{};
    while (next != null) {
      final current = next;
      next = current.next;
      final closer = current.delimiter;
      if (!closer.canClose || closer is! DelimiterRun) {
        continue;
      }
      openersBottom.putIfAbsent(closer.char, () => List.filled(3, bottomIndex));
      final openersBottomPerCloserLength = openersBottom[closer.char]!;
      final openerBottom = openersBottomPerCloserLength[closer.length % 3];
      var openerNode = current.previous;
      while (openerNode != null &&
          openerNode.pos > openerBottom &&
          !(openerNode.delimiter.char == closer.char &&
              openerNode.delimiter.canOpen &&
              _canFormEmphasis(openerNode.delimiter, closer))) {
        openerNode = openerNode.previous;
      }
      if (openerNode != null && openerNode.pos > openerBottom) {
        // Found an opener for [closer].
        final opener = openerNode.delimiter;
        if (opener is! DelimiterRun) {
          continue;
        }
        final matchedTagIndex = opener.tags.lastIndexWhere(
          (e) =>
              opener.length >= e.indicatorLength &&
              closer.length >= e.indicatorLength,
        );
        if (matchedTagIndex == -1) {
          continue;
        }
        final matchedTag = opener.tags[matchedTagIndex];
        final indicatorLength = matchedTag.indicatorLength;
        final openerTextNode = opener.node;
        final openerTreeNode = openerNode.treeNode!;
        final closerTextNode = closer.node;
        final closerTreeNode = current.treeNode!;
        final nodes = opener.syntax.close(
          this,
          opener,
          closer,
          tag: matchedTag.tag,
          getChildren: () {
            final children = <Node>[];
            for (
              var t = openerTreeNode.next;
              t != null && t != closerTreeNode;
              t = t.next
            ) {
              children.add(t.node);
            }
            return children;
          },
        );
        // Replace all of the nodes between the opener and the closer (which
        // are now the new emphasis node's children) with the emphasis node.
        while (openerTreeNode.next != closerTreeNode) {
          openerTreeNode.next!.unlink();
        }
        for (final node in nodes!) {
          closerTreeNode.insertBefore(_TreeNode(node));
        }

        while (openerNode.next != current) {
          openerNode.next!.unlink();
        }

        // Remove delimiter characters, possibly removing nodes from the tree
        // and Delimiters from the delimiter stack.
        if (opener.length == indicatorLength) {
          openerTreeNode.unlink();
          openerNode.unlink();
        } else {
          final newOpenerTextNode = Text(
            openerTextNode.text.substring(indicatorLength),
          );
          openerTreeNode.node = newOpenerTextNode;
          opener.node = newOpenerTextNode;
        }

        if (closer.length == indicatorLength) {
          closerTreeNode.unlink();
          current.unlink();
        } else {
          final newCloserTextNode = Text(
            closerTextNode.text.substring(indicatorLength),
          );
          closerTreeNode.node = newCloserTextNode;
          closer.node = newCloserTextNode;
          // [current] needs to be considered again; leave it.
          next = current;
        }
      } else {
        // No opener is found.
        openersBottomPerCloserLength[closer.length % 3] =
            current.previous?.pos ?? -1;
        if (!closer.canOpen) {
          current.unlink();
        }
      }
    }

    while (_delimiterStack.isNotEmpty && _delimiterStack.last != bottom) {
      _delimiterStack.last.unlink();
    }
  }

  // Combine any remaining adjacent Text nodes. This is important to produce
  // correct output across newlines, where whitespace is sometimes compressed.
  void _combineAdjacentText(List<Node> rootNodes) {
    final stack = <List<Node>>[rootNodes];
    while (stack.isNotEmpty) {
      final nodes = stack.removeLast();
      var writeIndex = 0;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node is Element && node.children != null) {
          stack.add(node.children!);
          if (writeIndex != i) nodes[writeIndex] = node;
          writeIndex++;
        } else if (node is Text &&
            i + 1 < nodes.length &&
            nodes[i + 1] is Text) {
          final buffer = StringBuffer(
            '${node.textContent}${nodes[i + 1].textContent}',
          );
          var j = i + 2;
          while (j < nodes.length && nodes[j] is Text) {
            buffer.write(nodes[j].textContent);
            j++;
          }
          nodes[writeIndex++] = Text(buffer.toString());
          i = j - 1;
        } else {
          if (writeIndex != i) nodes[writeIndex] = node;
          writeIndex++;
        }
      }
      if (writeIndex != nodes.length) {
        nodes.length = writeIndex;
      }
    }
  }

  int charAt(int index) => source.codeUnitAt(index);

  void writeText() {
    if (pos == start) {
      return;
    }
    final text = source.substring(start, pos);
    _tree.add(_TreeNode(Text(text)));
    start = pos;
  }

  /// Add [node] to the current tree.
  void addNode(Node node) {
    final treeNode = _TreeNode(node);
    _tree.add(treeNode);
    final d = _delimiterStack.lastOrNull;
    if (d != null && d.delimiter.node == node) {
      d.treeNode = treeNode;
    }
  }

  /// Push [delimiter] onto the stack of [Delimiter]s.
  void pushDelimiter(Delimiter delimiter) {
    final node = _DelimiterNode(delimiter, _nextDelimiterPos++);
    _delimiterStack.add(node);
    if (delimiter is SimpleDelimiter &&
        delimiter.syntax is LinkSyntax &&
        (delimiter.char == $lbracket || delimiter.char == $exclamation)) {
      node.previousBracket = _topBracket;
      _topBracket = node;
      if (delimiter.char == $lbracket) {
        node.previousActiveLinkBracket = _topActiveLinkBracket;
        _topActiveLinkBracket = node;
      }
    }
  }

  bool get isDone => pos >= source.length;

  void advanceBy(int length) {
    pos += length;
  }

  void consume(int length) {
    pos += length;
    start = pos;
  }

  bool get encodeHtml => document.encodeHtml;
}

final class _TreeNode extends LinkedListEntry<_TreeNode> {
  Node node;

  _TreeNode(this.node);
}

final class _DelimiterNode extends LinkedListEntry<_DelimiterNode> {
  final Delimiter delimiter;
  final int pos;
  _TreeNode? treeNode;
  _DelimiterNode? previousBracket;
  _DelimiterNode? previousActiveLinkBracket;

  _DelimiterNode(this.delimiter, this.pos);
}
