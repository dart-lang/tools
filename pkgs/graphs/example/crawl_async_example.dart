// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;

/// Print a transitive set of imported URIs where libraries are read
/// asynchronously.
Future<Null> main() async {
  var allImports = await crawlAsync(
          [Uri.parse('package:graphs/graphs.dart')], read, findImports)
      .toList();
  print(allImports.map((s) => s.uri).toList());
}

AnalysisContext _analysisContext;

Future<AnalysisContext> get analysisContext async {
  if (_analysisContext == null) {
    var libUri = Uri.parse('package:graphs/');
    var libPath = await getFilePath(libUri);
    var packagePath = p.dirname(libPath);

    var roots = new ContextLocator().locateRoots(includedPaths: [packagePath]);
    if (roots.length != 1) {
      throw new StateError(
          'Expected to find exactly one context root, got $roots');
    }

    _analysisContext =
        new ContextBuilder().createContext(contextRoot: roots[0]);
  }

  return _analysisContext;
}

Future<Iterable<Uri>> findImports(Uri from, Source source) async {
  return source.unit.directives
      .where((d) => d is UriBasedDirective)
      .map((d) => (d as UriBasedDirective).uri.stringValue)
      .where((uri) => !uri.startsWith('dart:'))
      .map((import) => resolveImport(import, from));
}

Future<String> getFilePath(Uri uri) async {
  var fileUri = await Isolate.resolvePackageUri(uri);
  if (!fileUri.isScheme('file')) {
    throw new StateError(
        'Expected to resolve $uri to a file URI, got $fileUri');
  }
  return p.fromUri(fileUri);
}

Future<CompilationUnit> parseFile(Uri uri) async {
  var path = await getFilePath(uri);
  var analysisSession = (await analysisContext).currentSession;
  var parseResult = analysisSession.getParsedAstSync(path);
  return parseResult.unit;
}

Future<Source> read(Uri uri) async => new Source(uri, await parseFile(uri));

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
