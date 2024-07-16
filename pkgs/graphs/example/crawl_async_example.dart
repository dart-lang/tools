// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

/// Print a transitive set of imported URIs where libraries are read
/// asynchronously.
Future<void> main() async {
  // Limits calls to [findImports].
  final pool = Pool(10);
  final allImports = await crawlAsync<Uri, Source>(
    [Uri.parse('package:graphs/graphs.dart')],
    read,
    (from, source) => pool.withResource(() => findImports(from, source)),
  ).toList();
  print(allImports.map((s) => s.uri).toList());
}

AnalysisContextCollection? _analysisContextCollection;

Future<AnalysisContextCollection> get analysisContextCollection async {
  var collection = _analysisContextCollection;
  if (collection == null) {
    final libUri = Uri.parse('package:graphs/');
    final libPath = await pathForUri(libUri);
    final packagePath = p.dirname(libPath);

    collection = _analysisContextCollection = AnalysisContextCollection(
      includedPaths: [packagePath],
    );
  }

  return collection;
}

Future<Iterable<Uri>> findImports(Uri from, Source source) async =>
    source.unit.directives
        .whereType<UriBasedDirective>()
        .map((d) => d.uri.stringValue!)
        .where((uri) => !uri.startsWith('dart:'))
        .map((import) => resolveImport(import, from));

Future<CompilationUnit> parseUri(Uri uri) async {
  final path = await pathForUri(uri);
  final analysisContext = (await analysisContextCollection).contexts.single;
  final analysisSession = analysisContext.currentSession;
  final parseResult = analysisSession.getParsedUnit(path);
  return (parseResult as ParsedUnitResult).unit;
}

Future<String> pathForUri(Uri uri) async {
  final fileUri = await Isolate.resolvePackageUri(uri);
  if (fileUri == null || !fileUri.isScheme('file')) {
    throw StateError('Expected to resolve $uri to a file URI, got $fileUri');
  }
  return p.fromUri(fileUri);
}

Future<Source> read(Uri uri) async => Source(uri, await parseUri(uri));

Uri resolveImport(String import, Uri from) {
  if (import.startsWith('package:')) return Uri.parse(import);
  assert(from.scheme == 'package');
  final package = from.pathSegments.first;
  final fromPath = p.joinAll(from.pathSegments.skip(1));
  final path = p.normalize(p.join(p.dirname(fromPath), import));
  return Uri.parse('package:${p.join(package, path)}');
}

class Source {
  final Uri uri;
  final CompilationUnit unit;

  Source(this.uri, this.unit);
}
