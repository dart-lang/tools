// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  late FileSystem fs;
  late Directory home;
  late Directory dartToolDirectory;
  late Analytics analytics;

  const String homeDirName = 'home';
  const DashTool initialTool = DashTool.flutterTool;
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
  });

  test('Honor legacy dart analytics opt out', () {
    // Create the file for the dart legacy opt out
    final File dartLegacyConfigFile =
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
    );

    // THIS NEEDS TO GET FIXED BECAUSE THE SET TELEMETRY
    // FUNCTION IS ASYNC AND WON'T REFLECTED IMMEDIATELY EVEN
    // THOUGH THE USER HAS OPTED OUT IN DART
    print(analytics.telemetryEnabled);

  });
}
