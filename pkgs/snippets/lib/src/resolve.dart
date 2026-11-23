// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Turning `example/hello.dart` into a file on disk.
///
/// The rules are dartdoc's, deliberately: a package that uses both
/// `{@example}` in doc comments and this tool in its markdown should not have
/// to remember two different ways of writing the same path.
///
/// * a **leading `/`** is relative to the package root,
/// * anything else is relative to the directory of the referring file,
/// * the reference is a URI reference, so `..` is clamped and `%20` works,
/// * a scheme or an authority is an error,
/// * resolving outside the package root is an error.
library;

import 'package:path/path.dart' as p;

import 'diagnostic.dart';

/// Resolves [reference] against [documentPath] within [packageRoot], and
/// returns an absolute path.
///
/// Throws [ExampleFormatException] if the reference is not a relative path
/// inside the package. Whether the file *exists* is not checked here; the
/// caller reports that with the line number of the reference.
String resolveReference({
  required String packageRoot,
  required String documentPath,
  required String reference,
  void Function(String message)? onWarning,
}) {
  final uri = Uri.tryParse(reference);
  if (uri == null) {
    throw ExampleFormatException('`$reference` is not a valid path');
  }
  if (uri.hasScheme) {
    throw ExampleFormatException(
      'a reference cannot have a scheme; `$reference` must be a path to a '
      'file in this package',
    );
  }
  if (uri.hasAuthority) {
    throw ExampleFormatException(
      'a reference cannot have an authority; `$reference` must be a path to '
      'a file in this package',
    );
  }
  if (uri.path.isEmpty) {
    throw ExampleFormatException('`$reference` names no file');
  }

  final root = p.normalize(p.absolute(packageRoot));
  final document = p.normalize(p.absolute(documentPath));

  // Resolve inside a rooted, package-relative URI space rather than on the
  // real filesystem: `/` then means the package root, and `..` runs out of
  // path at the root instead of escaping into the user's home directory.
  final directory = p.relative(p.dirname(document), from: root);
  final dirSegments = directory == '.' ? const <String>[] : p.split(directory);
  final base = dirSegments.isEmpty
      ? Uri(path: '/')
      : Uri(pathSegments: ['', ...dirSegments, '']);
  final cleanUri = uri.removeFragment();
  final resolved = base.resolveUri(cleanUri);

  if (onWarning != null &&
      _climbsAboveRoot(cleanUri.path, dirSegments.length)) {
    onWarning(
      '`$reference` climbs above the root directory; '
      'resolved as `${resolved.path}`',
    );
  }

  final relative = p.fromUri(resolved.path.substring(1));
  final path = p.normalize(p.join(root, relative));
  if (path != root && !p.isWithin(root, path)) {
    throw ExampleFormatException(
      '`$reference` resolves outside the package',
    );
  }
  return path;
}

bool _climbsAboveRoot(String uriPath, int startDepth) {
  var depth = uriPath.startsWith('/') ? 0 : startDepth;
  for (final segment in uriPath.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (depth == 0) return true;
      depth--;
    } else {
      depth++;
    }
  }
  return false;
}
