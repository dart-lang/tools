// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'package:boring/src/hook_helpers/library.dart';
import 'package:boring/src/hook_helpers/version.dart';
import 'package:prebuilt_code_assets/tools.dart';

/// Writes the SHA-256 hashes of the release assets built by
/// tool/precompile_binaries.dart to lib/src/hook_helpers/hashes.dart.
Future<void> main(List<String> args) async {
  await runRegenerateHashesCli(
    args,
    defaultVersion: releaseVersion,
    releaseConfigForVersion: boringReleaseConfig,
    licenseHeader:
        '// Copyright (c) 2026, the Dart project authors. Please see the '
        'AUTHORS file\n'
        '// for details. All rights reserved. Use of this source code is '
        'governed by a\n'
        '// BSD-style license that can be found in the LICENSE file.\n',
  );
}
