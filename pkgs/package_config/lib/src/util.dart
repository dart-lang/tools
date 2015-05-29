// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utility methods used by more than one library in the package.
library package_config.util;

import "package:charcode/ascii.dart";

/// Tests whether something is a valid Dart identifier/package name.
bool isIdentifier(String string) {
  if (string.isEmpty) return false;
  int firstChar = string.codeUnitAt(0);
  int firstCharLower = firstChar | 0x20;
  if (firstCharLower < $a || firstCharLower > $z) {
    if (firstChar != $_ && firstChar != $$) return false;
  }
  for (int i = 1; i < string.length; i++) {
    int char = string.codeUnitAt(i);
    int charLower = char | 0x20;
    if (charLower < $a || charLower > $z) {    // Letters.
      if ((char ^ 0x30) <= 9) continue;        // Digits.
      if (char == $_ || char == $$) continue;  // $ and _
      if (firstChar != $_ && firstChar != $$) return false;
    }
  }
  return true;
}


/// Validate that a Uri is a valid package:URI.
String checkValidPackageUri(Uri packageUri) {
  if (packageUri.scheme != "package") {
    throw new ArgumentError.value(packageUri, "packageUri",
                                  "Not a package: URI");
  }
  if (packageUri.hasAuthority) {
    throw new ArgumentError.value(packageUri, "packageUri",
                                  "Package URIs must not have a host part");
  }
  if (packageUri.hasQuery) {
    // A query makes no sense if resolved to a file: URI.
    throw new ArgumentError.value(packageUri, "packageUri",
                                  "Package URIs must not have a query part");
  }
  if (packageUri.hasFragment) {
    // We could leave the fragment after the URL when resolving,
    // but it would be odd if "package:foo/foo.dart#1" and
    // "package:foo/foo.dart#2" were considered different libraries.
    // Keep the syntax open in case we ever get multiple libraries in one file.
    throw new ArgumentError.value(packageUri, "packageUri",
                                  "Package URIs must not have a fragment part");
  }
  if (packageUri.path.startsWith('/')) {
    throw new ArgumentError.value(packageUri, "packageUri",
                                  "Package URIs must not start with a '/'");
  }
  int firstSlash = packageUri.path.indexOf('/');
  if (firstSlash == -1) {
    throw new ArgumentError.value(packageUri, "packageUri",
        "Package URIs must start with the package name followed by a '/'");
  }
  String packageName = packageUri.path.substring(0, firstSlash);
  if (!isIdentifier(packageName)) {
    throw new ArgumentError.value(packageUri, "packageUri",
        "Package names must be valid identifiers");
  }
  return packageName;
}
