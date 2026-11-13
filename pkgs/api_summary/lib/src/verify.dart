// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import '../api_summary.dart';
import 'extensions.dart';

/// Supported serialization formats for [ApiSummary].
enum ApiSummaryFormat {
  /// Human-readable text summary (`api.txt`).
  text('api.txt'),

  /// Pretty-printed JSON summary (`api.json`).
  json('api.json'),

  /// YAML summary (`api.yaml`).
  yaml('api.yaml');

  const ApiSummaryFormat(this.defaultFileName);

  /// The default golden file name for this format in a package root.
  final String defaultFileName;

  /// Formats [summary] according to this format.
  String format(ApiSummary summary) => switch (this) {
    .text => summary.toString(),
    .json =>
      '${const JsonEncoder.withIndent('  ').convert(summary.toJson())}\n',
    .yaml => () {
      final editor = YamlEditor('');
      editor.update([], summary.toJson());
      return '$editor\n';
    }(),
  };
}

/// Exception thrown by [expectApiSummaryClean] when a package's golden API
/// summary file is missing or out of sync with the package's public API.
final class ApiSummaryVerificationException implements Exception {
  /// A human-readable description of the verification failure, including a
  /// line diff and remediation command.
  final String message;

  /// The path to the golden file that was checked.
  final String goldenFilePath;

  /// The expected content read from [goldenFilePath], or `null` if the file
  /// did not exist.
  final String? expected;

  /// The actual summary generated from the package's current source code.
  final String actual;

  ApiSummaryVerificationException({
    required this.message,
    required this.goldenFilePath,
    required this.actual,
    this.expected,
  });

  @override
  String toString() => 'ApiSummaryVerificationException: $message';
}

/// Verifies that the package's generated [ApiSummary] matches the golden file
/// at [goldenFilePath] (defaults to [ApiSummaryFormat.defaultFileName] inside
/// [packagePath]).
///
/// If [packagePath] is omitted, defaults to [Directory.current].
///
/// Throws an [ApiSummaryVerificationException] if the golden file does not
/// exist, if its contents differ from the generated summary, or (unless
/// [ApiSummaryCustomizer.allowNonPublicTypes] is `true`) if public API
/// signatures expose [ApiDeclarationStatus.nonPublic] types or package-owned
/// types referenced by the primary `package:<pkg>/<pkg>.dart` barrel without
/// being exported by it.
///
/// Because all parameters are optional and named, [expectApiSummaryClean] can
/// be passed directly as a tear-off to `test()`:
/// ```dart
/// import 'package:api_summary/api_summary.dart';
/// import 'package:test/scaffolding.dart';
///
/// void main() {
///   test('api_summary', expectApiSummaryClean);
/// }
/// ```
Future<void> expectApiSummaryClean({
  String? goldenFilePath,
  String? packagePath,
  String? packageName,
  ApiSummaryCustomizer? customizer,
  ApiSummaryFormat format = ApiSummaryFormat.text,
}) async {
  final resolvedPackagePath = p.normalize(
    p.absolute(packagePath ?? Directory.current.path),
  );

  final effectiveGoldenPath = goldenFilePath == null
      ? p.join(resolvedPackagePath, format.defaultFileName)
      : (p.isAbsolute(goldenFilePath)
            ? p.normalize(goldenFilePath)
            : p.normalize(p.join(resolvedPackagePath, goldenFilePath)));

  final summary = await apiSummary(
    resolvedPackagePath,
    packageName: packageName,
    customizer: customizer,
  );

  final actualOutput = format.format(summary);
  if (!(customizer?.allowNonPublicTypes ?? false)) {
    if (_findUnexposedTypesError(summary) case final errorMessage?) {
      throw ApiSummaryVerificationException(
        message: errorMessage,
        goldenFilePath: effectiveGoldenPath,
        actual: actualOutput,
      );
    }
  }

  final goldenFile = File(effectiveGoldenPath);

  final displayGoldenPath = p.isWithin(resolvedPackagePath, effectiveGoldenPath)
      ? p.relative(effectiveGoldenPath, from: resolvedPackagePath)
      : effectiveGoldenPath;
  final remediationCommand = _buildRemediationCommand(
    format: format,
    displayGoldenPath: displayGoldenPath,
  );

  if (!goldenFile.existsSync()) {
    throw ApiSummaryVerificationException(
      message:
          'Golden file "$displayGoldenPath" does not exist at '
          '"$effectiveGoldenPath".\n'
          'To generate it, run:\n'
          '  $remediationCommand',
      goldenFilePath: effectiveGoldenPath,
      actual: actualOutput,
    );
  }

  final expectedRaw = goldenFile.readAsStringSync();
  final expectedLines = LineSplitter.split(expectedRaw).toList();
  final actualLines = LineSplitter.split(actualOutput).toList();

  if (!_linesEqual(expectedLines, actualLines)) {
    final diff = _buildLineDiff(expectedLines, actualLines);
    throw ApiSummaryVerificationException(
      message:
          '"$displayGoldenPath" does not match the current public API of '
          'package "${summary.name}".\n\n'
          '$diff\n\n'
          'To update the golden file, run:\n'
          '  $remediationCommand',
      goldenFilePath: effectiveGoldenPath,
      expected: expectedRaw,
      actual: actualOutput,
    );
  }
}

