// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/utils.dart';
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

  test('LogFileStats returns valid response after sent events', () async {
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

  test('The first record is malformed, but rest are valid', () async {
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

  test('Several records are malformed', () async {
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
    //
    // Important to note that this won't actually cause a FormatException
    // like the other malformed records, instead the LogItem.fromRecord
    // constructor will return null if all the keys are not available
    final contents = '''
{"client_id":"ffcea97b-db5e-4c66-98c2-3942de4fac40","events":[{"name":"hot_reload_time","params":{"timeMs":136}}],"user_properties":{"session_id":{"value":1699385899950},"flutter_channel":{"value":"ey-test-channel"},"host":{"value":"macOS"},"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},"dart_version":{"value":"Dart 2.19.0"},"analytics_pkg_version":{"value":"5.2.0"},"tool":{"value":"flutter-tool"},"local_time":{"value":"2023-11-07 15:37:26.685761 -0500"},"host_os_version":{"value":"Version 14.1 (Build 23B74)"},"locale":{"value":"en"},"client_ide":{"value":"VSCode"}}}
{"client_id":"ffcea97b-db5e-4c66-98c2-3942de4fac40","WRONG_EVENT_KEY":[{"name":"hot_reload_time","params":{"timeMs":136}}],"user_properties":{"session_id":{"value":1699385899950},"flutter_channel":{"value":"ey-test-channel"},"host":{"value":"macOS"},"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},"dart_version":{"value":"Dart 2.19.0"},"analytics_pkg_version":{"value":"5.2.0"},"tool":{"value":"flutter-tool"},"local_time":{"value":"2023-11-07 15:37:26.685761 -0500"},"host_os_version":{"value":"Version 14.1 (Build 23B74)"},"locale":{"value":"en"},"client_ide":{"value":"VSCode"}}}
{"client_id":"ffcea97b-db5e-4c66-98c2-3942de4fac40","events":[{"name":"hot_reload_time","params":{"timeMs":136}}],"user_properties":{"session_id":{"value":1699385899950},"flutter_channel":{"value":"ey-test-channel"},"host":{"value":"macOS"},"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},"dart_version":{"value":"Dart 2.19.0"},"analytics_pkg_version":{"value":"5.2.0"},"tool":{"value":"flutter-tool"},"local_time":{"value":"2023-11-07 15:37:26.685761 -0500"},"host_os_version":{"value":"Version 14.1 (Build 23B74)"},"locale":{"value":"en"},"client_ide":{"value":"VSCode"}}}
''';
    logFile.writeAsStringSync(contents);

    final logFileStats = analytics.logFileStats();

    expect(logFile.readAsLinesSync().length, 3);
    expect(logFileStats, isNotNull);
    expect(logFileStats!.recordCount, 2);
  });

  test('Malformed record gets phased out after several events', () async {
    // Write invalid json for the only log record
    logFile.writeAsStringSync('{{\n');

    // Send the max number of events minus one so that we have
    // one malformed record on top of the logs and the rest
    // are valid log records
    for (var i = 0; i < kLogFileLength - 1; i++) {
      analytics.send(testEvent);
    }
    final logFileStats = analytics.logFileStats();
    expect(logFile.readAsLinesSync().length, kLogFileLength);
    expect(logFileStats, isNotNull);
    expect(logFileStats!.recordCount, kLogFileLength - 1,
        reason: 'The first record should be malformed');
    expect(logFile.readAsLinesSync()[0].trim(), '{{');

    // Sending one more event should flush out the malformed record
    analytics.send(testEvent);

    final secondLogFileStats = analytics.logFileStats();
    expect(secondLogFileStats, isNotNull);
    expect(secondLogFileStats!.recordCount, kLogFileLength);
    expect(logFile.readAsLinesSync()[0].trim(), isNot('{{'));
  });

  test('Catching cast errors for each log record silently', () async {
    // Write a json array to the log file which will cause
    // a cast error when parsing each line
    logFile.writeAsStringSync('[{}, 1, 2, 3]\n');

    final logFileStats = analytics.logFileStats();
    expect(logFileStats, isNull);

    // Ensure it will work as expected after writing correct logs
    final countOfEventsToSend = 10;
    for (var i = 0; i < countOfEventsToSend; i++) {
      analytics.send(testEvent);
    }
    final secondLogFileStats = analytics.logFileStats();

    expect(secondLogFileStats, isNotNull);
    expect(secondLogFileStats!.recordCount, countOfEventsToSend);
  });

  test(
      'truncateStringToLength returns same string when '
      'max length greater than string length', () {
    final testString = 'Version 14.1 (Build 23B74)';
    final maxLength = 100;

    expect(testString.length < maxLength, true);

    String runTruncateString() => truncateStringToLength(testString, maxLength);

    expect(runTruncateString, returnsNormally);

    final newString = runTruncateString();
    expect(newString, testString);
  });

  test(
      'truncateStringToLength returns truncated string when '
      'max length less than string length', () {
    final testString = 'Version 14.1 (Build 23B74)';
    final maxLength = 10;

    expect(testString.length > maxLength, true);

    String runTruncateString() => truncateStringToLength(testString, maxLength);

    expect(runTruncateString, returnsNormally);

    final newString = runTruncateString();
    expect(newString.length, maxLength);
    expect(newString, 'Version 14');
  });

  test('truncateStringToLength handle errors for invalid max length', () {
    final testString = 'Version 14.1 (Build 23B74)';
    var maxLength = 0;
    String runTruncateString() => truncateStringToLength(testString, maxLength);

    expect(runTruncateString, throwsArgumentError);

    maxLength = -1;
    expect(runTruncateString, throwsArgumentError);
  });

  test('truncateStringToLength same string when max length is the same', () {
    final testString = 'Version 14.1 (Build 23B74)';
    final maxLength = testString.length;

    String runTruncateString() => truncateStringToLength(testString, maxLength);
    expect(runTruncateString, returnsNormally);

    final newString = runTruncateString();
    expect(newString.length, maxLength);
    expect(newString, testString);
  });
}
