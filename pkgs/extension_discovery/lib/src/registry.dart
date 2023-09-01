// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileSystemEntityType, IOException;

import 'expect_json.dart';
import 'io.dart';

/// Entry in the `.dart_tool/extension_discovery/<package>.json` file.
///
/// If the [rootUri] is not an absolute path, then we will assume that the
/// package is mutable (either it's the root package or a path dependency).
/// If there is no extension config file for a mutable package, then we will
/// still store a [RegistryEntry] with `config = null`. Because everytime we
/// load the registry, we still need to check if a configuration file has been
/// added to the mutable package.
typedef RegistryEntry = ({
  String package,
  Uri rootUri,
  Uri packageUri,
  Map<String, Object?>? config,
});

typedef Registry = List<RegistryEntry>;

Future<Registry?> loadRegistry(File registryFile) async {
  try {
    final registryJson = decodeJsonMap(await registryFile.readAsString());
    if (registryJson.expectNumber('version') != 2) {
      throw FormatException('"version" must be 2');
    }
    return registryJson
        .expectListObjects('entries')
        .map((e) => (
              package: e.expectString('package'),
              rootUri: e.expectUri('rootUri'),
              packageUri: e.expectUri('packageUri'),
              config: e.optionalMap('config'),
            ))
        .toList(growable: false);
  } on IOException {
    return null; // pass
  } on FormatException {
    await registryFile.tryDelete();
    return null;
  }
}

Future<void> saveRegistry(
  File registryFile,
  Registry registry,
) async {
  try {
    if (!registryFile.parent.existsSync()) {
      await registryFile.parent.create();
    }
    final tmpFile = File('${registryFile.path}.tmp');
    final tmpFileStat = tmpFile.statSync();
    if (tmpFileStat.type != FileSystemEntityType.notFound) {
      final tmpAge = DateTime.now().difference(tmpFileStat.modified);
      if (tmpAge.inSeconds < 5) {
        // Don't try to write registry, if there is an abandoned temporary file
        // no older than 5 seconds. Otherwise, we could have race conditions!
        // Note: That saving the registry is a performance improvement, not a
        //       strict necessity!
        return;
      } else {
        await tmpFile.delete();
      }
    }

    await tmpFile.writeAsString(jsonEncode({
      'version': 2,
      'entries': registry
          .map((e) => {
                'package': e.package,
                'rootUri': e.rootUri.toString(),
                'packageUri': e.packageUri.toString(),
                if (e.config != null) 'config': e.config,
              })
          .toList(),
    }));
    await tmpFile.reliablyRename(registryFile.path);
    await _ensureReadme(
      File.fromUri(registryFile.parent.uri.resolve('README.md')),
    );
  } on IOException {
    // pass
  }
}

Future<void> _ensureReadme(File readmeFile) async {
  try {
    final stat = readmeFile.statSync();
    if (stat.type != FileSystemEntityType.notFound) {
      final age = DateTime.now().difference(stat.modified);
      if (age.inDays < 5) {
        return; // don't update README.md, if it's less than 5 days old
      }
    }
    await readmeFile.writeAsString(_readmeContents);
  } on IOException {
    // pass
  }
}

const _readmeContents = '''
Extension Discovery Cache
=========================

This folder is used by `package:extension_discovery` to cache lists of
packages that contains extensions for other packages.

DO NOT USE THIS FOLDER
----------------------

 * Do not read (or rely) the contents of this folder.
 * Do write to this folder.

If you're interested in the lists of extensions stored in this folder use the
API offered by package `extension_discovery` to get this information.

If this package doesn't work for your use-case, then don't try to read the
contents of this folder. It may change, and will not remain stable.

Use package `extension_discovery`
---------------------------------

If you want to access information from this folder.

Feel free to delete this folder
-------------------------------

Files in this folder act as a cache, and the cache is discarded if the files
are older than the modification time of `.dart_tool/package_config.json`.

Hence, it should never be necessary to clear this cache manually, if you find a
need to do please file a bug.
''';
