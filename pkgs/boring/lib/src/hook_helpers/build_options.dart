// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:hooks/hooks.dart' show HookInputUserDefines;

enum BuildModeEnum { fetch, build, checkout, local }

class BuildOptions {
  final BuildModeEnum buildMode;
  final Uri? localPath;

  BuildOptions({required this.buildMode, this.localPath});

  factory BuildOptions.fromDefines(HookInputUserDefines defines) {
    final modeString = defines['buildMode'] as String? ?? 'fetch';
    return BuildOptions(
      buildMode: BuildModeEnum.values.firstWhere(
        (element) => element.name == modeString,
        orElse: () => BuildModeEnum.fetch,
      ),
      localPath: defines.path('localPath'),
    );
  }

  @override
  String toString() =>
      'BuildOptions(buildMode: $buildMode, localPath: $localPath)';
}
