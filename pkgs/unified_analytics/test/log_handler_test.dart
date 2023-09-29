// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  late Analytics analytics;
  late Directory homeDirectory;
  late FileSystem fs;
  late File logFile;

  final testEvent = Event.hotReloadTime(timeMs: 10);

  setUp(() {
    fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
    homeDirectory = fs.directory('home');
    logFile = fs.file(p.join(
      homeDirectory.path,
      kDartToolDirectoryName,
      kLogFileName,
    ));

    // Create the initialization analytics instance to onboard the tool
    final initializationAnalytics = Analytics.test(
      tool: DashTool.flutterTool,
      homeDirectory: homeDirectory,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      dartVersion: 'dartVersion',
      fs: fs,
      platform: DevicePlatform.macos,
    );
    initializationAnalytics.clientShowedMessage();

    // This instance is free to send events since the instance above
    // has confirmed that the client has shown the message
    analytics = Analytics.test(
      tool: DashTool.flutterTool,
      homeDirectory: homeDirectory,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      dartVersion: 'dartVersion',
      fs: fs,
      platform: DevicePlatform.macos,
    );
  });

  test('Ensure that log file is created', () {
    expect(logFile.existsSync(), true);
  });

  test('LogFileStats is null before events are sent', () {
    expect(analytics.logFileStats(), isNull);
  });

  test('LogFileStats returns valid response after sent events', () {
    final countOfEventsToSend = 10;

    for (var i = 0; i < countOfEventsToSend; i++) {
      analytics.send(testEvent);
    }

    expect(analytics.logFileStats(), isNotNull);
    expect(logFile.readAsLinesSync().length, countOfEventsToSend);
    expect(analytics.logFileStats()!.recordCount, countOfEventsToSend);
  });

  test('The only record in the log file is malformed', () {
    // Write invalid json for the only log record
    logFile.writeAsStringSync('{{\n');

    final logFileStats = analytics.logFileStats();
    expect(logFile.readAsLinesSync().length, 1);
    expect(logFileStats, isNull,
        reason: 'Null should be returned since only '
            'one record is in there and it is malformed');
  });

  test('The first record is malformed, but rest are valid', () {
    // Write invalid json for the only log record
    logFile.writeAsStringSync('{{\n');

    final countOfEventsToSend = 10;

    for (var i = 0; i < countOfEventsToSend; i++) {
      analytics.send(testEvent);
    }
    final logFileStats = analytics.logFileStats();

    expect(logFile.readAsLinesSync().length, countOfEventsToSend + 1);
    expect(logFileStats, isNotNull);
    expect(logFileStats!.recordCount, countOfEventsToSend);
  });

  test('Several records are malformed', () {
    final countOfMalformedRecords = 4;
    for (var i = 0; i < countOfMalformedRecords; i++) {
      final currentContents = logFile.readAsStringSync();
      logFile.writeAsStringSync('$currentContents{{\n');
    }

    final countOfEventsToSend = 10;

    for (var i = 0; i < countOfEventsToSend; i++) {
      analytics.send(testEvent);
    }
    final logFileStats = analytics.logFileStats();

    expect(logFile.readAsLinesSync().length,
        countOfEventsToSend + countOfMalformedRecords);
    expect(logFileStats, isNotNull);
    expect(logFileStats!.recordCount, countOfEventsToSend);
  });
}
