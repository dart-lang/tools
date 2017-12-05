// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/analyzer.dart' show parseDirectives;
import 'package:analyzer/dart/ast/ast.dart' show UriBasedDirective;
import 'package:resource/resource.dart';
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;

class Source {
  final Uri uri;
  final String content;

  Source(this.uri, this.content);
}

Future<Source> read(Uri uri) async =>
    new Source(uri, await new Resource(uri).readAsString());

Iterable<Uri> findImports(Uri from, Source source) {
  final unit = parseDirectives(source.content);
  return unit.directives
      .where((d) => d is UriBasedDirective)
      .map((d) => (d as UriBasedDirective).uri.stringValue)
      .where((uri) => !uri.startsWith('dart:'))
      .map((import) => resolveImport(import, from));
}

Uri resolveImport(String import, Uri from) {
  if (import.startsWith('package:')) return Uri.parse(import);
  assert(from.scheme == 'package');
  final package = from.pathSegments.first;
  final fromPath = p.joinAll(from.pathSegments.skip(1));
  final path = p.normalize(p.join(p.dirname(fromPath), import));
  return Uri.parse('package:${p.join(package, path)}');
}

/// Print a transitive set of imported URIs where libraries are read
/// asynchronously.
Future<Null> main() async {
  var allImports = await crawlAsync(
          [Uri.parse('package:graphs/graphs.dart')], read, findImports)
      .toList();
  print(allImports.map((s) => s.uri).toList());
}
