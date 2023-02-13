// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'utils.dart';

class Initializer {
  final FileSystem fs;
  final String tool;
  final Directory homeDirectory;
  final int toolsMessageVersion;
  final String toolsMessage;
  bool firstRun = false;

  /// Responsibe for the initialization of the files
  /// necessary for analytics reporting
  ///
  /// Creates the configuration file that allows the user to
  /// mannually opt out of reporting along with the file containing
  /// the client ID to be used across all relevant tooling
  ///
  /// Updating of the config file with new versions will
  /// not be handled by the [Initializer]
  Initializer({
    required this.fs,
    required this.tool,
    required this.homeDirectory,
    required this.toolsMessageVersion,
    required this.toolsMessage,
  });

  /// Get a string representation of the current date in the following format
  /// yyyy-MM-dd (2023-01-09)
  String get dateStamp {
    return DateFormat('yyyy-MM-dd').format(clock.now());
  }

  /// Creates the text file that will contain the client ID
  /// which will be used across all related tools for analytics
  /// reporting in GA
  void createClientIdFile({required File clientFile}) {
    clientFile.createSync(recursive: true);
    clientFile.writeAsStringSync(Uuid().generateV4());
  }

  /// Creates the configuration file with the default message
  /// in the user's home directory
  void createConfigFile({
    required File configFile,
    required String dateStamp,
    required String tool,
    required String toolsMessage,
    required int toolsMessageVersion,
  }) {
    configFile.createSync(recursive: true);
    configFile.writeAsStringSync('''
$kConfigString
$tool=$dateStamp,$toolsMessageVersion
''');
  }

  /// Creates that log file that will store the record formatted
  /// events locally on the user's machine
  void createLogFile({required File logFile}) {
    logFile.createSync(recursive: true);
  }

  /// Creates the session json file which will contain
  /// the current session id along with the timestamp for
  /// the last ping which will be used to increment the session
  /// if current timestamp is greater than the session window
  void createSessionFile({required File sessionFile}) {
    final DateTime now = clock.now();
    sessionFile.createSync(recursive: true);
    sessionFile.writeAsStringSync(jsonEncode(<String, int>{
      'session_id': now.millisecondsSinceEpoch,
      'last_ping': now.millisecondsSinceEpoch,
    }));
  }

  /// This will check that there is a client ID populated in
  /// the user's home directory under the dart-tool directory.
  /// If it doesn't exist, one will be created there
  ///
  /// Passing [forceReset] as true will only reset the configuration
  /// file, it won't recreate the client id and session files
  void run({bool forceReset = false}) {
    // Begin by checking for the config file
    final File configFile = fs.file(
        p.join(homeDirectory.path, kDartToolDirectoryName, kConfigFileName));

    // When the config file doesn't exist, initialize it with the default tools
    // and the current date
    if (!configFile.existsSync() || forceReset) {
      firstRun = true;
      createConfigFile(
        configFile: configFile,
        dateStamp: dateStamp,
        tool: tool,
        toolsMessage: toolsMessage,
        toolsMessageVersion: toolsMessageVersion,
      );
    }

    // Begin initialization checks for the client id
    final File clientFile = fs.file(
        p.join(homeDirectory.path, kDartToolDirectoryName, kClientIdFileName));
    if (!clientFile.existsSync()) {
      createClientIdFile(clientFile: clientFile);
    }

    // Begin initialization checks for the session file
    final File sessionFile = fs.file(
        p.join(homeDirectory.path, kDartToolDirectoryName, kSessionFileName));
    if (!sessionFile.existsSync()) {
      createSessionFile(sessionFile: sessionFile);
    }

    // Begin initialization checks for the log file to persist events locally
    final File logFile = fs
        .file(p.join(homeDirectory.path, kDartToolDirectoryName, kLogFileName));
    if (!logFile.existsSync()) {
      createLogFile(logFile: logFile);
    }
  }
}
