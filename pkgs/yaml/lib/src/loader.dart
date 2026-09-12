// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' show max;

import 'package:source_span/source_span.dart';

import 'charcodes.dart';
import 'equality.dart';
import 'error_listener.dart';
import 'event.dart';
import 'layout.dart';
import 'parser.dart';
import 'style.dart';
import 'yaml_document.dart';
import 'yaml_exception.dart';
import 'yaml_node.dart';

/// A loader that reads [Event]s emitted by a [Parser] and emits
/// [YamlDocument]s.
///
/// This is based on the libyaml loader, available at
/// https://github.com/yaml/libyaml/blob/master/src/loader.c. The license for
/// that is available in ../../libyaml-license.txt.
class Loader {
  /// The underlying [Parser] that generates [Event]s.
  final Parser _parser;

  /// Aliases by the alias name.
  final _aliases = <String, YamlNode>{};

  /// Anchors that are currently being resolved.
  final _activeAnchors = <String>{};

  /// The span of the entire stream emitted so far.
  FileSpan get span => _span;
  FileSpan _span;

  /// Creates a loader that loads [source].
  factory Loader(String source,
      {Uri? sourceUrl,
      bool recover = false,
      ErrorListener? errorListener,
      bool retainLayout = false}) {
    var parser = Parser(source,
        sourceUrl: sourceUrl,
        recover: recover,
        errorListener: errorListener,
        retainLayout: retainLayout);
    var event = parser.parse();
    assert(event.type == EventType.streamStart);
    return Loader._(parser, event.span);
  }

  Loader._(this._parser, this._span);

  /// Loads the next document from the stream.
  ///
  /// If there are no more documents, returns `null`.
  YamlDocument? load() {
    if (_parser.isDone) return null;

    var event = _parser.parse();
    if (event.type == EventType.streamEnd) {
      _span = _span.expand(event.span);
      return null;
    }

    var document = _loadDocument(event as DocumentStartEvent);
    _span = _span.expand(document.span as FileSpan);
    _aliases.clear();
    return document;
  }

  /// Composes a document object.
  YamlDocument _loadDocument(DocumentStartEvent firstEvent) {
    var contents = _loadNode(_parser.parse());

    var lastEvent = _parser.parse() as DocumentEndEvent;
    assert(lastEvent.type == EventType.documentEnd);

    return YamlDocument.internal(
        contents,
        firstEvent.span.expand(lastEvent.span),
        firstEvent.versionDirective,
        firstEvent.tagDirectives,
        startImplicit: firstEvent.isImplicit,
        endImplicit: lastEvent.isImplicit,
        startMarkerSpan: firstEvent.startMarkerSpan,
        endMarkerSpan: lastEvent.endMarkerSpan,
        leadingLayout: firstEvent.leadingLayout,
        trailingLayout: lastEvent.trailingLayout);
  }

  /// Composes a node.
  YamlNode _loadNode(Event firstEvent) => switch (firstEvent.type) {
        EventType.alias => _loadAlias(firstEvent as AliasEvent),
        EventType.scalar => _loadScalar(firstEvent as ScalarEvent),
        EventType.sequenceStart =>
          _loadSequence(firstEvent as SequenceStartEvent),
        EventType.mappingStart => _loadMapping(firstEvent as MappingStartEvent),
        _ => throw StateError('Unreachable')
      };

  /// Registers an anchor.
  void _registerAnchor(String? anchor, YamlNode node) {
    if (anchor == null) return;

    // libyaml throws an error for duplicate anchors, but example 7.1 makes it
    // clear that they should be overridden:
    // http://yaml.org/spec/1.2/spec.html#id2786448.

    _aliases[anchor] = node;
  }

  /// Composes a node corresponding to an alias.
  YamlNode _loadAlias(AliasEvent event) {
    var alias = _aliases[event.name];
    if (alias != null) {
      if (_activeAnchors.contains(event.name)) {
        throw YamlException(
            'Self-referential collections are not supported.', event.span);
      }
      return alias;
    }

    throw YamlException('Undefined alias.', event.span);
  }

