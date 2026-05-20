// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math show min;

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

/// A tool to extract declared docregions from specified source files.
///
/// Caches all docregions parsed from files, so consider
/// creating a new one for each file you're injecting in to.
final class ExcerptExtractor {
  /// A cache of file paths to to the regions found within them.
  ///
  /// If the value a pile path points to is `null`,
  /// the file couldn't be found or read.
  final Map<String, Map<String, Region>?> _regionCacheByPath = {};

  /// Extract the region with the specified [regionName] from
  /// the file located at the specified [path].
  ///
  /// If a file does not exist at that location or the [regionName]
  /// does not exist either, a `ExtractException` will be thrown.
  @useResult
  Future<Region> extractRegion(String path, String regionName) async {
    if (!_regionCacheByPath.containsKey(path)) {
      _regionCacheByPath[path] = await _extractAllRegions(path);
    }
    final regions = _regionCacheByPath[path];
    if (regions == null) {
      throw ExtractException('No file exists at $path.');
    }

    final region = regions[regionName];
    if (region == null) {
      throw ExtractException(
        'The region "$regionName" does not exist in the file at $path.',
      );
    }

    return region;
  }

  @useResult
  Future<Map<String, Region>?> _extractAllRegions(String path) async {
    final file = File(path);
    if (!(await file.exists())) {
      return null;
    }

    final content = await file.readAsString();
    if (content.isEmpty) {
      return const {};
    }

    final sourceFile = SourceFile.fromString(content, url: Uri.file(path));
    final lines = const LineSplitter().convert(content);

    final dialect = _LanguageDialect.fromPath(path);
    var state = _ScannerState.code;
    String? currentStringDelimiter;
    (String, String)? currentBlockCommentDelimiter;

    final regionContent = <String, Region>{_entireFileRegionName: Region._()};
    final currentRegions = <String>{_entireFileRegionName};

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      final line = lines[lineIndex];
      final trimmedLine = line.trimLeft();
      final indent = line.length - trimmedLine.length;

      final lineStart = sourceFile.getOffset(lineIndex);
      final lineEnd = lineStart + line.length;
      final lineSpan = sourceFile.span(lineStart, lineEnd);

      final (
        nextState,
        nextStringDelim,
        nextBlockCommentDelim,
        isDirective,
        match,
      ) = _scanLine(
        line,
        dialect,
        state,
        currentStringDelimiter,
        currentBlockCommentDelimiter,
      );

      state = nextState;
      currentStringDelimiter = nextStringDelim;
      currentBlockCommentDelimiter = nextBlockCommentDelim;

      if (isDirective && match != null) {
        final isEnd = match.namedGroup('end') != null;
        final rawRegionNames = match.namedGroup('regions');
        if (rawRegionNames == null) {
          throw ExtractException(
            'A docregion comment must specify at least one region!',
            lineSpan,
          );
        }
        final regionNames = dialect.cleanRegions(rawRegionNames).split(',');
        for (final rawRegionName in regionNames) {
          final regionName = rawRegionName.trim();
          if (regionName.isEmpty) {
            throw ExtractException(
              'docregion comment tried to use an empty region name.',
              lineSpan,
            );
          }
          if (isEnd) {
            final removed = currentRegions.remove(regionName);
            if (!removed) {
              throw ExtractException(
                'enddocregion tried to close the '
                "unopened '$regionName' region!",
                lineSpan,
              );
            }
          } else {
            if (regionContent[regionName] case final region?) {
              // If the region already exists, add a plaster line.
              region._addPlaster(indent);
            } else {
              regionContent[regionName] = Region._();
            }

            currentRegions.add(regionName);
          }
        }
      } else {
        // Just a normal line.
        for (final region in currentRegions) {
          regionContent[region]!._addLine(line, indent);
        }
      }
    }

    currentRegions.remove(_entireFileRegionName);
    if (currentRegions.isNotEmpty) {
      throw ExtractException(
        'Regions $currentRegions were not closed.',
        sourceFile.span(content.length),
      );
    }

