// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  final testEvent = Event.hotReloadTime(timeMs: 50);

  test('NoOpAnalytics.telemetryEnabled is always false', () async {
    final analytics = const NoOpAnalytics();

    expect(analytics.telemetryEnabled, isFalse);
    await analytics.setTelemetry(true);
    expect(analytics.telemetryEnabled, isFalse);
  });

  test('NoOpAnalytics.shouldShowMessage is always false', () async {
    final analytics = const NoOpAnalytics();

    expect(analytics.shouldShowMessage, isFalse);
    analytics.clientShowedMessage();
    expect(analytics.shouldShowMessage, isFalse);
  });

  test('NoOpAnalytics.sendEvent() always returns null', () async {
    final analytics = const NoOpAnalytics();

    await analytics.setTelemetry(true);
    analytics.clientShowedMessage();
    expect(
      analytics.send(testEvent),
      isNull,
    );
  });

  test('NoOpAnalytics.logFileStats() always returns null', () async {
    final analytics = const NoOpAnalytics();

    expect(analytics.logFileStats(), isNull);

    await analytics.setTelemetry(true);
    analytics.clientShowedMessage();
    await analytics.send(testEvent);

    expect(analytics.logFileStats(), isNull);
  });

  test('Home directory without write permissions', () {
    final home = FakeDirectory(writeEnabled: false);

    expect(checkDirectoryForWritePermissions(home), false);
  });

  test('Home directory with write permissions', () {
    final home = FakeDirectory(writeEnabled: true);

    expect(checkDirectoryForWritePermissions(home), true);
  });

  test('Fetching the client id', () {
    final analytics = const NoOpAnalytics();
    expect(analytics.clientId, 'xxxx-xxxx');
  });
}

class FakeDirectory extends Fake implements Directory {
  final String _fakeModeString;

  /// This fake directory class allows you to pass the permissions for
  /// the user level, the group and global permissions will default to
  /// being denied as indicated by the last 6 characters in the mode string.
  FakeDirectory({
    required bool writeEnabled,
    bool readEnabled = true,
    bool executeEnabled = true,
  }) : _fakeModeString = '${readEnabled ? "r" : "-"}'
            '${writeEnabled ? "w" : "-"}'
            '${executeEnabled ? "x" : "-"}'
            '------' {
    assert(_fakeModeString.length == 9);
  }

  @override
  bool existsSync() => true;

  @override
  FileStat statSync() => FakeFileStat(_fakeModeString);
}

class FakeFileStat extends Fake implements FileStat {
  final String _fakeModeString;

  FakeFileStat(this._fakeModeString);

  @override
  String modeString() => _fakeModeString;
}
