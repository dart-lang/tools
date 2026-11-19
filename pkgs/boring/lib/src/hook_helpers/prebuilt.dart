// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'targets.dart'
    show
        prebuiltDirectory,
        prebuiltLibraryPath,
        prebuiltTargets,
        targetTripleFor;

const _checkoutHint =
    'To build boring locally from source instead, set '
    '`buildMode: checkout` in your pubspec.yaml under '
    '`hooks.user_defines.boring`.';

/// The prebuilt library for the target of [input] in the [prebuiltDirectory]
/// of the package.
///
/// `.github/workflows/boring_binaries.yaml` adds the prebuilt libraries to the
/// package that it publishes to pub.dev, so they come with the package instead
/// of being downloaded.
///
/// Throws a [BuildError] if there is no prebuilt library for the target, or if
/// the package doesn't have it, as for a git or path dependency on the
/// repository.
Uri prebuiltLibrary(HookInput input, {required bool static}) {
  final targetOS = input.config.code.targetOS;
  final targetArch = input.config.code.targetArchitecture;
  final iosSdk = targetOS == OS.iOS ? input.config.code.iOS.targetSdk : null;
  final target = targetTripleFor(targetOS, targetArch, iosSdk: iosSdk);

  if (!prebuiltTargets.contains((targetOS, targetArch, iosSdk))) {
    throw BuildError(
      message:
          'No prebuilt boring library is available for $target.\n'
          '$_checkoutHint',
    );
  }

  final path = prebuiltLibraryPath(
    targetOS,
    targetArch,
    iosSdk: iosSdk,
    static: static,
  );
  final library = input.packageRoot.resolve('$prebuiltDirectory/$path');
  if (!File.fromUri(library).existsSync()) {
    throw BuildError(
      message:
          'The prebuilt boring library for $target is missing: '
          '${library.toFilePath()} does not exist. Only the package published '
          'on pub.dev has the prebuilt libraries, a git or path dependency on '
          'its repository does not.\n'
          '$_checkoutHint',
    );
  }

  stdout.writeln('boring: using the prebuilt library ${library.toFilePath()}.');
  return library;
}