    return regionContent;
  }
}

(
  _ScannerState nextState,
  String? nextStringDelimiter,
  (String, String)? nextBlockCommentDelimiter,
  bool isDirective,
  RegExpMatch? match,
)
_scanLine(
  String line,
  _LanguageDialect dialect,
  _ScannerState state,
  String? currentStringDelimiter,
  (String, String)? currentBlockCommentDelimiter,
) {
  if (state == _ScannerState.lineComment) {
    state = _ScannerState.code;
  }

  final match = _docRegionDirective.firstMatch(line);
  var isDirective = false;

  var i = 0;
  final len = line.length;
  while (i < len) {
    if (match != null && i == match.start) {
      if (state == _ScannerState.lineComment ||
          state == _ScannerState.blockComment) {
        isDirective = true;
      }
    }

    if (state == _ScannerState.code) {
      (String, String)? matchedBlock;
      for (final block in dialect.blockComments) {
        if (line.startsWith(block.$1, i)) {
          matchedBlock = block;
          break;
        }
      }
      if (matchedBlock != null) {
        state = _ScannerState.blockComment;
        currentBlockCommentDelimiter = matchedBlock;
        i += matchedBlock.$1.length;
        continue;
      }

      String? matchedLineComment;
      for (final prefix in dialect.lineComments) {
        if (line.startsWith(prefix, i)) {
          matchedLineComment = prefix;
          break;
        }
      }
      if (matchedLineComment != null) {
        state = _ScannerState.lineComment;
        if (match != null && match.start >= i) {
          isDirective = true;
        }
        break;
      }

      String? matchedStringDelim;
      for (final delim in dialect.stringDelimiters) {
        if (line.startsWith(delim, i)) {
          matchedStringDelim = delim;
          break;
        }
      }
      if (matchedStringDelim != null) {
        state = _ScannerState.string;
        currentStringDelimiter = matchedStringDelim;
        i += matchedStringDelim.length;
        continue;
      }

      i++;
    } else if (state == _ScannerState.string) {
      if (line.startsWith(r'\', i) && i + 1 < len) {
        i += 2;
        continue;
      }
      if (line.startsWith(currentStringDelimiter!, i)) {
        state = _ScannerState.code;
        i += currentStringDelimiter.length;
        currentStringDelimiter = null;
      } else {
        i++;
      }
    } else if (state == _ScannerState.blockComment) {
      final endToken = currentBlockCommentDelimiter!.$2;
      if (line.startsWith(endToken, i)) {
        state = _ScannerState.code;
        i += endToken.length;
        currentBlockCommentDelimiter = null;
      } else {
        i++;
      }
    }
  }

  return (
    state,
    currentStringDelimiter,
    currentBlockCommentDelimiter,
    isDirective,
    match,
  );
}

/// The contents of a docregion found in a file.
final class Region {
  /// The untransformed text lines or plaster lines of the docregion.
  final List<_RegionLine> _lines = [];

  /// The minimum indent seen in this region.
  ///
  /// `99999` is the initial value as no line should be longer than that...
  int _minIndent = 99999;

  /// Creates a [Region] with the specified indentation,
  /// usually from the docregion comment.
  Region._();

  /// Adds the specified [line] with the specified [indent]
  /// to the contents of the region.
  void _addLine(String line, int indent) {
    _lines.add(_StringLine(line));

    // Ignore the indent of blank lines.
    if (line.trim().isNotEmpty) {
      _minIndent = math.min(_minIndent, indent);
    }
  }

  /// Adds a line where a plaster could be inserted
  /// as well as the [directiveIndent] of the directive adding it.
  ///
  /// This is usually when a docregion is closed and opened again.
  void _addPlaster(int directiveIndent) {
    _lines.add(_PlasterLine(directiveIndent));
  }

  /// Builds a list of strings from the region,
  /// replacing lines marked as plasters with the
  /// specified [plaster] content,
  /// and applying the minimum indentation to each line.
  ///
  /// If [plaster] is `null` or `'none'`,
  /// the plaster lines are not included at all.
  @useResult
  Iterable<String> linesWithPlaster(final String? plaster) {
    final updatedLines = <String>[];
    final includePlaster = plaster != null && plaster != 'none';

    for (final line in _lines) {
      switch (line) {
        case _PlasterLine(:final directiveIndent):
          if (includePlaster) {
            final minimizedDirectiveIndent = directiveIndent - _minIndent;
            updatedLines.add('${' ' * minimizedDirectiveIndent}$plaster');
          }
        case _StringLine(:final line):
          if (_minIndent == 0 || line.length < _minIndent) {
            updatedLines.add(line);
          } else {
            updatedLines.add(line.substring(_minIndent));
          }
      }
    }

    return updatedLines;
  }
}

sealed class _RegionLine {}

final class _StringLine extends _RegionLine {
  final String line;

  _StringLine(this.line);
}

final class _PlasterLine extends _RegionLine {
  final int directiveIndent;

  _PlasterLine(this.directiveIndent);
}

/// An exception thrown when a [ExcerptExtractor]
/// failed to extract a region.
final class ExtractException extends SourceSpanException {
  /// Create a [ExtractException] with the specified [message] and [span].
  ExtractException(super.message, [super.span]);
}

const String _entireFileRegionName = '';

final RegExp _docRegionDirective = RegExp(
  r'#(?<end>end)?docregion\s+(?<regions>[a-zA-Z0-9,_\-\s]+)',
);

enum _ScannerState { code, string, lineComment, blockComment }

enum _LanguageDialect {
  cStyle(
    extensions: {
      'dart',
      'js',
      'ts',
      'go',
      'java',
      'kt',
      'swift',
      'c',
      'cpp',
      'cs',
    },
    lineComments: ['//'],
    blockComments: [('/*', '*/')],
    stringDelimiters: ["'''", '"""', "'", '"'],
  ),
  pythonStyle(
    extensions: {'py'},
    lineComments: ['#'],
    blockComments: [],
    stringDelimiters: ["'''", '"""', "'", '"'],
  ),
  hashStyle(
    extensions: {'yaml', 'yml'},
    lineComments: ['#'],
    blockComments: [],
    stringDelimiters: ["'", '"'],
  ),
  htmlStyle(
    extensions: {'html', 'xml'},
    lineComments: [],
    blockComments: [('<!--', '-->')],
    stringDelimiters: ["'", '"'],
  ),
  cssStyle(
    extensions: {'css'},
    lineComments: [],
    blockComments: [('/*', '*/')],
    stringDelimiters: [],
  ),
  fallback(
    extensions: {},
    lineComments: ['//', '#'],
    blockComments: [('/*', '*/'), ('<!--', '-->')],
    stringDelimiters: ["'''", '"""', "'", '"'],
  );

  final Set<String> extensions;
  final List<String> lineComments;
  final List<(String, String)> blockComments;
  final List<String> stringDelimiters;

  const _LanguageDialect({
    required this.extensions,
    required this.lineComments,
    required this.blockComments,
    required this.stringDelimiters,
  });

  String cleanRegions(String raw) {
    switch (this) {
      case _LanguageDialect.htmlStyle:
        // HTML block comments end in '-->'. Since dashes are allowed inside
        // region names, the greedy regex matching group catches the trailing
        // dashes from the comment closing delimiter (e.g. 'html-region --').
        // We strip them off to recover the actual region name.
        var cleaned = raw.trimRight();
        while (cleaned.endsWith('-')) {
          cleaned = cleaned.substring(0, cleaned.length - 1).trimRight();
        }
        return cleaned;
      default:
        return raw.trimRight();
    }
  }

  factory _LanguageDialect.fromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    for (final dialect in _LanguageDialect.values) {
      if (dialect.extensions.contains(ext)) {
        return dialect;
      }
    }
    return fallback;
  }
}
