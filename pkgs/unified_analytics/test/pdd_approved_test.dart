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
  late Analytics initializationAnalytics;
  late Analytics analytics;
  late File clientIdFile;
  late File sessionFile;
  late File configFile;
  late File logFile;

  const String homeDirName = 'home';
  const DashTool initialTool = DashTool.flutterTool;
  const String dartVersion = 'dartVersion';

  setUp(() {
    // Setup the filesystem with the home directory
    final FileSystemStyle fsStyle =
        io.Platform.isWindows ? FileSystemStyle.windows : FileSystemStyle.posix;
    fs = MemoryFileSystem.test(style: fsStyle);
    home = fs.directory(homeDirName);
    dartToolDirectory = home.childDirectory(kDartToolDirectoryName);

    // Create the initial analytics instance that will onboard the tool
    initializationAnalytics = Analytics(
      tool: initialTool,
      dartVersion: dartVersion,
      fsOverride: fs,
      homeOverride: home,
    );
    initializationAnalytics.clientShowedMessage();

    // The main analytics instance that will be used for the
    // tests after having the tool onboarded
    analytics = Analytics(
      tool: initialTool,
      dartVersion: dartVersion,
      fsOverride: fs,
      homeOverride: home,
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
  });

  test('Initializer properly sets up on first run', () {
    expect(dartToolDirectory.existsSync(), true,
        reason: 'The directory should have been created');
    expect(clientIdFile.existsSync(), true,
        reason: 'The $kClientIdFileName file was not found');
    expect(sessionFile.existsSync(), false,
        reason: 'The session handling has been disabled');
    expect(configFile.existsSync(), true,
        reason: 'The $kConfigFileName was not found');
    expect(logFile.existsSync(), false,
        reason: 'The log file has been disabled');
    expect(dartToolDirectory.listSync().length, equals(2),
        reason:
            'There should only be 2 files in the $kDartToolDirectoryName directory');
    expect(initializationAnalytics.shouldShowMessage, true,
        reason: 'For the first run, the message should be shown');
    expect(configFile.readAsLinesSync().length,
        kConfigString.split('\n').length + 1,
        reason: 'The number of lines should equal lines in constant value + 1 '
            'for the initialized tool');
  });

  test('Sending events does not cause any errors', () async {
    await expectLater(
        () => analytics.sendEvent(eventName: DashEvent.hotReloadTime),
        returnsNormally);
  });
}
