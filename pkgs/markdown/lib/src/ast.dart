// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A resolver for reference links that do not resolve to a declaration.
///
/// Does not have access to the link text. Use a [LinkBuilder] instead.
typedef Resolver = Node? Function(String name, [String? title]);

/// A builder for reference links that do not resolve to a declaration.
///
/// Receives the label, title (if available) and a function to extract
/// the child nodes of the reference link.
///
/// Example: `[link _text_!][label]` has label "label", no title, and
/// child nodes equivalent to `link _text_!`.
/// Calling `getChildren` removes the nodes from the parsing,
/// and should be called if and only if a non-`null` result is returned.
typedef LinkBuilder =
    List<Node>? Function(
      String label,
      String? title,
      List<Node> Function() getChildren,
    );

Resolver? linkResolverFromBuilder(LinkBuilder? builder) => builder == null
    ? null
    : (String label, [String? title]) {
        final nodes = builder(label, title, () => []);
        if (nodes == null) return null;
        if (nodes.length == 1) return nodes.first;
        return Element('span', nodes);
      };

LinkBuilder? linkBuilderFromResolver(Resolver? resolver) => resolver == null
    ? null
    : (String label, String? title, List<Node> Function() getChildren) {
        print(">> OLD RESOLVER CALLED");
        final node = resolver(label, title);
        if (node != null) {
          getChildren();
          return [node];
        }
        return null;
      };

/// Base class for any AST item.
///
/// Roughly corresponds to Node in the DOM. Will be either an Element or Text.
abstract class Node {
  void accept(NodeVisitor visitor);

  String get textContent;
}

/// A named tag that can contain other nodes.
class Element implements Node {
  final String tag;
  final List<Node>? children;
  final Map<String, String> attributes;
  String? generatedId;
  String? footnoteLabel;

  /// Instantiates a [tag] Element with [children].
  Element(this.tag, this.children, [Map<String, String>? attributes])
    : attributes = {...?attributes};

  /// Instantiates an empty, self-closing [tag] Element.
  Element.empty(this.tag, [Map<String, String>? attributes])
    : children = null,
      attributes = {...?attributes};

  /// Instantiates a [tag] Element with no [children].
  Element.withTag(this.tag, [Map<String, String>? attributes])
    : children = const [],
      attributes = {...?attributes};

  /// Instantiates a [tag] Element with a single Text child.
  Element.text(this.tag, String text, [Map<String, String>? attributes])
    : children = [Text(text)],
      attributes = {...?attributes};

  /// Whether this element is self-closing.
  bool get isEmpty => children == null;

  @override
  void accept(NodeVisitor visitor) {
    if (visitor.visitElementBefore(this)) {
      if (children != null) {
        for (final child in children!) {
          child.accept(visitor);
        }
      }
      visitor.visitElementAfter(this);
    }
  }

  @override
  String get textContent {
    final children = this.children;
    return children == null
        ? ''
        : children.map((child) => child.textContent).join();
  }
}

/// A plain text element.
class Text implements Node {
  final String text;

  Text(this.text);

  @override
  void accept(NodeVisitor visitor) => visitor.visitText(this);

  @override
  String get textContent => text;
}

/// Inline content that has not been parsed into inline nodes (strong, links,
/// etc).
///
/// These placeholder nodes should only remain in place while the block nodes
/// of a document are still being parsed, in order to gather all reference link
/// definitions.
class UnparsedContent implements Node {
  @override
  final String textContent;

  UnparsedContent(this.textContent);

  @override
  void accept(NodeVisitor visitor) {}
}

/// Visitor pattern for the AST.
///
/// Renderers or other AST transformers should implement this.
abstract class NodeVisitor {
  /// Called when a Text node has been reached.
  void visitText(Text text);

  /// Called when an Element has been reached, before its children have been
  /// visited.
  ///
  /// Returns `false` to skip its children.
  bool visitElementBefore(Element element);

  /// Called when an Element has been reached, after its children have been
  /// visited.
  ///
  /// Will not be called if [visitElementBefore] returns `false`.
  void visitElementAfter(Element element);
}
