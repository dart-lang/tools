// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unified_analytics/unified_analytics.dart';

final Analytics analytics = Analytics.development(
  tool: DashTool.flutterTool,
  flutterChannel: 'ey-test-channel',
  flutterVersion: 'Flutter 3.29.2',
  clientIde: 'VSCode',
  dartVersion: 'Dart 3.7.2',
);

/// Simple CLI to print the logFileStats to the console.
///
/// Run with: dart run example/log_stats.dart
void main() async {
  print(analytics.logFileStats());
  // Close the client connection on exit.
  await analytics.close();
}
