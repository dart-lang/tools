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
  late FileSystem fs;
  late Directory home;
  late FakeAnalytics initializationAnalytics;
  late FakeAnalytics analytics;
  late File sessionFile;
  late File logFile;

  const homeDirName = 'home';
  const initialTool = DashTool.flutterTool;
  const measurementId = 'measurementId';
  const apiSecret = 'apiSecret';
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
    initializationAnalytics = Analytics.test(
      tool: initialTool,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    ) as FakeAnalytics;
    expect(initializationAnalytics.shouldShowMessage, true);
    initializationAnalytics.clientShowedMessage();
    expect(initializationAnalytics.shouldShowMessage, false);

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
    //
    // This instance should have the same parameters as the one above for
    // [initializationAnalytics]
    analytics = Analytics.test(
      tool: initialTool,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
      clientIde: clientIde,
    ) as FakeAnalytics;
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

      final secondAnalytics = Analytics.test(
        tool: initialTool,
        homeDirectory: home,
        measurementId: measurementId,
        apiSecret: apiSecret,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: flutterVersion,
        dartVersion: dartVersion,
        fs: fs,
        platform: platform,
        clientIde: clientIde,
      ) as FakeAnalytics;
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

      final matchingEvents = analytics.sentEvents.where(
          (element) => element.eventName == DashEvent.analyticsException);
      expect(matchingEvents, hasLength(1));

      // Making the file empty again and sending an event should not send
      // an additional event
      sessionFile.writeAsStringSync('');
      expect(sessionFile.readAsStringSync(), isEmpty);
      analytics.send(testEvent);
      expect(sessionFile.readAsStringSync(), isNotEmpty);

      final secondMatchingEvents = analytics.sentEvents.where(
          (element) => element.eventName == DashEvent.analyticsException);
      expect(secondMatchingEvents, hasLength(1),
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
  });

  group('Log handler:', () {
    // TODO: add tests for the log handler
  });
}
