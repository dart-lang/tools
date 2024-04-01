// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  late MemoryFileSystem fs;
  late Directory home;
  late Analytics initializationAnalytics;
  late Analytics analytics;

  const homeDirName = 'home';
  const initialTool = DashTool.flutterTool;
  const toolsMessageVersion = 1;
  const toolsMessage = 'toolsMessage';
  const flutterChannel = 'flutterChannel';
  const flutterVersion = 'flutterVersion';
  const dartVersion = 'dartVersion';
  const platform = DevicePlatform.macos;

  final testEvent = Event.hotReloadTime(timeMs: 50);

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
    initializationAnalytics.clientShowedMessage();

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
    );
    analytics.clientShowedMessage();
  });

  test('Suppression works as expected', () async {
    analytics.suppressTelemetry();
    analytics.send(testEvent);

    final logFileStats = analytics.logFileStats();

    expect(logFileStats, isNull,
        reason: 'Returns null because no records have been recorded');
  });

  test('Second instance is not suppressed', () async {
    analytics.suppressTelemetry();
    analytics.send(testEvent);

    final logFileStats = analytics.logFileStats();

    expect(logFileStats, isNull,
        reason: 'Returns null because no records have been recorded');

    // The newly created instance will not be suppressed
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
    );

    // Using a new event here to differentiate from the first one
    final newEvent = Event.commandExecuted(count: 2, name: 'commandName');
    secondAnalytics.send(newEvent);

    // Both instances of `Analytics` should now have data retrieved
    // from `LogFileStats()` even though only the second instance
    // was the instance to send an event
    final secondLogFileStats = analytics.logFileStats()!;
    final thirdLogFileStats = secondAnalytics.logFileStats()!;

    // Series of checks for each parameter in logFileStats
    expect(secondLogFileStats.startDateTime, thirdLogFileStats.startDateTime);
    expect(secondLogFileStats.minsFromStartDateTime,
        thirdLogFileStats.minsFromStartDateTime);
    expect(secondLogFileStats.endDateTime, thirdLogFileStats.endDateTime);
    expect(secondLogFileStats.minsFromEndDateTime,
        thirdLogFileStats.minsFromEndDateTime);
    expect(secondLogFileStats.sessionCount, thirdLogFileStats.sessionCount);
    expect(secondLogFileStats.flutterChannelCount,
        thirdLogFileStats.flutterChannelCount);
    expect(secondLogFileStats.toolCount, thirdLogFileStats.toolCount);
    expect(secondLogFileStats.recordCount, thirdLogFileStats.recordCount);
    expect(secondLogFileStats.eventCount, thirdLogFileStats.eventCount);

    // Ensure the correct data is in the object
    expect(secondLogFileStats.eventCount.containsKey(newEvent.eventName.label),
        true);
    expect(secondLogFileStats.eventCount[newEvent.eventName.label], 1);
  });
}
