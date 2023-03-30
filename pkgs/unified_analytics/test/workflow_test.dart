// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/config_handler.dart';
import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  late FileSystem fs;
  late Directory home;
  late Directory dartToolDirectory;
  late File clientIdFile;
  late File sessionFile;
  late File configFile;
  late File logFile;

  const String homeDirName = 'home';
  const DashTool initialTool = DashTool.flutterTool;
  const DashTool secondTool = DashTool.dartTool;
  const String measurementId = 'measurementId';
  const String apiSecret = 'apiSecret';
  const int toolsMessageVersion = 1;
  const String toolsMessage = 'toolsMessage';
  const String flutterChannel = 'flutterChannel';
  const String flutterVersion = 'flutterVersion';
  const String dartVersion = 'dartVersion';
  const DevicePlatform platform = DevicePlatform.macos;

  setUp(() {
    // Setup the filesystem with the home directory
    final FileSystemStyle fsStyle =
        io.Platform.isWindows ? FileSystemStyle.windows : FileSystemStyle.posix;
    fs = MemoryFileSystem.test(style: fsStyle);
    home = fs.directory(homeDirName);
    dartToolDirectory = home.childDirectory(kDartToolDirectoryName);

    // The 3 files that should have been generated
    clientIdFile = home
        .childDirectory(kDartToolDirectoryName)
        .childFile(kClientIdFileName);
    sessionFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kSessionFileName);
    configFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kConfigFileName);
    logFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kLogFileName);
  });

  test('Confirm workflow for checking tools into the config file', () {
    final Analytics firstAnalytics = Analytics.test(
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
    );

    // Host of assertions to ensure all required artifacts
    // are created
    expect(dartToolDirectory.existsSync(), true,
        reason: 'The directory should have been created');
    expect(clientIdFile.existsSync(), true,
        reason: 'The $kClientIdFileName file was not found');
    expect(sessionFile.existsSync(), true,
        reason: 'The $kSessionFileName file was not found');
    expect(configFile.existsSync(), true,
        reason: 'The $kConfigFileName was not found');
    expect(logFile.existsSync(), true,
        reason: 'The $kLogFileName file was not found');
    expect(dartToolDirectory.listSync().length, equals(4),
        reason:
            'There should only be 4 files in the $kDartToolDirectoryName directory');
    expect(configFile.readAsStringSync(), kConfigString);

    expect(firstAnalytics.shouldShowMessage, true);

    // Attempting to send a message with this instance should be
    // blocked because it has not invoked `clientShowedMessage()`
    // and it is the first run
    //
    // Even after invoking the method, it should be prevented from
    // sending a message because it is the first time the tool was
    // run in this instance
    firstAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 0);
    firstAnalytics.clientShowedMessage();

    // Attempt to send two events, both should be blocked because it is
    // part of the first instance
    firstAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    firstAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 0);

    // Creating a second analytics instance from the same tool now should
    // allow for events to be sent
    final Analytics secondAnalytics = Analytics.test(
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
    );

    expect(secondAnalytics.shouldShowMessage, false);
    secondAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 1,
        reason: 'Events will be blocked until invoking method '
            'ensuring client has seen message');

    secondAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    secondAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 3);

    // Next, we will want to confirm that the message should be showing when
    // a new analytics instance has been created with a newer version for
    // message that should be shown
    //
    // In this case, it should be treated as a new tool being added for the first
    // time and all events should be blocked

    // Delete the log file to reset the counter of events sent
    logFile.deleteSync();
    final Analytics thirdAnalytics = Analytics.test(
      tool: initialTool,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1, // Incrementing version
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );

    expect(logFile.existsSync(), true,
        reason: 'The $kLogFileName file was not found');
    expect(thirdAnalytics.shouldShowMessage, true,
        reason: 'New version number should require showing message');
    thirdAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 0);
    thirdAnalytics.clientShowedMessage();

    // Attempt to send two events, both should be blocked because it is
    // part of the third instance which has a new version for the consent
    // message which will be treated as a new tool being onboarded
    thirdAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    thirdAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 0);

    // The fourth instance of the analytics class with the consent message
    // version incremented should now be able to send messages
    final Analytics fourthAnalytics = Analytics.test(
      tool: initialTool,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1, // Incrementing version
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );

    expect(fourthAnalytics.shouldShowMessage, false);
    fourthAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 1,
        reason: 'Events will be blocked until invoking method '
            'ensuring client has seen message');

    fourthAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    fourthAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    expect(logFile.readAsLinesSync().length, 3);
  });

  test('Disable second instance if first one did not show message', () {
    final Analytics firstAnalytics = Analytics.test(
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
    );

    expect(firstAnalytics.shouldShowMessage, true);

    final Analytics secondAnalytics = Analytics.test(
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
    );

    expect(secondAnalytics.shouldShowMessage, true);

    secondAnalytics.clientShowedMessage();

    final Analytics thirdAnalytics = Analytics.test(
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
    );

    expect(thirdAnalytics.shouldShowMessage, false);
  });

  test('Passing large version number gets logged in config', () {
    final int firstVersion = toolsMessageVersion + 3;
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: flutterChannel,
      toolsMessageVersion: firstVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(
        configFile.readAsStringSync().endsWith(
            '${secondTool.label}=${ConfigHandler.dateStamp},$firstVersion\n'),
        true);

    // Create a new instane of the secondTool with an even
    // bigger version
    final int secondVersion = firstVersion + 3;
    final Analytics thirdAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: flutterChannel,
      toolsMessageVersion: secondVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    expect(
        configFile.readAsStringSync().endsWith(
            '${secondTool.label}=${ConfigHandler.dateStamp},$firstVersion\n'),
        true);

    // After invoking this method, it will get updated
    // in the config with the next version
    thirdAnalytics.clientShowedMessage();

    expect(
        configFile.readAsStringSync().endsWith(
            '${secondTool.label}=${ConfigHandler.dateStamp},$secondVersion\n'),
        true);
  });
}
