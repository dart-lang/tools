// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  late MemoryFileSystem fs;
  late Directory home;
  late FakeAnalytics initializationAnalytics;
  late FakeAnalytics analytics;
  late File sessionFile;
  late File logFile;

  const homeDirName = 'home';
  const initialTool = DashTool.flutterTool;
  const toolsMessageVersion = 1;
  const toolsMessage = 'toolsMessage';
  const flutterChannel = 'flutterChannel';
  const flutterVersion = 'flutterVersion';
  const dartVersion = 'dartVersion';
  const platform = DevicePlatform.macos;
  const clientIde = 'VSCode';

  final testEvent = Event.codeSizeAnalysis(platform: 'platform');

  setUp(() {
    // Setup the filesystem with the home directory
    final fsStyle =
        io.Platform.isWindows ? FileSystemStyle.windows : FileSystemStyle.posix;
    fs = MemoryFileSystem.test(style: fsStyle);
    home = fs.directory(homeDirName);

    // This is the first analytics instance that will be used to demonstrate
    // that events will not be sent with the first run of analytics
    initializationAnalytics = Analytics.fake(
      tool: initialTool,
      homeDirectory: home,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );
    expect(initializationAnalytics.shouldShowMessage, true);
    initializationAnalytics.clientShowedMessage();
    expect(initializationAnalytics.shouldShowMessage, false);

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
    //
    // This instance should have the same parameters as the one above for
    // [initializationAnalytics]
    analytics = Analytics.fake(
      tool: initialTool,
      homeDirectory: home,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
      clientIde: clientIde,
    );
    analytics.clientShowedMessage();

    // The files that should have been generated that will be used for tests
    sessionFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kSessionFileName);
    logFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kLogFileName);
  });

  group('Session handler:', () {
    test('no error when opted out already and opting in', () async {
      // When we opt out from an analytics instance, we clear the contents of
      // session file, as required by the privacy document. When creating a
      // second instance of [Analytics], it should not detect that the file is
      // empty and recreate it, it should remain opted out and no error event
      // should have been sent
      await analytics.setTelemetry(false);
      expect(analytics.telemetryEnabled, false);
      expect(sessionFile.readAsStringSync(), isEmpty);

      final secondAnalytics = Analytics.fake(
        tool: initialTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: flutterVersion,
        dartVersion: dartVersion,
        fs: fs,
        platform: platform,
        clientIde: clientIde,
      );
      expect(sessionFile.readAsStringSync(), isEmpty);
      expect(secondAnalytics.telemetryEnabled, false);

      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        isEmpty,
      );
      expect(
        secondAnalytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        isEmpty,
      );

      await secondAnalytics.setTelemetry(true);
      expect(sessionFile.readAsStringSync(), isNotEmpty,
          reason: 'Toggling telemetry should bring back the session data');
    });
    test('only sends one event for FormatException', () {
      // Begin with the session file empty, it should recreate the file
      // and send an error event
      sessionFile.writeAsStringSync('');
      expect(sessionFile.readAsStringSync(), isEmpty);
      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);

      analytics.sendPendingErrorEvents();
      expect(
          analytics.sentEvents.where(
              (element) => element.eventName == DashEvent.analyticsException),
          hasLength(1));

      // Making the file empty again and sending an event should not send
      // an additional event
      sessionFile.writeAsStringSync('');
      expect(sessionFile.readAsStringSync(), isEmpty);
      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);

      expect(
          analytics.sentEvents.where(
              (element) => element.eventName == DashEvent.analyticsException),
          hasLength(1),
          reason: 'We should not have added a new error event');
    });

    test('only sends one event for FileSystemException', () {
      // Deleting the session file should cause the file system exception and
      // sending a new event should log the error the first time and recreate
      // the file. If we delete the file again and attempt to send an event,
      // the session file should get recreated without sending a second error.
      sessionFile.deleteSync();
      expect(sessionFile.existsSync(), isFalse);
      analytics.send(testEvent);

      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(1),
      );
      expect(sessionFile.existsSync(), isTrue);
      expect(sessionFile.readAsStringSync(), isNotEmpty);

      // Remove the file again and send an event
      sessionFile.deleteSync();
      expect(sessionFile.existsSync(), isFalse);
      analytics.send(testEvent);

      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(1),
        reason: 'Only the first error event should exist',
      );
      expect(sessionFile.existsSync(), isTrue);
      expect(sessionFile.readAsStringSync(), isNotEmpty);
    });

    test('sends two unique errors', () {
      // Begin with the session file empty, it should recreate the file
      // and send an error event
      sessionFile.writeAsStringSync('');
      expect(sessionFile.readAsStringSync(), isEmpty);
      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);

      analytics.sendPendingErrorEvents();
      expect(
          analytics.sentEvents.where(
              (element) => element.eventName == DashEvent.analyticsException),
          hasLength(1));

      // Deleting the file now before sending an additional event should
      // cause a different test error
      sessionFile.deleteSync();
      expect(sessionFile.existsSync(), isFalse);

      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);
      analytics.sendPendingErrorEvents();
      expect(
          analytics.sentEvents.where(
              (element) => element.eventName == DashEvent.analyticsException),
          hasLength(2));
      expect(analytics.sentEvents, hasLength(4));

      sessionFile.deleteSync();
      expect(sessionFile.existsSync(), isFalse);

      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);
      expect(
          analytics.sentEvents.where(
              (element) => element.eventName == DashEvent.analyticsException),
          hasLength(2));
    });
  });

  group('Log handler:', () {
    test('only sends one event for FormatException', () {
      expect(logFile.existsSync(), isTrue);

      // Write invalid lines to the log file to have a FormatException
      // thrown when trying to parse the log file
      logFile.writeAsStringSync('''
{{}
{{}
''');

      // Send one event so that the logFileStats method returns a valid value
      analytics.send(testEvent);
      expect(analytics.sentEvents, hasLength(1));
      expect(logFile.readAsLinesSync(), hasLength(3));
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        isEmpty,
      );

      // This call below will cause a FormatException while parsing the log file
      final logFileStats = analytics.logFileStats();
      expect(logFileStats, isNotNull);
      expect(logFileStats!.recordCount, 1,
          reason: 'The error event is not counted');
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(1),
      );
      expect(logFile.readAsLinesSync(), hasLength(4));
    });

    test('only sends one event for TypeError', () {
      expect(logFile.existsSync(), isTrue);
      // Write valid json but have one of the types wrong for
      // the keys so that we throw a TypeError while casting the values
      //
      // In the json below, we have made the session id value a string when
      // it should be an integer
      logFile.writeAsStringSync('''
{"client_id":"fcd6c0d5-6582-4c36-b09e-3ecedee9145c","events":[{"name":"command_usage_values","params":{"workflow":"doctor","commandHasTerminal":true}}],"user_properties":{"session_id":{"value":"this should be a string"},"flutter_channel":{"value":"master"},"host":{"value":"macOS"},"flutter_version":{"value":"3.20.0-2.0.pre.9"},"dart_version":{"value":"3.4.0 (build 3.4.0-99.0.dev)"},"analytics_pkg_version":{"value":"5.8.1"},"tool":{"value":"flutter-tool"},"local_time":{"value":"2024-02-07 15:46:19.920784 -0500"},"host_os_version":{"value":"Version 14.3 (Build 23D56)"},"locale":{"value":"en"},"client_ide":{"value":null},"enabled_features":{"value":"enable-native-assets"}}}
''');
      expect(logFile.readAsLinesSync(), hasLength(1));

      // Send the test event so that the LogFileStats object is not null
      analytics.send(testEvent);

      final logFileStats = analytics.logFileStats();
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(1),
      );
      expect(logFileStats, isNotNull);
      expect(logFileStats!.recordCount, 1);
    });

    test('sends two unique errors', () {
      expect(logFile.existsSync(), isTrue);

      // Write invalid lines to the log file to have a FormatException
      // thrown when trying to parse the log file
      logFile.writeAsStringSync('''
{{}
{{}
''');

      // Send one event so that the logFileStats method returns a valid value
      analytics.send(testEvent);
      expect(analytics.sentEvents, hasLength(1));
      expect(logFile.readAsLinesSync(), hasLength(3));
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        isEmpty,
      );

      // This will cause the first error
      analytics.logFileStats();
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(1),
      );

      // Overwrite the contents of the log file now to include something that
      // will cause a TypeError by changing the expected value for session id
      // from integer to a string
      logFile.writeAsStringSync('''
{"client_id":"fcd6c0d5-6582-4c36-b09e-3ecedee9145c","events":[{"name":"command_usage_values","params":{"workflow":"doctor","commandHasTerminal":true}}],"user_properties":{"session_id":{"value":"this should be a string"},"flutter_channel":{"value":"master"},"host":{"value":"macOS"},"flutter_version":{"value":"3.20.0-2.0.pre.9"},"dart_version":{"value":"3.4.0 (build 3.4.0-99.0.dev)"},"analytics_pkg_version":{"value":"5.8.1"},"tool":{"value":"flutter-tool"},"local_time":{"value":"2024-02-07 15:46:19.920784 -0500"},"host_os_version":{"value":"Version 14.3 (Build 23D56)"},"locale":{"value":"en"},"client_ide":{"value":null},"enabled_features":{"value":"enable-native-assets"}}}
''');
      expect(logFile.readAsLinesSync(), hasLength(1));

      // This will cause the second error
      analytics.logFileStats();
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(2),
      );

      // Attempting to cause the same error won't send another error event
      analytics.logFileStats();
      analytics.sendPendingErrorEvents();
      expect(
        analytics.sentEvents.where(
            (element) => element.eventName == DashEvent.analyticsException),
        hasLength(2),
      );
    });
  });
}