/// Builds the CLI command shown in failure messages to regenerate or update
/// the golden file at [displayGoldenPath].
///
/// Uses `--write` when [displayGoldenPath] matches [format]'s
/// [ApiSummaryFormat.defaultFileName], and `--output=<path>` otherwise.
String _buildRemediationCommand({
  required ApiSummaryFormat format,
  required String displayGoldenPath,
}) => [
  'dart run api_summary',
  if (displayGoldenPath == format.defaultFileName) ...[
    '--write',
    if (format != .text) '--format=${format.name}',
  ] else ...[
    if (format != .text) '--format=${format.name}',
    '--output=$displayGoldenPath',
  ],
].join(' ');

/// Whether [a] and [b] contain identical lines in the same order.
bool _linesEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Formats a compact unified-style diff of the first differing span between
/// [expected] and [actual].
///
/// Strips matching leading and trailing lines, emits a 1-based
/// `@@ line <N> @@` header at the start of the divergence, and lists up to
/// 20 removed (`-`) and 20 added (`+`) lines before summarizing any
/// remaining lines.
String _buildLineDiff(List<String> expected, List<String> actual) {
  var prefix = 0;
  final minLen = expected.length < actual.length
      ? expected.length
      : actual.length;
  while (prefix < minLen && expected[prefix] == actual[prefix]) {
    prefix++;
  }

  var expectedSuffix = expected.length;
  var actualSuffix = actual.length;
  while (expectedSuffix > prefix &&
      actualSuffix > prefix &&
      expected[expectedSuffix - 1] == actual[actualSuffix - 1]) {
    expectedSuffix--;
    actualSuffix--;
  }

  final buffer = StringBuffer();
  buffer.writeln('@@ line ${prefix + 1} @@');

  const maxLinesShown = 20;
  final removedCount = expectedSuffix - prefix;
  for (var i = 0; i < removedCount && i < maxLinesShown; i++) {
    buffer.writeln('- ${expected[prefix + i]}');
  }
  if (removedCount > maxLinesShown) {
    buffer.writeln('... (${removedCount - maxLinesShown} more removed lines)');
  }

  final addedCount = actualSuffix - prefix;
  for (var i = 0; i < addedCount && i < maxLinesShown; i++) {
    buffer.writeln('+ ${actual[prefix + i]}');
  }
  if (addedCount > maxLinesShown) {
    buffer.writeln('... (${addedCount - maxLinesShown} more added lines)');
  }

  return buffer.toString().trimRight();
}

String? _findUnexposedTypesError(ApiSummary summary) {
  final nonPublics = summary.libraries
      .expand(_libraryDeclarations)
      .where((d) => d.status == .nonPublic)
      .toList();
  final nonPublicKeys = nonPublics.map(_declarationKey).toSet();

  final sections = <String>[];
  if (nonPublics.isNotEmpty) {
    final lines = [
      for (final d in nonPublics) '  - ${d.name} (${d.locationUri})',
    ]..sort();
    sections.add(
      'The package exposes the following non-public types in its API '
      'signatures. These types are either from "lib/src/" or unexported '
      'libraries, making them unusable by callers:\n'
      '${lines.join('\n')}\n'
      'Ensure all types used in public signatures are exported by the '
      'package.',
    );
  }

  final primaryLib = summary.libraries.firstWhereOrNull(
    (l) => Uri.parse(l.uri).isPrimaryPublicLibOf(summary.name),
  );
  if (primaryLib != null) {
    final unexportedLines = _findUnexportedPrimaryBarrelLines(
      summary,
      primaryLib,
      nonPublicKeys,
    );
    if (unexportedLines.isNotEmpty) {
      sections.add(
        'The primary barrel "${primaryLib.uri}" exposes package-owned types '
        'in its public API signatures that it does not export. Callers '
        'importing only "${primaryLib.uri}" cannot name these types:\n'
        '${unexportedLines.join('\n')}\n'
        'Export these types from "${primaryLib.uri}" (or opt out via '
        'ApiSummaryCustomizer(allowNonPublicTypes: true)).',
      );
    }
  }

  return sections.isEmpty ? null : sections.join('\n\n');
}

