// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: lines_longer_than_80_chars, avoid_dynamic_calls

import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';
import 'package:yaml/yaml.dart';

void main() {
  late MemoryFileSystem fs;
  late Directory home;
  late Directory dartToolDirectory;
  late Analytics initializationAnalytics;
  late FakeAnalytics analytics;
  late File clientIdFile;
  late File sessionFile;
  late File configFile;
  late File logFile;
  late File dismissedSurveyFile;

  const homeDirName = 'home';
  const initialTool = DashTool.flutterTool;
  const secondTool = DashTool.dartTool;
  const toolsMessageVersion = 1;
  const toolsMessage = 'toolsMessage';
  const flutterChannel = 'flutterChannel';
  const flutterVersion = 'flutterVersion';
  const dartVersion = 'dartVersion';
  const platform = DevicePlatform.macos;
  const clientIde = 'VSCode';

  final testEvent = Event.hotReloadTime(timeMs: 50);

  setUp(() {
    // Setup the filesystem with the home directory
    final fsStyle =
        io.Platform.isWindows ? FileSystemStyle.windows : FileSystemStyle.posix;
    fs = MemoryFileSystem.test(style: fsStyle);
    home = fs.directory(homeDirName);
    dartToolDirectory = home.childDirectory(kDartToolDirectoryName);

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

    // The 5 files that should have been generated
    clientIdFile = home
        .childDirectory(kDartToolDirectoryName)
        .childFile(kClientIdFileName);
    sessionFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kSessionFileName);
    configFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kConfigFileName);
    logFile =
        home.childDirectory(kDartToolDirectoryName).childFile(kLogFileName);
    dismissedSurveyFile = home
        .childDirectory(kDartToolDirectoryName)
        .childFile(kDismissedSurveyFileName);
  });

  test('Initializer properly sets up on first run', () {
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
    expect(dismissedSurveyFile.existsSync(), true,
        reason: 'The $dismissedSurveyFile file was not found');
    expect(dartToolDirectory.listSync().length, equals(5),
        reason:
            'There should only be 5 files in the $kDartToolDirectoryName directory');
    expect(configFile.readAsLinesSync().length,
        kConfigString.split('\n').length + 1,
        reason: 'The number of lines should equal lines in constant value + 1 '
            'for the initialized tool');
  });

  test('Resetting session file when data is malformed', () {
    // Purposefully write content to the session file that
    // can't be decoded as an integer
    sessionFile.writeAsStringSync('contents');

    // Define the initial time to start
    final start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      final timestamp = clock.now().millisecondsSinceEpoch.toString();
      expect(sessionFile.readAsStringSync(), 'contents');
      analytics.userProperty.preparePayload();
      expect(sessionFile.readAsStringSync(),
          '{"session_id": $timestamp, "last_ping": $timestamp}');

      analytics.sendPendingErrorEvents();

      // Attempting to fetch the session id when malformed should also
      // send an error event while parsing
      final lastEvent = analytics.sentEvents.last;
      expect(lastEvent, isNotNull);
      expect(lastEvent.eventName, DashEvent.analyticsException);
      expect(
          lastEvent.eventData['workflow']!, 'UserProperty._refreshSessionData');
      expect(lastEvent.eventData['error']!, 'FormatException');
    });
  });

  test('Handles malformed session file on startup', () {
    // Ensure that we are able to send an error message on startup if
    // we encounter an error while parsing the contents of the session file
    // for session data
    sessionFile.writeAsStringSync('not a valid session id');

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

    // Invoking a send command should reset the session file to a good state
    //
    // Having it reformat the session file before any send event happens will just
    // add additional work on startup
    analytics.send(testEvent);

    analytics.sendPendingErrorEvents();
    final errorEvent = analytics.sentEvents
        .where((element) => element.eventName == DashEvent.analyticsException)
        .firstOrNull;
    expect(errorEvent, isNotNull);
    expect(
        errorEvent!.eventData['workflow'], 'UserProperty._refreshSessionData');
    expect(errorEvent.eventData['error'], 'FormatException');
    expect(errorEvent.eventData['description'],
        'message: Unexpected character\nsource: not a valid session id');
  });

  test('Resetting session file when file is removed', () {
    // Purposefully write delete the file
    sessionFile.deleteSync();

    // Define the initial time to start
    final start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      final timestamp = clock.now().millisecondsSinceEpoch.toString();
      expect(sessionFile.existsSync(), false);
      analytics.userProperty.preparePayload();
      expect(sessionFile.readAsStringSync(),
          '{"session_id": $timestamp, "last_ping": $timestamp}');

      analytics.sendPendingErrorEvents();

      // Attempting to fetch the session id when malformed should also
      // send an error event while parsing
      final lastEvent = analytics.sentEvents.last;
      expect(lastEvent, isNotNull);
      expect(lastEvent.eventName, DashEvent.analyticsException);
      expect(
          lastEvent.eventData['workflow']!, 'UserProperty._refreshSessionData');
      expect(lastEvent.eventData['error']!, 'FileSystemException');
    });
  });

  test('New tool is successfully added to config file', () {
    // Create a new instance of the analytics class with the new tool
    final secondAnalytics = Analytics.fake(
      tool: secondTool,
      homeDirectory: home,
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(secondAnalytics.parsedTools.length, equals(2),
        reason: 'There should be only 2 tools that have '
            'been parsed into the config file');
    expect(secondAnalytics.parsedTools.containsKey(initialTool.label), true,
        reason: 'The first tool: ${initialTool.label} should be in the map');
    expect(secondAnalytics.parsedTools.containsKey(secondTool.label), true,
        reason: 'The second tool: $secondAnalytics should be in the map');
    expect(configFile.readAsStringSync().startsWith(kConfigString), true,
        reason:
            'The config file should have the same message from the constants file');
  });

  test('First time analytics run will not send events, second time will', () {
    // Send an event with the first analytics class; this should result
    // in no logs in the log file which keeps track of all the events
    // that have been sent
    initializationAnalytics.send(testEvent);
    initializationAnalytics.send(testEvent);

    // Use the second instance of analytics defined in setUp() to send the actual
    // events to simulate the second time the tool ran
    analytics.send(testEvent);

    expect(logFile.readAsLinesSync().length, 1,
        reason: 'The second analytics instance should have logged an event');
  });

  test('Toggling telemetry boolean through Analytics class api', () async {
    final originalClientId = clientIdFile.readAsStringSync();

    expect(analytics.telemetryEnabled, true,
        reason: 'Telemetry should be enabled by default '
            'when initialized for the first time');
    // Use the API to disable analytics
    expect(logFile.readAsLinesSync().length, 0);
    await analytics.setTelemetry(false);
    expect(analytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled');
    expect(logFile.readAsLinesSync().length, 0,
        reason: 'Log file should have been cleared after opting out');
    expect(clientIdFile.readAsStringSync().length, 0,
        reason: 'CLIENT ID file gets cleared on opt out');
    expect(sessionFile.readAsStringSync().length, 0,
        reason: 'Session file gets cleared on opt out');

    // Toggle it back to being enabled
    await analytics.setTelemetry(true);
    expect(analytics.telemetryEnabled, true,
        reason: 'Analytics telemetry should be enabled');
    expect(logFile.readAsLinesSync().length, 1,
        reason: 'There should only one event since it was cleared on opt out');
    expect(clientIdFile.readAsStringSync().length, greaterThan(0),
        reason: 'CLIENT ID file gets regenerated on opt in');
    expect(sessionFile.readAsStringSync().length, greaterThan(0),
        reason: 'Session file gets regenerated on opt in');

    // Extract the last log item to check for the keys
    final lastLogItem =
        jsonDecode(logFile.readAsLinesSync().last) as Map<String, Object?>;
    expect((lastLogItem['events'] as List).last['name'],
        'analytics_collection_enabled',
        reason: 'Check on event name');
    expect((lastLogItem['events'] as List).last['params']['status'], true,
        reason: 'Status should be false');
    expect((lastLogItem['client_id'] as String).isNotEmpty, true);
    expect(originalClientId != lastLogItem['client_id'], true,
        reason: 'When opting in again, the client id should be regenerated');
  });

  test('Confirm client id is not empty string after opting in', () async {
    await analytics.setTelemetry(false);
    expect(logFile.readAsLinesSync().length, 0,
        reason: 'Log file should have been cleared after opting out');
    expect(clientIdFile.readAsStringSync().length, 0,
        reason: 'CLIENT ID file gets cleared on opt out');

    // Start up a second instance to simulate starting another
    // command being run
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

    // Setting telemetry back on will emit a new event
    // where the client id string should not be empty
    await secondAnalytics.setTelemetry(true);
    expect(analytics.telemetryEnabled, true,
        reason: 'Analytics telemetry should be enabled');
    expect(logFile.readAsLinesSync().length, 1,
        reason: 'There should only one event since it was cleared on opt out');
    expect(clientIdFile.readAsStringSync().length, greaterThan(0),
        reason: 'CLIENT ID file gets regenerated on opt in');

    // Extract the last log item to check for the keys
    final lastLogItem =
        jsonDecode(logFile.readAsLinesSync().last) as Map<String, Object?>;
    expect((lastLogItem['client_id'] as String).isNotEmpty, true,
        reason: 'The client id should have been regenerated and '
            'emitted in the opt in event');
  });

  test(
      'Telemetry has been disabled by one '
      'tool and second tool correctly shows telemetry is disabled', () async {
    expect(analytics.telemetryEnabled, true,
        reason: 'Analytics telemetry should be enabled on initialization');
    // Use the API to disable analytics
    await analytics.setTelemetry(false);
    expect(analytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled');

    // Initialize a second analytics class, which simulates a second tool
    // Create a new instance of the analytics class with the new tool
    final secondAnalytics = Analytics.fake(
      tool: secondTool,
      homeDirectory: home,
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(secondAnalytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled by the first class '
            'and the second class should show telemetry is disabled');
  });

  test(
      'Two concurrent instances are running '
      'and reflect an accurate up to date telemetry status', () async {
    // Initialize a second analytics class, which simulates a second tool
    final secondAnalytics = Analytics.fake(
      tool: secondTool,
      homeDirectory: home,
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(analytics.telemetryEnabled, true,
        reason: 'Telemetry should be enabled on initialization for '
            'first analytics instance');
    expect(secondAnalytics.telemetryEnabled, true,
        reason: 'Telemetry should be enabled on initialization for '
            'second analytics instance');

    // Use the API to disable analytics on the first instance
    await analytics.setTelemetry(false);
    expect(analytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled on first instance');

    expect(secondAnalytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled by the first class '
            'and the second class should show telemetry is disabled'
            ' by checking the timestamp on the config file');
  });

  test('New line character is added if missing', () {
    String currentConfigFileString;

    expect(configFile.readAsStringSync().endsWith('\n'), true,
        reason: 'When initialized, the tool should correctly '
            'add a trailing new line character');

    // Remove the trailing new line character before initializing a second
    // analytics class; the new class should correctly format the config file
    currentConfigFileString = configFile.readAsStringSync();
    currentConfigFileString = currentConfigFileString.substring(
        0, currentConfigFileString.length - 1);

    // Write back out to the config file to be processed again
    configFile.writeAsStringSync(currentConfigFileString);

    expect(configFile.readAsStringSync().endsWith('\n'), false,
        reason: 'The trailing new line should be missing');

    // Initialize a second analytics class, which simulates a second tool
    // which should correct the missing trailing new line character
    final secondAnalytics = Analytics.fake(
      tool: secondTool,
      homeDirectory: home,
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(secondAnalytics.telemetryEnabled, true);

    expect(configFile.readAsStringSync().endsWith('\n'), true,
        reason: 'The second analytics class will correct '
            'the missing new line character');
  });

  test('Incrementing the version for a tool is successful', () {
    expect(analytics.parsedTools[initialTool.label]?.versionNumber,
        toolsMessageVersion,
        reason: 'On initialization, the first version number should '
            'be what is set in the setup method');

    // Initialize a second analytics class for the same tool as
    // the first analytics instance except with a newer version for
    // the tools message and version
    final secondAnalytics = Analytics.fake(
      tool: initialTool,
      homeDirectory: home,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );
    expect(secondAnalytics.shouldShowMessage, true);
    expect(secondAnalytics.okToSend, false);
    secondAnalytics.clientShowedMessage();
    expect(secondAnalytics.shouldShowMessage, false);
    expect(secondAnalytics.okToSend, false,
        reason: 'New version for the message will be treated as a first run');

    expect(secondAnalytics.parsedTools[initialTool.label]?.versionNumber,
        toolsMessageVersion + 1,
        reason:
            'The second analytics instance should have incremented the version');
  });

  test(
      'Config file resets when there is not exactly one match for the reporting flag',
      () async {
    // Write to the config file a string that is not formatted correctly
    // (ie. there is more than one match for the reporting flag)
    configFile.writeAsStringSync('''
# INTRODUCTION
#
# This is the Flutter and Dart telemetry reporting
# configuration file.
#
# Lines starting with a #" are documentation that
# the tools maintain automatically.
#
# All other lines are configuration lines. They have
# the form "name=value". If multiple lines contain
# the same configuration name with different values,
# the parser will default to a conservative value. 

# DISABLING TELEMETRY REPORTING
#
# To disable telemetry reporting, set "reporting" to
# the value "0" and to enable, set to "1":
reporting=1
reporting=1

# NOTIFICATIONS
#
# Each tool records when it last informed the user about
# analytics reporting and the privacy policy.
#
# The following tools have so far read this file:
#
#   dart-tools (Dart CLI developer tool)
#   devtools (DevTools debugging and performance tools)
#   flutter-tools (Flutter CLI developer tool)
#
# For each one, the file may contain a configuration line
# where the name is the code in the list above, e.g. "dart-tool",
# and the value is a date in the form YYYY-MM-DD, a comma, and
# a number representing the version of the message that was
# displayed.''');

    // Disable telemetry which should result in a reset of the config file
    await analytics.setTelemetry(false);

    expect(configFile.readAsStringSync().startsWith(kConfigString), true,
        reason: 'The tool should have reset the config file '
            'because it was not formatted correctly');
  });

  test('Config file resets when there is not exactly one match for the tool',
      () {
    // Write to the config file a string that is not formatted correctly
    // (ie. there is more than one match for the reporting flag)
    configFile.writeAsStringSync('''
# INTRODUCTION
#
# This is the Flutter and Dart telemetry reporting
# configuration file.
#
# Lines starting with a #" are documentation that
# the tools maintain automatically.
#
# All other lines are configuration lines. They have
# the form "name=value". If multiple lines contain
# the same configuration name with different values,
# the parser will default to a conservative value. 

# DISABLING TELEMETRY REPORTING
#
# To disable telemetry reporting, set "reporting" to
# the value "0" and to enable, set to "1":
reporting=1

# NOTIFICATIONS
#
# Each tool records when it last informed the user about
# analytics reporting and the privacy policy.
#
# The following tools have so far read this file:
#
#   dart-tools (Dart CLI developer tool)
#   devtools (DevTools debugging and performance tools)
#   flutter-tools (Flutter CLI developer tool)
#
# For each one, the file may contain a configuration line
# where the name is the code in the list above, e.g. "dart-tool",
# and the value is a date in the form YYYY-MM-DD, a comma, and
# a number representing the version of the message that was
# displayed.
${initialTool.label}=$dateStamp,$toolsMessageVersion
${initialTool.label}=$dateStamp,$toolsMessageVersion
''');

    // Initialize a second analytics class for the same tool as
    // the first analytics instance except with a newer version for
    // the tools message and version
    //
    // This second instance should reset the config file when it goes
    // to increment the version in the file
    final secondAnalytics = Analytics.fake(
      tool: initialTool,
      homeDirectory: home,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );
    secondAnalytics.clientShowedMessage();

    expect(
      configFile.readAsStringSync(),
      kConfigString,
      reason: 'The config file should have been reset completely '
          'due to a malformed file that contained two lines for the same tool',
    );

    // Creating a third instance after the second instance
    // has reset the config file should include the newly added
    // tool again with its incremented version number
    final thirdAnalytics = Analytics.fake(
      tool: initialTool,
      homeDirectory: home,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );
    thirdAnalytics.clientShowedMessage();

    expect(
      configFile.readAsStringSync().endsWith(
          '# displayed.\n${initialTool.label}=$dateStamp,${toolsMessageVersion + 1}\n'),
      true,
      reason: 'The config file ends with the correctly formatted ending '
          'after removing the duplicate lines for a given tool',
    );
    expect(
      thirdAnalytics.parsedTools[initialTool.label]?.versionNumber,
      toolsMessageVersion + 1,
      reason: 'The new version should have been incremented',
    );
  });

  test('Check that UserProperty class has all the necessary keys', () {
    const userPropertyKeys = <String>[
      'session_id',
      'flutter_channel',
      'host',
      'flutter_version',
      'dart_version',
      'analytics_pkg_version',
      'tool',
      'local_time',
      'host_os_version',
      'locale',
      'client_ide',
      'enabled_features',
    ];
    expect(analytics.userPropertyMap.keys.length, userPropertyKeys.length,
        reason: 'There should only be ${userPropertyKeys.length} keys');
    for (final key in userPropertyKeys) {
      expect(analytics.userPropertyMap.keys.contains(key), true,
          reason: 'The $key variable is required');
    }
  });

  test('The minimum session duration should be at least 30 minutes', () {
    expect(kSessionDurationMinutes < 30, false,
        reason: 'Session is less than 30 minutes');
  });

  test(
      'The session id stays the same when duration'
      ' is less than the constraint', () {
    // For this test, we will need control clock time so we will delete
    // the [dartToolDirectory] and all of its contents and reconstruct a
    // new [Analytics] instance at a specific time
    dartToolDirectory.deleteSync(recursive: true);
    expect(dartToolDirectory.existsSync(), false,
        reason: 'The directory should have been cleared');

    // Define the initial time to start
    final start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      // This class will be constructed at a fixed time
      final secondAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      secondAnalytics.clientShowedMessage();

      expect(secondAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch);
      expect(sessionFile.lastModifiedSync().millisecondsSinceEpoch,
          start.millisecondsSinceEpoch);
    });

    // Add time to the start time that is less than the duration
    final end = start.add(const Duration(minutes: kSessionDurationMinutes - 1));

    // Use a new clock to ensure that the session id didn't change
    withClock(Clock.fixed(end), () {
      // A new instance will need to be created since the second
      // instance in the previous block is scoped - this new instance
      // should not reset the files generated by the second instance
      final thirdAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      thirdAnalytics.clientShowedMessage();

      // Calling the send event method will result in the session file
      // getting updated but because we use the `Analytics.fake()` constructor
      // no events will be sent
      thirdAnalytics.send(testEvent);

      expect(thirdAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch,
          reason: 'The session id should not have changed since it was made '
              'within the duration');
      expect(sessionFile.lastModifiedSync().millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          reason: 'The last modified value should have been updated');
    });
  });

  test('The session id is refreshed once event is sent after duration', () {
    // For this test, we will need control clock time so we will delete
    // the [dartToolDirectory] and all of its contents and reconstruct a
    // new [Analytics] instance at a specific time
    dartToolDirectory.deleteSync(recursive: true);
    expect(dartToolDirectory.existsSync(), false,
        reason: 'The directory should have been cleared');

    // Define the initial time to start
    final start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      // This class will be constructed at a fixed time
      final secondAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      secondAnalytics.clientShowedMessage();

      expect(secondAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch);
      expect(sessionFile.lastModifiedSync().millisecondsSinceEpoch,
          start.millisecondsSinceEpoch);

      secondAnalytics.send(testEvent);
      expect(sessionFile.readAsStringSync(),
          '{"session_id": ${start.millisecondsSinceEpoch}, "last_ping": ${start.millisecondsSinceEpoch}}');
    });

    // Add time to the start time that is less than the duration
    final end = start.add(const Duration(minutes: kSessionDurationMinutes + 1));

    // Use a new clock to ensure that the session id didn't change
    withClock(Clock.fixed(end), () {
      // A new instance will need to be created since the second
      // instance in the previous block is scoped - this new instance
      // should not reset the files generated by the second instance
      final thirdAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      thirdAnalytics.clientShowedMessage();

      // Calling the send event method will result in the session file
      // getting updated but because we use the `Analytics.fake()` constructor
      // no events will be sent
      thirdAnalytics.send(testEvent);

      expect(thirdAnalytics.userPropertyMap['session_id']?['value'],
          end.millisecondsSinceEpoch,
          reason: 'The session id should have changed since it was made '
              'outside the duration');
      expect(sessionFile.lastModifiedSync().millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          reason: 'The last modified value should have been updated');
      expect(sessionFile.readAsStringSync(),
          '{"session_id": ${end.millisecondsSinceEpoch}, "last_ping": ${end.millisecondsSinceEpoch}}');
    });
  });

  test('Validate the available enum types for DevicePlatform', () {
    expect(DevicePlatform.values.length, 3,
        reason: 'There should only be 3 supported device platforms');
    expect(DevicePlatform.values.contains(DevicePlatform.windows), true);
    expect(DevicePlatform.values.contains(DevicePlatform.macos), true);
    expect(DevicePlatform.values.contains(DevicePlatform.linux), true);
  });

  test('Validate the request body', () {
    // Sample map for event data
    final eventData = <String, dynamic>{
      'time': 5,
      'command': 'run',
    };

    final Map<String, dynamic> body = generateRequestBody(
      clientId: Uuid().generateV4(),
      eventName: DashEvent.hotReloadTime,
      eventData: eventData,
      userProperty: analytics.userProperty,
    );

    // Checks for the top level keys
    expect(body.containsKey('client_id'), true,
        reason: '"client_id" is required at the top level');
    expect(body.containsKey('events'), true,
        reason: '"events" is required at the top level');
    expect(body.containsKey('user_properties'), true,
        reason: '"user_properties" is required at the top level');

    // Regex for the client id
    final clientIdPattern = RegExp(
        r'^[0-9a-z]{8}\-[0-9a-z]{4}\-[0-9a-z]{4}\-[0-9a-z]{4}\-[0-9a-z]{12}$');

    // Checks for the top level values
    expect(body['client_id'].runtimeType, String,
        reason: 'The client id must be a string');
    expect(clientIdPattern.hasMatch(body['client_id'] as String), true,
        reason: 'The client id is not properly formatted, ie '
            '46cc0ba6-f604-4fd9-aa2f-8a20beb24cd4');
    expect(
        (body['events'][0] as Map<String, dynamic>).containsKey('name'), true,
        reason: 'Each event in the events array needs a name');
    expect(
        (body['events'][0] as Map<String, dynamic>).containsKey('params'), true,
        reason: 'Each event in the events array needs a params key');
  });

  test('Check that log file is correctly persisting events sent', () {
    final int numberOfEvents = max((kLogFileLength * 0.1).floor(), 5);

    for (var i = 0; i < numberOfEvents; i++) {
      analytics.send(testEvent);
    }

    expect(logFile.readAsLinesSync().length, numberOfEvents,
        reason: 'The number of events should be $numberOfEvents');

    // Add the max number of events to confirm it does not exceed the max
    for (var i = 0; i < kLogFileLength; i++) {
      analytics.send(testEvent);
    }

    expect(logFile.readAsLinesSync().length, kLogFileLength,
        reason: 'The number of events should be capped at $kLogFileLength');
  });

  test('Check the query on the log file works as expected', () {
    // Define a new clock so that we can check the output of the
    // log file stats method explicitly
    final start = DateTime(1995, 3, 3, 12, 0);
    final firstClock = Clock.fixed(start);

    // Run with the simulated clock for the initial events
    withClock(firstClock, () {
      expect(analytics.logFileStats(), isNull,
          reason: 'The result for the log file stats should be null when '
              'there are no logs');
      analytics.send(testEvent);

      final firstQuery = analytics.logFileStats()!;
      expect(firstQuery.sessionCount, 1,
          reason:
              'There should only be one session after the initial send event');
      expect(firstQuery.flutterChannelCount, {'flutterChannel': 1},
          reason: 'There should only be one flutter channel logged');
      expect(firstQuery.toolCount, {'flutter-tool': 1},
          reason: 'There should only be one tool logged');
    });

    // Define a new clock that is outside of the session duration
    final secondClock =
        start.add(const Duration(minutes: kSessionDurationMinutes + 1));

    // Use the new clock to send an event that will change the session identifier
    withClock(Clock.fixed(secondClock), () {
      analytics.send(testEvent);

      final secondQuery = analytics.logFileStats()!;

      // Construct the expected response for the second query
      expect(secondQuery.startDateTime, DateTime(1995, 3, 3, 12, 0));
      expect(secondQuery.minsFromStartDateTime, 31);
      expect(secondQuery.endDateTime, DateTime(1995, 3, 3, 12, 31));
      expect(secondQuery.minsFromEndDateTime, 0);
      expect(secondQuery.sessionCount, 2);
      expect(secondQuery.flutterChannelCount, {'flutterChannel': 2});
      expect(secondQuery.toolCount, {'flutter-tool': 2});
      expect(secondQuery.recordCount, 2);
      expect(secondQuery.eventCount, {'hot_reload_time': 2});
    });
  });

  test('Check that the log file shows two different tools being used', () {
    // Use a for loop two initialize the second analytics instance
    // twice to account for no events being sent on the first instance
    // run for a given tool
    Analytics? secondAnalytics;
    for (var i = 0; i < 2; i++) {
      secondAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      secondAnalytics.clientShowedMessage();
    }

    // Send events with both instances of the classes
    analytics.send(testEvent);
    secondAnalytics!.send(testEvent);

    // Query the log file stats to verify that there are two tools
    final query = analytics.logFileStats()!;

    expect(query.toolCount, {'flutter-tool': 1, 'dart-tool': 1},
        reason: 'There should have been two tools in the persisted logs');
  });

  test('Check that log data missing some keys results in null for stats', () {
    // The following string represents a log item that is malformed (missing the `tool` key)
    const malformedLog = '{"client_id":"d40133a0-7ea6-4347-b668-ffae94bb8774",'
        '"events":[{"name":"hot_reload_time","params":{"time_ns":345}}],'
        '"user_properties":{'
        '"session_id":{"value":1675193534342},'
        '"flutter_channel":{"value":"ey-test-channel"},'
        '"host":{"value":"macOS"},'
        '"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},'
        '"dart_version":{"value":"Dart 2.19.0"},'
        // '"tool":{"value":"flutter-tools"},'  NEEDS REMAIN REMOVED
        '"local_time":{"value":"2023-01-31 14:32:14.592898 -0500"}}}';

    logFile.writeAsStringSync(malformedLog);
    final query = analytics.logFileStats();

    expect(query, isNull,
        reason:
            'The query should be null because `tool` is missing under `user_properties`');
  });

  test('Malformed local_time string should result in null for stats', () {
    // The following string represents a log item that is malformed (missing the `tool` key)
    const malformedLog = '{"client_id":"d40133a0-7ea6-4347-b668-ffae94bb8774",'
        '"events":[{"name":"hot_reload_time","params":{"time_ns":345}}],'
        '"user_properties":{'
        '"session_id":{"value":1675193534342},'
        '"flutter_channel":{"value":"ey-test-channel"},'
        '"host":{"value":"macOS"},'
        '"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},'
        '"dart_version":{"value":"Dart 2.19.0"},'
        '"tool":{"value":"flutter-tools"},'
        '"local_time":{"value":"2023-xx-31 14:32:14.592898 -0500"}}}'; // PURPOSEFULLY MALFORMED

    logFile.writeAsStringSync(malformedLog);
    final query = analytics.logFileStats();

    expect(query, isNull,
        reason:
            'The query should be null because the `local_time` value is malformed');
  });

  test('Version is the same in the change log, pubspec, and constants.dart',
      () {
    // Parse the contents of the pubspec.yaml
    final pubspecYamlString = io.File('pubspec.yaml').readAsStringSync();

    // Parse into a yaml document to extract the version number
    final doc = loadYaml(pubspecYamlString) as YamlMap;
    final version = doc['version'] as String;

    expect(version, kPackageVersion,
        reason: 'The package version in the pubspec and '
            'constants.dart need to match\n'
            'Pubspec: $version && constants.dart: $kPackageVersion\n\n'
            'Make sure both are the same');

    // Parse the contents of the change log file
    final changeLogFirstLineString =
        io.File('CHANGELOG.md').readAsLinesSync().first;
    expect(changeLogFirstLineString.substring(3), kPackageVersion,
        reason: 'The CHANGELOG.md file needs the first line to '
            'be the same version as the pubspec and constants.dart');
  });

  test('Null values for flutter parameters is reflected properly in log file',
      () {
    // Because we are using the `MemoryFileSystem.test` constructor,
    // we don't have a real clock in the filesystem, and because we
    // are checking the last modified timestamp for the session file
    // to determine if we need to update the session id, manually setting
    // that timestamp will ensure we are not updating session id when it
    // first gets created
    sessionFile.setLastModifiedSync(DateTime.now());

    // Use a for loop two initialize the second analytics instance
    // twice to account for no events being sent on the first instance
    // run for a given tool
    Analytics? secondAnalytics;
    for (var i = 0; i < 2; i++) {
      secondAnalytics = Analytics.fake(
        tool: secondTool,
        homeDirectory: home,
        // flutterChannel: flutterChannel,  THIS NEEDS TO REMAIN REMOVED
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );
      secondAnalytics.clientShowedMessage();
    }

    // Send an event and check that the query stats reflects what is expected
    secondAnalytics!.send(testEvent);

    // Query the log file stats to verify that there are two tools
    final query = analytics.logFileStats()!;

    expect(query.toolCount, {'dart-tool': 1},
        reason: 'There should have only been on tool that sent events');
    expect(query.flutterChannelCount.isEmpty, true,
        reason:
            'The instance does not have flutter information so it should be 0');

    // Sending a query with the first analytics instance which has flutter information
    // available should reflect in the query that there is 1 flutter channel present
    analytics.send(testEvent);
    final query2 = analytics.logFileStats()!;

    expect(query2.toolCount, {'dart-tool': 1, 'flutter-tool': 1},
        reason: 'Two different analytics instances have '
            'been initialized and sent events');
    expect(query2.sessionCount, query.sessionCount,
        reason: 'The session should have remained the same');
    expect(query2.flutterChannelCount, {'flutterChannel': 1},
        reason: 'The first instance has flutter information initialized');
  });

  group('Testing against Google Analytics limitations:', () {
    // Link to limitations documentation
    // https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag#limitations
    //
    // Only the limitations specified below have been added, the other
    // are not able to be validated because it will vary by each tool
    //
    // 1. Events can have a maximum of 25 user properties
    // 2. User property names must be 24 characters or fewer
    // 3. (Only for `tool` name) User property values must be 36 characters or fewer
    // 4. Event names must be 40 characters or fewer, may only contain alpha-numeric
    //    characters and underscores, and must start with an alphabetic character
    test('max 25 user properties per event', () {
      final Map<String, Object> userPropPayload =
          analytics.userProperty.preparePayload();
      const maxUserPropKeys = 25;

      expect(userPropPayload.keys.length < maxUserPropKeys, true,
          reason: 'There are too many keys in the UserProperty payload');
    });

    test('max 24 characters for user prop keys', () {
      final Map<String, Object> userPropPayload =
          analytics.userProperty.preparePayload();
      const maxUserPropLength = 24;

      var userPropLengthValid = true;
      final invalidUserProps = <String>[];
      for (final key in userPropPayload.keys) {
        if (key.length > maxUserPropLength) {
          userPropLengthValid = false;
          invalidUserProps.add(key);
        }
      }
      expect(userPropLengthValid, true,
          reason:
              'The max length for each user prop is $maxUserPropLength chars\n'
              'The below keys are too long:\n$invalidUserProps');
    });

    test('max 36 characters for user prop values (only `tool` key)', () {
      // Checks item 3
      // All tools must be under 36 characters (and enforce each tool
      // begins with a letter)
      final toolLabelPattern = RegExp(r'^[a-zA-Z][a-zA-Z\_-]{0,35}$');
      var toolLengthValid = true;
      final invalidTools = <DashTool>[];
      for (final tool in DashTool.values) {
        if (!toolLabelPattern.hasMatch(tool.label)) {
          toolLengthValid = false;
          invalidTools.add(tool);
        }
      }

      expect(toolLengthValid, true,
          reason:
              'All tool labels must be under 36 characters and begin with a letter\n'
              'The following are invalid\n$invalidTools');
    });

    test('max 40 characters for event names', () {
      // Check that each event name is less than 40 chars and starts with
      // an alphabetic character; the entire string has to be alphanumeric
      // and underscores
      final eventLabelPattern = RegExp(r'^[a-zA-Z]{1}[a-zA-Z0-9\_]{0,39}$');
      var eventValid = true;
      final invalidEvents = <DashEvent>[];
      for (final event in DashEvent.values) {
        if (!eventLabelPattern.hasMatch(event.label)) {
          eventValid = false;
          invalidEvents.add(event);
        }
      }

      expect(eventValid, true,
          reason: 'All event labels should have letters and underscores '
              'as a delimiter if needed; invalid events below\n$invalidEvents');
    });
  });

  test('Confirm credentials for GA', () {
    expect(kGoogleAnalyticsApiSecret, 'Ka1jc8tZSzWc_GXMWHfPHA');
    expect(kGoogleAnalyticsMeasurementId, 'G-04BXPVBCWJ');
  });

  test('Consent message is formatted correctly for the flutter tool', () {
    // Retrieve the consent message for flutter tools
    final consentMessage = analytics.getConsentMessage;

    expect(consentMessage, equalsIgnoringWhitespace(r'''
The Flutter CLI developer tool uses Google Analytics to report usage and diagnostic
data along with package dependencies, and crash reporting to send basic crash
reports. This data is used to help improve the Dart platform, Flutter framework,
and related tools.

Telemetry is not sent on the very first run. To disable reporting of telemetry,
run this terminal command:

    flutter --disable-analytics

If you opt out of telemetry, an opt-out event will be sent, and then no further
information will be sent. This data is collected in accordance with the Google
Privacy Policy (https://policies.google.com/privacy).
'''));
  });

  test('Consent message is formatted correctly for any tool other than flutter',
      () {
    // Create a new instance of the analytics class with the new tool
    final secondAnalytics = Analytics.fake(
      tool: secondTool,
      homeDirectory: home,
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    // Retrieve the consent message for flutter tools
    final consentMessage = secondAnalytics.getConsentMessage;

    expect(consentMessage, equalsIgnoringWhitespace(r'''
The Dart CLI developer tool uses Google Analytics to report usage and diagnostic
data along with package dependencies, and crash reporting to send basic crash
reports. This data is used to help improve the Dart platform, Flutter framework,
and related tools.

Telemetry is not sent on the very first run. To disable reporting of telemetry,
run this terminal command:

    dart --disable-analytics

If you opt out of telemetry, an opt-out event will be sent, and then no further
information will be sent. This data is collected in accordance with the Google
Privacy Policy (https://policies.google.com/privacy).
'''));
  });

  test('Equality operator works for identical events', () {
    final eventOne = Event.clientRequest(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
    );
    final eventTwo = Event.clientRequest(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
    );

    expect(eventOne == eventTwo, true);
  });

  test('Equality operator works for non-identical events', () {
    final eventOne = Event.clientRequest(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
      added: 'DIFFERENT FROM EVENT TWO',
    );
    final eventTwo = Event.clientRequest(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
    );

    expect(eventOne == eventTwo, false);
  });

  test('Find a match for an event in a list of events', () {
    final eventList = [
      Event.analyticsCollectionEnabled(status: true),
      Event.memoryInfo(rss: 500),
      Event.clientRequest(
          duration: 'duration', latency: 'latency', method: 'method'),
    ];

    final eventToMatch = Event.memoryInfo(rss: 500);

    expect(eventList.contains(eventToMatch), true);
    expect(eventList.where((element) => element == eventToMatch).length, 1);
  });

  group('Unit tests for util dartSDKVersion', () {
    test('parses correctly for non-stable version', () {
      final originalVersion =
          '3.4.0-148.0.dev (dev) (Thu Feb 15 12:05:45 2024 -0800) on "macos_arm64"';

      expect(parseDartSDKVersion(originalVersion),
          '3.4.0 (build 3.4.0-148.0.dev)');
    });

    test('parses correctly for stable version', () {
      final originalVersion =
          '3.3.0 (stable) (Tue Feb 13 10:25:19 2024 +0000) on "macos_arm64"';

      expect(parseDartSDKVersion(originalVersion), '3.3.0');
    });
  });
}