  /// Composes a scalar node.
  YamlNode _loadScalar(ScalarEvent scalar) {
    YamlNode node;
    if (scalar.tag == '!') {
      node = YamlScalar.internal(scalar.value, scalar);
    } else if (scalar.tag != null) {
      node = _parseByTag(scalar);
    } else {
      node = _parseScalar(scalar);
    }

    setLayout(node,
        leading: scalar.leadingLayout, trailing: scalar.trailingLayout);
    if (scalar.anchorSpan != null) {
      setAnchorSpan(node, scalar.anchorSpan);
    }
    _registerAnchor(scalar.anchor, node);
    return node;
  }

  /// Composes a sequence node.
  YamlNode _loadSequence(SequenceStartEvent firstEvent) {
    if (firstEvent.tag != '!' &&
        firstEvent.tag != null &&
        firstEvent.tag != 'tag:yaml.org,2002:seq') {
      throw YamlException('Invalid tag for sequence.', firstEvent.span);
    }

    var children = <YamlNode>[];
    var dashSpans = <SourceSpan?>[];
    var aliasSpans = <SourceSpan?>[];
    var commaSpans = <SourceSpan?>[];
    var node = YamlList.internal(children, firstEvent.span, firstEvent.style);
    _registerAnchor(firstEvent.anchor, node);
    if (firstEvent.anchorSpan != null) {
      setAnchorSpan(node, firstEvent.anchorSpan);
    }

    Event event;
    try {
      if (firstEvent.anchor case final anchor?) _activeAnchors.add(anchor);
      event = _parser.parse();
      while (event.type != EventType.sequenceEnd) {
        dashSpans.add(_parser.lastDashSpan);
        commaSpans.add(_parser.lastCommaSpan);
        if (event is AliasEvent) {
          aliasSpans.add(event.span);
        } else {
          aliasSpans.add(null);
        }
        children.add(_loadNode(event));
        event = _parser.parse();
      }
    } finally {
      if (firstEvent.anchor case final anchor?) _activeAnchors.remove(anchor);
    }

    setSpan(node, firstEvent.span.expand(event.span));
    setLayout(node,
        leading: firstEvent.leadingLayout, trailing: event.trailingLayout);

    final openSpan = firstEvent.openSpan;
    final closeSpan = event.span.length > 0 ? event.span : null;

    final file = (node.span as FileSpan).file;
    final entrySpans = <SourceSpan?>[];
    if (children.isNotEmpty) {
      if (firstEvent.style == CollectionStyle.FLOW) {
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          if (children.length == 1) {
            entrySpans.add(child.span);
          } else if (i == 0) {
            final nextComma =
                i + 1 < commaSpans.length ? commaSpans[i + 1] : null;
            if (nextComma != null) {
              entrySpans.add(
                file.span(child.span.start.offset, nextComma.end.offset),
              );
            } else {
              entrySpans.add(child.span);
            }
          } else {
            final comma = commaSpans[i];
            if (comma != null) {
              final childEnd = aliasSpans[i]?.end ?? child.span.end;
              final endOffset = max(comma.start.offset, childEnd.offset);
              entrySpans.add(
                file.span(comma.start.offset, endOffset),
              );
            } else {
              entrySpans.add(child.span);
            }
          }
        }
      } else {
        for (var i = 0; i < children.length; i++) {
          final fallbackStart = dashSpans[i]?.start ??
              aliasSpans[i]?.start ??
              children[i].span.start;
          final startLoc = _getEntryStartLocation(
            leadingLayout: children[i].leadingLayout,
            fallback: fallbackStart,
          );
          final fallbackNext = (i + 1 < children.length)
              ? (dashSpans[i + 1]?.start ??
                  aliasSpans[i + 1]?.start ??
                  children[i + 1].span.start)
              : null;
          final endLoc = (i + 1 < children.length)
              ? _getEntryStartLocation(
                  leadingLayout: children[i + 1].leadingLayout,
                  fallback: fallbackNext!,
                )
              : node.span.end;
          final endOffset = max(startLoc.offset, endLoc.offset);
          entrySpans.add(file.span(startLoc.offset, endOffset));
        }
      }
    }

