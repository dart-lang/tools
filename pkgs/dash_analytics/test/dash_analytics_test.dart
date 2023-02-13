// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:dash_analytics/dash_analytics.dart';
import 'package:dash_analytics/src/config_handler.dart';
import 'package:dash_analytics/src/constants.dart';
import 'package:dash_analytics/src/session.dart';
import 'package:dash_analytics/src/user_property.dart';
import 'package:dash_analytics/src/utils.dart';

void main() {
  late FileSystem fs;
  late Directory home;
  late Directory dartToolDirectory;
  late Analytics analytics;
  late File clientIdFile;
  late File sessionFile;
  late File configFile;
  late File logFile;
  late UserProperty userProperty;

  const String homeDirName = 'home';
  const String initialToolName = 'initialTool';
  const String secondTool = 'newTool';
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

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
    analytics = Analytics.test(
      tool: initialToolName,
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

    // Create the user property object that is also
    // created within analytics for testing
    userProperty = UserProperty(
      session: Session(homeDirectory: home, fs: fs),
      flutterChannel: flutterChannel,
      host: platform.label,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      tool: initialToolName,
    );
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
    expect(dartToolDirectory.listSync().length, equals(4),
        reason:
            'There should only be 4 files in the $kDartToolDirectoryName directory');
    expect(analytics.shouldShowMessage, true,
        reason: 'For the first run, analytics should default to being enabled');
  });

  test('New tool is successfully added to config file', () {
    // Create a new instance of the analytics class with the new tool
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    expect(secondAnalytics.parsedTools.length, equals(2),
        reason: 'There should be only 2 tools that have '
            'been parsed into the config file');
    expect(secondAnalytics.parsedTools.containsKey(initialToolName), true,
        reason: 'The first tool: $initialToolName should be in the map');
    expect(secondAnalytics.parsedTools.containsKey(secondTool), true,
        reason: 'The second tool: $secondAnalytics should be in the map');
    expect(configFile.readAsStringSync().startsWith(kConfigString), true,
        reason:
            'The config file should have the same message from the constants file');
  });

  test('Toggling telemetry boolean through Analytics class api', () async {
    expect(analytics.telemetryEnabled, true,
        reason: 'Telemetry should be enabled by default '
            'when initialized for the first time');

    // Use the API to disable analytics
    await analytics.setTelemetry(false);
    expect(analytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled');

    // Toggle it back to being enabled
    await analytics.setTelemetry(true);
    expect(analytics.telemetryEnabled, true,
        reason: 'Analytics telemetry should be enabled');
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
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    expect(secondAnalytics.telemetryEnabled, false,
        reason: 'Analytics telemetry should be disabled by the first class '
            'and the second class should show telemetry is disabled');
  });

  test(
      'Two concurrent instances are running '
      'and reflect an accurate up to date telemetry status', () async {
    // Initialize a second analytics class, which simulates a second tool
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

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
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: 'ey-test-channel',
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );
    expect(secondAnalytics.telemetryEnabled, true);

    expect(configFile.readAsStringSync().endsWith('\n'), true,
        reason: 'The second analytics class will correct '
            'the missing new line character');
  });

  test('Incrementing the version for a tool is successful', () {
    expect(analytics.parsedTools[initialToolName]?.versionNumber,
        toolsMessageVersion,
        reason: 'On initialization, the first version number should '
            'be what is set in the setup method');

    // Initialize a second analytics class for the same tool as
    // the first analytics instance except with a newer version for
    // the tools message and version
    final Analytics secondAnalytics = Analytics.test(
      tool: initialToolName,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );

    expect(secondAnalytics.parsedTools[initialToolName]?.versionNumber,
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
$initialToolName=${ConfigHandler.dateStamp},$toolsMessageVersion
$initialToolName=${ConfigHandler.dateStamp},$toolsMessageVersion
''');

    // Initialize a second analytics class for the same tool as
    // the first analytics instance except with a newer version for
    // the tools message and version
    //
    // This second instance should reset the config file when it goes
    // to increment the version in the file
    final Analytics secondAnalytics = Analytics.test(
      tool: initialToolName,
      homeDirectory: home,
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion + 1,
      toolsMessage: toolsMessage,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      fs: fs,
      platform: platform,
    );

    expect(
      configFile.readAsStringSync().endsWith(
          '# displayed.\n$initialToolName=${ConfigHandler.dateStamp},${toolsMessageVersion + 1}\n'),
      true,
      reason: 'The config file ends with the correctly formatted ending '
          'after removing the duplicate lines for a given tool',
    );
    expect(
      secondAnalytics.parsedTools[initialToolName]?.versionNumber,
      toolsMessageVersion + 1,
      reason: 'The new version should have been incremented',
    );
  });

  test('Check that UserProperty class has all the necessary keys', () {
    const List<String> userPropertyKeys = <String>[
      'session_id',
      'flutter_channel',
      'host',
      'flutter_version',
      'dart_version',
      'dash_analytics_version',
      'tool',
      'local_time',
    ];
    expect(analytics.userPropertyMap.keys.length, userPropertyKeys.length,
        reason: 'There should only be ${userPropertyKeys.length} keys');
    for (String key in userPropertyKeys) {
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
    final DateTime start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      // This class will be constructed at a fixed time
      final Analytics secondAnalytics = Analytics.test(
        tool: secondTool,
        homeDirectory: home,
        measurementId: 'measurementId',
        apiSecret: 'apiSecret',
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );

      // Read the contents of the session file
      final String sessionFileContents = sessionFile.readAsStringSync();
      final Map<String, dynamic> sessionObj = jsonDecode(sessionFileContents);

      expect(secondAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch);
      expect(sessionObj['last_ping'], start.millisecondsSinceEpoch);
    });

    // Add time to the start time that is less than the duration
    final DateTime end =
        start.add(Duration(minutes: kSessionDurationMinutes - 1));

    // Use a new clock to ensure that the session id didn't change
    withClock(Clock.fixed(end), () {
      // A new instance will need to be created since the second
      // instance in the previous block is scoped - this new instance
      // should not reset the files generated by the second instance
      final Analytics thirdAnalytics = Analytics.test(
        tool: secondTool,
        homeDirectory: home,
        measurementId: 'measurementId',
        apiSecret: 'apiSecret',
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );

      // Calling the send event method will result in the session file
      // getting updated but because we use the `Analytics.test()` constructor
      // no events will be sent
      thirdAnalytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});

      // Read the contents of the session file
      final String sessionFileContents = sessionFile.readAsStringSync();
      final Map<String, dynamic> sessionObj = jsonDecode(sessionFileContents);

      expect(thirdAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch,
          reason: 'The session id should not have changed since it was made '
              'within the duration');
      expect(sessionObj['last_ping'], end.millisecondsSinceEpoch,
          reason: 'The last_ping value should have been updated');
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
    final DateTime start = DateTime(1995, 3, 3, 12, 0);

    // Set the clock to the start value defined above
    withClock(Clock.fixed(start), () {
      // This class will be constructed at a fixed time
      final Analytics secondAnalytics = Analytics.test(
        tool: secondTool,
        homeDirectory: home,
        measurementId: 'measurementId',
        apiSecret: 'apiSecret',
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );

      // Read the contents of the session file
      final String sessionFileContents = sessionFile.readAsStringSync();
      final Map<String, dynamic> sessionObj = jsonDecode(sessionFileContents);

      expect(secondAnalytics.userPropertyMap['session_id']?['value'],
          start.millisecondsSinceEpoch);
      expect(sessionObj['last_ping'], start.millisecondsSinceEpoch);

      secondAnalytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    });

    // Add time to the start time that is less than the duration
    final DateTime end =
        start.add(Duration(minutes: kSessionDurationMinutes + 1));

    // Use a new clock to ensure that the session id didn't change
    withClock(Clock.fixed(end), () {
      // A new instance will need to be created since the second
      // instance in the previous block is scoped - this new instance
      // should not reset the files generated by the second instance
      final Analytics thirdAnalytics = Analytics.test(
        tool: secondTool,
        homeDirectory: home,
        measurementId: 'measurementId',
        apiSecret: 'apiSecret',
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
        dartVersion: 'Dart 2.19.0',
        fs: fs,
        platform: platform,
      );

      // Calling the send event method will result in the session file
      // getting updated but because we use the `Analytics.test()` constructor
      // no events will be sent
      thirdAnalytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});

      // Read the contents of the session file
      final String sessionFileContents = sessionFile.readAsStringSync();
      final Map<String, dynamic> sessionObj = jsonDecode(sessionFileContents);

      expect(thirdAnalytics.userPropertyMap['session_id']?['value'],
          end.millisecondsSinceEpoch,
          reason: 'The session id should have changed since it was made '
              'outside the duration');
      expect(sessionObj['last_ping'], end.millisecondsSinceEpoch,
          reason: 'The last_ping value should have been updated');
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
    final Map<String, dynamic> eventData = <String, dynamic>{
      'time': 5,
      'command': 'run',
    };

    final Map<String, dynamic> body = generateRequestBody(
      clientId: Uuid().generateV4(),
      eventName: DashEvent.hotReloadTime,
      eventData: eventData,
      userProperty: userProperty,
    );

    // Checks for the top level keys
    expect(body.containsKey('client_id'), true,
        reason: '"client_id" is required at the top level');
    expect(body.containsKey('events'), true,
        reason: '"events" is required at the top level');
    expect(body.containsKey('user_properties'), true,
        reason: '"user_properties" is required at the top level');

    // Regex for the client id
    final RegExp clientIdPattern = RegExp(
        r'^[0-9a-z]{8}\-[0-9a-z]{4}\-[0-9a-z]{4}\-[0-9a-z]{4}\-[0-9a-z]{12}$');

    // Checks for the top level values
    expect(body['client_id'].runtimeType, String,
        reason: 'The client id must be a string');
    expect(clientIdPattern.hasMatch(body['client_id']), true,
        reason: 'The client id is not properly formatted, ie '
            '46cc0ba6-f604-4fd9-aa2f-8a20beb24cd4');
    expect(
        (body['events'][0] as Map<String, dynamic>).containsKey('name'), true,
        reason: 'Each event in the events array needs a name');
    expect(
        (body['events'][0] as Map<String, dynamic>).containsKey('params'), true,
        reason: 'Each event in the events array needs a params key');
  });

  test(
      'All DashTools labels are made of characters that are letters or hyphens',
      () {
    // Regex pattern to match only letters or hyphens
    final RegExp toolLabelPattern = RegExp(r'^[a-zA-Z\-]+$');
    bool valid = true;
    for (DashTool tool in DashTool.values) {
      if (!toolLabelPattern.hasMatch(tool.label)) {
        valid = false;
      }
    }

    expect(valid, true,
        reason: 'All tool labels should have letters and hyphens '
            'as a delimiter if needed');
  });

  test('Check that log file is correctly persisting events sent', () {
    final int numberOfEvents = max((kLogFileLength * 0.1).floor(), 5);

    for (int i = 0; i < numberOfEvents; i++) {
      analytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    }

    expect(logFile.readAsLinesSync().length, numberOfEvents,
        reason: 'The number of events should be $numberOfEvents');

    // Add the max number of events to confirm it does not exceed the max
    for (int i = 0; i < kLogFileLength; i++) {
      analytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    }

    expect(logFile.readAsLinesSync().length, kLogFileLength,
        reason: 'The number of events should be capped at $kLogFileLength');
  });

  test('Check the query on the log file works as expected', () {
    expect(analytics.logFileStats(), isNull,
        reason: 'The result for the log file stats should be null when '
            'there are no logs');
    analytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});

    final LogFileStats firstQuery = analytics.logFileStats()!;
    expect(firstQuery.sessionCount, 1,
        reason:
            'There should only be one session after the initial send event');
    expect(firstQuery.flutterChannelCount, 1,
        reason: 'There should only be one flutter channel logged');
    expect(firstQuery.toolCount, 1,
        reason: 'There should only be one tool logged');

    // Define a new clock that is outside of the session duration
    final DateTime firstClock =
        clock.now().add(Duration(minutes: kSessionDurationMinutes + 1));

    // Use the new clock to send an event that will change the session identifier
    withClock(Clock.fixed(firstClock), () {
      analytics.sendEvent(
          eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    });

    final LogFileStats secondQuery = analytics.logFileStats()!;
    expect(secondQuery.sessionCount, 2,
        reason: 'There should be 2 sessions after the second event');
  });

  test('Check that the log file shows two different tools being used', () {
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    // Send events with both instances of the classes
    analytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    secondAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});

    // Query the log file stats to verify that there are two tools
    LogFileStats query = analytics.logFileStats()!;

    expect(query.toolCount, 2,
        reason: 'There should have been two tools in the persisted logs');
  });

  test('Check that log data missing some keys results in null for stats', () {
    // The following string represents a log item that is malformed (missing the `tool` key)
    const String malformedLog =
        '{"client_id":"d40133a0-7ea6-4347-b668-ffae94bb8774",'
        '"events":[{"name":"hot_reload_time","params":{"time_ns":345}}],'
        '"user_properties":{'
        '"session_id":{"value":1675193534342},'
        '"flutter_channel":{"value":"ey-test-channel"},'
        '"host":{"value":"macOS"},'
        '"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},'
        '"dart_version":{"value":"Dart 2.19.0"},'
        // '"tool":{"value":"flutter-tools"},'  NEEDS REMAIN REMOVED
        '"local_time":{"value":"2023-01-31 14:32:14.592898"}}}';

    logFile.writeAsStringSync(malformedLog);
    final LogFileStats? query = analytics.logFileStats();

    expect(query, isNull,
        reason:
            'The query should be null because `tool` is missing under `user_properties`');
  });

  test('Malformed local_time string should result in null for stats', () {
    // The following string represents a log item that is malformed (missing the `tool` key)
    const String malformedLog =
        '{"client_id":"d40133a0-7ea6-4347-b668-ffae94bb8774",'
        '"events":[{"name":"hot_reload_time","params":{"time_ns":345}}],'
        '"user_properties":{'
        '"session_id":{"value":1675193534342},'
        '"flutter_channel":{"value":"ey-test-channel"},'
        '"host":{"value":"macOS"},'
        '"flutter_version":{"value":"Flutter 3.6.0-7.0.pre.47"},'
        '"dart_version":{"value":"Dart 2.19.0"},'
        '"tool":{"value":"flutter-tools"},'
        '"local_time":{"value":"2023-xx-31 14:32:14.592898"}}}'; // PURPOSEFULLY MALFORMED

    logFile.writeAsStringSync(malformedLog);
    final LogFileStats? query = analytics.logFileStats();

    expect(query, isNull,
        reason:
            'The query should be null because the `local_time` value is malformed');
  });

  test('Check that the constant kPackageVersion matches pubspec version', () {
    // Parse the contents of the pubspec.yaml
    final String pubspecYamlString = io.File('pubspec.yaml').readAsStringSync();

    // Parse into a yaml document to extract the version number
    final YamlMap doc = loadYaml(pubspecYamlString);
    final String version = doc['version'];

    expect(version, kPackageVersion,
        reason: 'The package version in the pubspec and '
            'constants.dart need to match\n'
            'Pubspec: $version && constants.dart: $kPackageVersion\n\n'
            'Make sure both are the same');
  });

  test('Null values for flutter parameters is reflected properly in log file',
      () {
    final Analytics secondAnalytics = Analytics.test(
      tool: secondTool,
      homeDirectory: home,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      // flutterChannel: flutterChannel,           THIS NEEDS TO REMAIN REMOVED
      // toolsMessageVersion: toolsMessageVersion, THIS NEEDS TO REMAIN REMOVED
      toolsMessage: toolsMessage,
      flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
      dartVersion: 'Dart 2.19.0',
      fs: fs,
      platform: platform,
    );

    // Send an event and check that the query stats reflects what is expected
    secondAnalytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});

    // Query the log file stats to verify that there are two tools
    LogFileStats query = analytics.logFileStats()!;

    expect(query.toolCount, 1,
        reason: 'There should have only been on tool that sent events');
    expect(query.flutterChannelCount, 0,
        reason:
            'The instance does not have flutter information so it should be 0');

    // Sending a query with the first analytics instance which has flutter information
    // available should reflect in the query that there is 1 flutter channel present
    analytics.sendEvent(
        eventName: DashEvent.hotReloadTime, eventData: <String, dynamic>{});
    LogFileStats? query2 = analytics.logFileStats()!;

    expect(query2.toolCount, 2,
        reason: 'Two different analytics instances have '
            'been initialized and sent events');
    expect(query2.sessionCount, query.sessionCount,
        reason: 'The session should have remained the same');
    expect(query2.flutterChannelCount, 1,
        reason: 'The first instance has flutter information initialized');
  });
}