List<String> _findUnexportedPrimaryBarrelLines(
  ApiSummary summary,
  ApiLibrary primaryLib,
  Set<String> excludedKeys,
) {
  final primaryExportedKeys = _libraryDeclarations(
    primaryLib,
  ).map(_declarationKey).toSet();
  final exportingLibraries = _siblingExportingLibraries(
    summary.libraries,
    primaryLib.uri,
  );

  final seenKeys = <String>{};
  final lines = <String>[];
  final referencedTypes = _libraryDeclarations(
    primaryLib,
  ).expand(_declarationTypes).expand(_nestedInterfaceTypes);
  for (final type in referencedTypes) {
    final libraryUri = type.libraryUri;
    if (libraryUri == null || !Uri.parse(libraryUri).isIn(summary.name)) {
      continue;
    }
    final key = '$libraryUri#${type.name}';
    if (primaryExportedKeys.contains(key) ||
        excludedKeys.contains(key) ||
        !seenKeys.add(key)) {
      continue;
    }
    lines.add(
      _formatUnexportedBarrelType(
        type.name,
        libraryUri,
        exportingLibraries[key],
      ),
    );
  }
  return lines..sort();
}

Map<String, List<String>> _siblingExportingLibraries(
  List<ApiLibrary> libraries,
  String primaryUri,
) {
  final result = <String, List<String>>{};
  for (final lib in libraries) {
    if (!lib.isPublicEntryPoint || lib.uri == primaryUri) continue;
    for (final decl in _libraryDeclarations(lib)) {
      (result[_declarationKey(decl)] ??= []).add(lib.uri);
    }
  }
  return result;
}

String _formatUnexportedBarrelType(
  String name,
  String libraryUri,
  List<String>? siblings,
) {
  if (siblings != null &&
      siblings.isNotEmpty &&
      !(siblings.length == 1 && siblings.single == libraryUri)) {
    return '  - $name ($libraryUri, exported by ${siblings.join(', ')})';
  }
  return '  - $name ($libraryUri)';
}

String _declarationKey(ApiDeclaration declaration) =>
    '${declaration.locationUri}#${declaration.name}';

Iterable<ApiDeclaration> _libraryDeclarations(ApiLibrary library) sync* {
  yield* library.classes;
  yield* library.enums;
  yield* library.mixins;
  yield* library.extensions;
  yield* library.extensionTypes;
  yield* library.functions;
  yield* library.typeAliases;
}

Iterable<ApiType> _declarationTypes(ApiDeclaration declaration) sync* {
  switch (declaration) {
    case ApiClass():
      yield* declaration.typeParameters.values.nonNulls;
      if (declaration.supertype case final supertype?) yield supertype;
      yield* declaration.interfaces;
      yield* declaration.mixins;
      yield* declaration.superclassConstraints;
      for (final member in [
        ...declaration.constructors,
        ...declaration.methods,
      ]) {
        yield* _declarationTypes(member);
      }
    case ApiExtension():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.extendedType;
      for (final method in declaration.methods) {
        yield* _declarationTypes(method);
      }
    case ApiExtensionType():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.representationType;
      yield* declaration.interfaces;
      for (final member in [
        ...declaration.constructors,
        ...declaration.methods,
      ]) {
        yield* _declarationTypes(member);
      }
    case ApiExecutable():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.returnType;
      for (final parameter in declaration.parameters) {
        yield parameter.type;
      }
    case ApiTypeAlias():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.aliasedType;
  }
}

Iterable<ApiInterfaceType> _nestedInterfaceTypes(ApiType type) sync* {
  switch (type) {
    case ApiDynamicType() || ApiVoidType() || ApiTypeParameterType():
      return;
    case ApiInterfaceType():
      yield type;
      for (final arg in type.typeArguments) {
        yield* _nestedInterfaceTypes(arg);
      }
    case ApiRecordType():
      for (final field in type.positionalFields) {
        yield* _nestedInterfaceTypes(field);
      }
      for (final field in type.namedFields) {
        yield* _nestedInterfaceTypes(field.type);
      }
    case ApiFunctionType():
      yield* _nestedInterfaceTypes(type.returnType);
      for (final bound in type.typeParameters.values.nonNulls) {
        yield* _nestedInterfaceTypes(bound);
      }
      for (final parameter in type.parameters) {
        yield* _nestedInterfaceTypes(parameter.type);
      }
  }
}