    setListLayoutSpans(
      node,
      dashSpans: dashSpans.any((s) => s != null) ? dashSpans : null,
      entrySpans: entrySpans.isNotEmpty ? entrySpans : null,
      aliasSpans: aliasSpans.any((s) => s != null) ? aliasSpans : null,
      commaSpans: commaSpans.any((s) => s != null) ? commaSpans : null,
      openSpan: openSpan,
      closeSpan: closeSpan,
    );
    return node;
  }

  /// Composes a mapping node.
  YamlNode _loadMapping(MappingStartEvent firstEvent) {
    if (firstEvent.tag != '!' &&
        firstEvent.tag != null &&
        firstEvent.tag != 'tag:yaml.org,2002:map') {
      throw YamlException('Invalid tag for mapping.', firstEvent.span);
    }

    var children = deepEqualsMap<dynamic, YamlNode>();
    var colonSpans = deepEqualsMap<dynamic, SourceSpan>();
    var aliasSpans = deepEqualsMap<dynamic, SourceSpan>();
    var commaSpans = deepEqualsMap<dynamic, SourceSpan>();
    var entrySpans = deepEqualsMap<dynamic, SourceSpan>();
    var orderedKeys = <YamlNode>[];
    var node = YamlMap.internal(children, firstEvent.span, firstEvent.style);
    _registerAnchor(firstEvent.anchor, node);
    if (firstEvent.anchorSpan != null) {
      setAnchorSpan(node, firstEvent.anchorSpan);
    }

    Event event;
    try {
      if (firstEvent.anchor case final anchor?) _activeAnchors.add(anchor);
      event = _parser.parse();
      while (event.type != EventType.mappingEnd) {
        var commaSpan = _parser.lastCommaSpan;
        var key = _loadNode(event);
        orderedKeys.add(key);
        if (commaSpan != null) {
          commaSpans[key] = commaSpan;
        }
        var valueEvent = _parser.parse();
        var colonSpan = _parser.lastColonSpan;
        if (colonSpan != null) {
          colonSpans[key] = colonSpan;
        }
        if (valueEvent is AliasEvent) {
          aliasSpans[key] = valueEvent.span;
        }
        var value = _loadNode(valueEvent);
        if (children.containsKey(key)) {
          throw YamlException('Duplicate mapping key.', key.span);
        }

        children[key] = value;
        event = _parser.parse();
      }
    } finally {
      if (firstEvent.anchor case final anchor?) _activeAnchors.remove(anchor);
    }

    setSpan(node, firstEvent.span.expand(event.span));
    setLayout(node,
        leading: firstEvent.leadingLayout, trailing: event.trailingLayout);

    final openSpan = firstEvent.openSpan;
    final closeSpan = event.span.length > 0 ? event.span : null;

    final file = (node.span as FileSpan).file;
    if (orderedKeys.isNotEmpty) {
      if (firstEvent.style == CollectionStyle.FLOW) {
        for (var i = 0; i < orderedKeys.length; i++) {
          final k = orderedKeys[i];
          final v = children[k]!;
          if (orderedKeys.length == 1) {
            final endOffset = max(k.span.start.offset, v.span.end.offset);
            entrySpans[k] = file.span(k.span.start.offset, endOffset);
          } else if (i == 0) {
            final nextK = orderedKeys[1];
            final nextComma = commaSpans[nextK];
            if (nextComma != null) {
              final endOffset = max(k.span.start.offset, nextComma.end.offset);
              entrySpans[k] = file.span(k.span.start.offset, endOffset);
            } else {
              final endOffset = max(k.span.start.offset, v.span.end.offset);
              entrySpans[k] = file.span(k.span.start.offset, endOffset);
            }
          } else {
            final comma = commaSpans[k];
            if (comma != null) {
              final endOffset = max(comma.start.offset, v.span.end.offset);
              entrySpans[k] = file.span(comma.start.offset, endOffset);
            } else {
              final endOffset = max(k.span.start.offset, v.span.end.offset);
              entrySpans[k] = file.span(k.span.start.offset, endOffset);
            }
          }
        }
      } else {
        // BLOCK style map
        for (var i = 0; i < orderedKeys.length; i++) {
          final k = orderedKeys[i];
          final startLoc = _getEntryStartLocation(
            leadingLayout: k.leadingLayout,
            fallback: k.span.start,
          );
          final endLoc = (i + 1 < orderedKeys.length)
              ? _getEntryStartLocation(
                  leadingLayout: orderedKeys[i + 1].leadingLayout,
                  fallback: orderedKeys[i + 1].span.start,
                )
              : node.span.end;
          final endOffset = max(startLoc.offset, endLoc.offset);
          entrySpans[k] = file.span(startLoc.offset, endOffset);
        }
      }
    }

    setMapLayoutSpans(
      node,
      colonSpans: colonSpans.isNotEmpty ? colonSpans : null,
      entrySpans: entrySpans.isNotEmpty ? entrySpans : null,
      aliasSpans: aliasSpans.isNotEmpty ? aliasSpans : null,
      commaSpans: commaSpans.isNotEmpty ? commaSpans : null,
      openSpan: openSpan,
      closeSpan: closeSpan,
    );
    return node;
  }

  SourceLocation _getEntryStartLocation({
    required List<LayoutElement> leadingLayout,
    required SourceLocation fallback,
  }) {
    var startIndex = 0;
    while (startIndex < leadingLayout.length &&
        leadingLayout[startIndex] is NewlineElement) {
      startIndex++;
    }
    if (startIndex < leadingLayout.length) {
      return leadingLayout[startIndex].span.start;
    }
    return fallback;
  }

  /// Parses a scalar according to its tag name.
  YamlScalar _parseByTag(ScalarEvent scalar) {
    switch (scalar.tag) {
      case 'tag:yaml.org,2002:null':
        var result = _parseNull(scalar);
        if (result != null) return result;
        throw YamlException('Invalid null scalar.', scalar.span);
      case 'tag:yaml.org,2002:bool':
        var result = _parseBool(scalar);
        if (result != null) return result;
        throw YamlException('Invalid bool scalar.', scalar.span);
      case 'tag:yaml.org,2002:int':
        var result = _parseNumber(scalar, allowFloat: false);
        if (result != null) return result;
        throw YamlException('Invalid int scalar.', scalar.span);
      case 'tag:yaml.org,2002:float':
        var result = _parseNumber(scalar, allowInt: false);
        if (result != null) return result;
        throw YamlException('Invalid float scalar.', scalar.span);
      case 'tag:yaml.org,2002:str':
        return YamlScalar.internal(scalar.value, scalar);
      default:
        throw YamlException('Undefined tag: ${scalar.tag}.', scalar.span);
    }
  }

  /// Parses [scalar], which may be one of several types.
  YamlScalar _parseScalar(ScalarEvent scalar) =>
      _tryParseScalar(scalar) ?? YamlScalar.internal(scalar.value, scalar);

  /// Tries to parse [scalar].
  ///
  /// If parsing fails, this returns `null`, indicating that the scalar should
  /// be parsed as a string.
  YamlScalar? _tryParseScalar(ScalarEvent scalar) {
    // Quickly check for the empty string, which means null.
    var length = scalar.value.length;
    if (length == 0) return YamlScalar.internal(null, scalar);

    // Dispatch on the first character.
    var firstChar = scalar.value.codeUnitAt(0);
    return switch (firstChar) {
      $dot || $plus || $minus => _parseNumber(scalar),
      $n || $N => length == 4 ? _parseNull(scalar) : null,
      $t || $T => length == 4 ? _parseBool(scalar) : null,
      $f || $F => length == 5 ? _parseBool(scalar) : null,
      $tilde => length == 1 ? YamlScalar.internal(null, scalar) : null,
      _ => (firstChar >= $0 && firstChar <= $9) ? _parseNumber(scalar) : null
    };
  }

  /// Parse a null scalar.
  ///
  /// Returns a Dart `null` if parsing fails.
  YamlScalar? _parseNull(ScalarEvent scalar) => switch (scalar.value) {
        '' ||
        'null' ||
        'Null' ||
        'NULL' ||
        '~' =>
          YamlScalar.internal(null, scalar),
        _ => null
      };

  /// Parse a boolean scalar.
  ///
  /// Returns `null` if parsing fails.
  YamlScalar? _parseBool(ScalarEvent scalar) => switch (scalar.value) {
        'true' || 'True' || 'TRUE' => YamlScalar.internal(true, scalar),
        'false' || 'False' || 'FALSE' => YamlScalar.internal(false, scalar),
        _ => null
      };

  /// Parses a numeric scalar.
  ///
  /// Returns `null` if parsing fails.
  YamlScalar? _parseNumber(ScalarEvent scalar,
      {bool allowInt = true, bool allowFloat = true}) {
    var value = _parseNumberValue(scalar.value,
        allowInt: allowInt, allowFloat: allowFloat);
    return value == null ? null : YamlScalar.internal(value, scalar);
  }

  /// Parses the value of a number.
  ///
  /// Returns the number if it's parsed successfully, or `null` if it's not.
  num? _parseNumberValue(String contents,
      {bool allowInt = true, bool allowFloat = true}) {
    assert(allowInt || allowFloat);

    var firstChar = contents.codeUnitAt(0);
    var length = contents.length;

    // Quick check for single digit integers.
    if (allowInt && length == 1) {
      var value = firstChar - $0;
      return value >= 0 && value <= 9 ? value : null;
    }

    var secondChar = contents.codeUnitAt(1);

    // Hexadecimal or octal integers.
    if (allowInt && firstChar == $0) {
      // int.tryParse supports 0x natively.
      if (secondChar == $x) return int.tryParse(contents);

      if (secondChar == $o) {
        var afterRadix = contents.substring(2);
        return int.tryParse(afterRadix, radix: 8);
      }
    }

    // Int or float starting with a digit or a +/- sign.
    if ((firstChar >= $0 && firstChar <= $9) ||
        ((firstChar == $plus || firstChar == $minus) &&
            secondChar >= $0 &&
            secondChar <= $9)) {
      // Try to parse an int or, failing that, a double.
      num? result;
      if (allowInt) {
        // Pass "radix: 10" explicitly to ensure that "-0x10", which is valid
        // Dart but invalid YAML, doesn't get parsed.
        result = int.tryParse(contents, radix: 10);
      }

      if (allowFloat) result ??= double.tryParse(contents);
      return result;
    }

    if (!allowFloat) return null;

    // Now the only possibility is to parse a float starting with a dot or a
    // sign and a dot, or the signed/unsigned infinity values and not-a-numbers.
    if ((firstChar == $dot && secondChar >= $0 && secondChar <= $9) ||
        (firstChar == $minus || firstChar == $plus) && secondChar == $dot) {
      // Starting with a . and a number or a sign followed by a dot.
      if (length == 5) {
        switch (contents) {
          case '+.inf':
          case '+.Inf':
          case '+.INF':
            return double.infinity;
          case '-.inf':
          case '-.Inf':
          case '-.INF':
            return -double.infinity;
        }
      }

      return double.tryParse(contents);
    }

    if (length == 4 && firstChar == $dot) {
      switch (contents) {
        case '.inf':
        case '.Inf':
        case '.INF':
          return double.infinity;
        case '.nan':
        case '.NaN':
        case '.NAN':
          return double.nan;
      }
    }

    return null;
  }
}
