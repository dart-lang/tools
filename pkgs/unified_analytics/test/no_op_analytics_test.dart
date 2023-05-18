// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  test('NoOpAnalytics.telemetryEnabled is always false', () async {
    final NoOpAnalytics analytics = NoOpAnalytics();

    expect(analytics.telemetryEnabled, isFalse);
    await analytics.setTelemetry(true);
    expect(analytics.telemetryEnabled, isFalse);
  });

  test('NoOpAnalytics.shouldShowMessage is always false', () async {
    final NoOpAnalytics analytics = NoOpAnalytics();

    expect(analytics.shouldShowMessage, isFalse);
    analytics.clientShowedMessage();
    expect(analytics.shouldShowMessage, isFalse);
  });

  test('NoOpAnalytics.sendEvent() always returns null', () async {
    final NoOpAnalytics analytics = NoOpAnalytics();

    await analytics.setTelemetry(true);
    analytics.clientShowedMessage();
    expect(
      analytics.sendEvent(eventName: DashEvent.analyticsCollectionEnabled),
      isNull,
    );
  });

  test('NoOpAnalytics.logFileStats() always returns null', () async {
    final NoOpAnalytics analytics = NoOpAnalytics();

    expect(analytics.logFileStats(), isNull);

    await analytics.setTelemetry(true);
    analytics.clientShowedMessage();
    await analytics.sendEvent(eventName: DashEvent.analyticsCollectionEnabled);

    expect(analytics.logFileStats(), isNull);
  });

  test('Home directory without write permissions', () {
    final FileSystem fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
    final Directory home = fs.directory('home');
    home.createSync();

    expect(home.statSync().modeString(), 'r-xrw-rwx');
    expect(checkDirectoryForWritePermissions(home), false);
  });
}
