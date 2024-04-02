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
  late Analytics analytics;

  const homeDirName = 'home';
  const initialTool = DashTool.flutterTool;
  const toolsMessageVersion = 1;
  const toolsMessage = 'toolsMessage';
  const flutterChannel = 'flutterChannel';
  const flutterVersion = 'flutterVersion';
  const dartVersion = 'dartVersion';
  const platform = DevicePlatform.macos;

  setUp(() {
    // Setup the filesystem with the home directory
    final fsStyle =
        io.Platform.isWindows ? FileSystemStyle.windows : FileSystemStyle.posix;
    fs = MemoryFileSystem.test(style: fsStyle);
    home = fs.directory(homeDirName);
  });

  test('Honor legacy dart analytics opt out', () {
    // Create the file for the dart legacy opt out
    final dartLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    dartLegacyConfigFile.createSync(recursive: true);
    dartLegacyConfigFile.writeAsStringSync('''
{
  "firstRun": false,
  "enabled": false,
  "disclosureShown": true,
  "clientId": "52710e60-7c70-4335-b3a4-9d922630f12a"
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });

  test('Telemetry enabled if legacy dart analytics is enabled', () {
    // Create the file for the dart legacy opt out
    final dartLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    dartLegacyConfigFile.createSync(recursive: true);
    dartLegacyConfigFile.writeAsStringSync('''
{
  "firstRun": false,
  "enabled": true,
  "disclosureShown": true,
  "clientId": "52710e60-7c70-4335-b3a4-9d922630f12a"
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, true);
  });

  test('Honor legacy flutter analytics opt out', () {
    // Create the file for the flutter legacy opt out
    final flutterLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    flutterLegacyConfigFile.createSync(recursive: true);
    flutterLegacyConfigFile.writeAsStringSync('''
{
  "firstRun": false,
  "clientId": "4c3a3d1e-e545-47e7-b4f8-10129f6ab169",
  "enabled": false
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });

  test('Telemetry enabled if legacy flutter analytics is enabled', () {
    // Create the file for the flutter legacy opt out
    final flutterLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    flutterLegacyConfigFile.createSync(recursive: true);
    flutterLegacyConfigFile.writeAsStringSync('''
{
  "firstRun": false,
  "clientId": "4c3a3d1e-e545-47e7-b4f8-10129f6ab169",
  "enabled": true
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, true);
  });

  test('Honor legacy devtools analytics opt out', () {
    // Create the file for the devtools legacy opt out
    final devtoolsLegacyConfigFile =
        home.childDirectory('.flutter-devtools').childFile('.devtools');
    devtoolsLegacyConfigFile.createSync(recursive: true);
    devtoolsLegacyConfigFile.writeAsStringSync('''
{
  "analyticsEnabled": false,
  "isFirstRun": false,
  "lastReleaseNotesVersion": "2.31.0",
  "2023-Q4": {
    "surveyActionTaken": false,
    "surveyShownCount": 0
  }
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });

  test('Telemetry enabled if legacy devtools analytics is enabled', () {
    // Create the file for the devtools legacy opt out
    final devtoolsLegacyConfigFile =
        home.childDirectory('.flutter-devtools').childFile('.devtools');
    devtoolsLegacyConfigFile.createSync(recursive: true);
    devtoolsLegacyConfigFile.writeAsStringSync('''
{
  "analyticsEnabled": true,
  "isFirstRun": false,
  "lastReleaseNotesVersion": "2.31.0",
  "2023-Q4": {
    "surveyActionTaken": false,
    "surveyShownCount": 0
  }
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, true);
  });

  test('Telemetry disabled if dart config file corrupted', () {
    // Create the file for the dart legacy opt out with text that
    // is not valid JSON
    final dartLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    dartLegacyConfigFile.createSync(recursive: true);
    dartLegacyConfigFile.writeAsStringSync('''
NOT VALID JSON
{
  "firstRun": false,
  "clientId": "4c3a3d1e-e545-47e7-b4f8-10129f6ab169",
  "enabled": true
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });

  test('Telemetry disabled if devtools config file corrupted', () {
    // Create the file for the devtools legacy opt out with text that
    // is not valid JSON
    final devtoolsLegacyConfigFile =
        home.childDirectory('.flutter-devtools').childFile('.devtools');
    devtoolsLegacyConfigFile.createSync(recursive: true);
    devtoolsLegacyConfigFile.writeAsStringSync('''
NOT VALID JSON
{
  "analyticsEnabled": true,
  "isFirstRun": false,
  "lastReleaseNotesVersion": "2.31.0",
  "2023-Q4": {
    "surveyActionTaken": false,
    "surveyShownCount": 0
  }
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });

  test('Telemetry disabled if flutter config file corrupted', () {
    // Create the file for the flutter legacy opt out with text that
    // is not valid JSON
    final fluttterLegacyConfigFile =
        home.childDirectory('.dart').childFile('dartdev.json');
    fluttterLegacyConfigFile.createSync(recursive: true);
    fluttterLegacyConfigFile.writeAsStringSync('''
NOT VALID JSON
{
  "firstRun": false,
  "clientId": "4c3a3d1e-e545-47e7-b4f8-10129f6ab169",
  "enabled": true
}
''');

    // The main analytics instance, other instances can be spawned within tests
    // to test how to instances running together work
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

    expect(analytics.telemetryEnabled, false);
  });
}
