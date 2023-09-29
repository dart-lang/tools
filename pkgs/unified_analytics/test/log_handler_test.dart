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

  test('Valid json but invalid keys', () {
    
    // The second line here is missing the "events" top level
    // key which should cause an error for that record only
    final contents = '''
{"client_id":"fe4a035b-bba8-4d4b-a651-ea213e9b8a2c","events":[{"name":"lint_usage_count","params":{"count":1,"name":"prefer_final_fields"}}],"user_properties":{"session_id":{"value":1695147041117},"flutter_channel":{"value":null},"host":{"value":"macOS"},"flutter_version":{"value":"3.14.0-14.0.pre.303"},"dart_version":{"value":"3.2.0-140.0.dev"},"analytics_pkg_version":{"value":"3.1.0"},"tool":{"value":"vscode-plugins"},"local_time":{"value":"2023-09-19 14:44:11.528153 -0400"}}}
{"client_id":"fe4a035b-bba8-4d4b-a651-ea213e9b8a2c","WRONG_EVENT_KEY":[{"name":"lint_usage_count","params":{"count":1,"name":"prefer_for_elements_to_map_fromIterable"}}],"user_properties":{"session_id":{"value":1695147041117},"flutter_channel":{"value":null},"host":{"value":"macOS"},"flutter_version":{"value":"3.14.0-14.0.pre.303"},"dart_version":{"value":"3.2.0-140.0.dev"},"analytics_pkg_version":{"value":"3.1.0"},"tool":{"value":"vscode-plugins"},"local_time":{"value":"2023-09-19 14:44:11.565549 -0400"}}}
{"client_id":"fe4a035b-bba8-4d4b-a651-ea213e9b8a2c","events":[{"name":"lint_usage_count","params":{"count":1,"name":"prefer_function_declarations_over_variables"}}],"user_properties":{"session_id":{"value":1695147041117},"flutter_channel":{"value":null},"host":{"value":"macOS"},"flutter_version":{"value":"3.14.0-14.0.pre.303"},"dart_version":{"value":"3.2.0-140.0.dev"},"analytics_pkg_version":{"value":"3.1.0"},"tool":{"value":"vscode-plugins"},"local_time":{"value":"2023-09-19 14:44:11.589338 -0400"}}}
''';
    logFile.writeAsStringSync(contents);

    final logFileStats = analytics.logFileStats();

    expect(logFile.readAsLinesSync().length, 3);
    expect(logFileStats, isNotNull);
    expect(logFileStats!.recordCount, 2);
  });
}
