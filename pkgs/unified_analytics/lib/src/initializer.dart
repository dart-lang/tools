// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'utils.dart';

/// Creates the text file that will contain the client ID
/// which will be used across all related tools for analytics
/// reporting in GA.
void createClientIdFile({required File clientIdFile}) {
  clientIdFile.createSync(recursive: true);
  clientIdFile.writeAsStringSync(Uuid().generateV4());
}

/// Creates the configuration file with the default message
/// in the user's home directory.
void createConfigFile({
  required File configFile,
  required Directory homeDirectory,
  required FileSystem fs,
}) {
  configFile.createSync(recursive: true);

  // If the user was previously opted out, then we will
  // replace the line that assumes automatic opt in with
  // an opt out from the start
  if (legacyOptOut(fs: fs, home: homeDirectory)) {
    configFile.writeAsStringSync(
        kConfigString.replaceAll('reporting=1', 'reporting=0'));
  } else {
    configFile.writeAsStringSync(kConfigString);
  }
}

/// Creates that file that will persist dismissed survey ids.
void createDismissedSurveyFile({required File dismissedSurveyFile}) {
  dismissedSurveyFile.createSync(recursive: true);
  dismissedSurveyFile.writeAsStringSync('{}');
}

/// Creates that log file that will store the record formatted
/// events locally on the user's machine.
void createLogFile({required File logFile}) {
  logFile.createSync(recursive: true);
}

/// Creates the session file which will contain
/// the current session id which is the current timestamp.
///
/// It also returns the timestamp used for the session if it needs
/// to be accessed.
DateTime createSessionFile({required File sessionFile}) {
  final now = clock.now();
  sessionFile.createSync(recursive: true);
  writeSessionContents(sessionFile: sessionFile);

  return now;
}

/// Performs all of the initialization checks for the required files.
///
/// Returns `true` if the config file was created indicating it is the first
/// time this package was run on a user's machine.
///
/// Checks for the following:
/// - Config file
/// - Client ID file
/// - Session JSON file
/// - Log file
/// - Dismissed survey JSON file
bool runInitialization({
  required Directory homeDirectory,
  required FileSystem fs,
}) {
  var firstRun = false;

  // When the config file doesn't exist, initialize it with the default tools
  // and the current date
  final configFile = fs.file(
      p.join(homeDirectory.path, kDartToolDirectoryName, kConfigFileName));
  if (!configFile.existsSync()) {
    firstRun = true;
    createConfigFile(
      configFile: configFile,
      fs: fs,
      homeDirectory: homeDirectory,
    );
  }

  // Begin initialization checks for the client id
  final clientFile = fs.file(
      p.join(homeDirectory.path, kDartToolDirectoryName, kClientIdFileName));
  if (!clientFile.existsSync()) {
    createClientIdFile(clientIdFile: clientFile);
  }

  // Begin initialization checks for the session file
  final sessionFile = fs.file(
      p.join(homeDirectory.path, kDartToolDirectoryName, kSessionFileName));
  if (!sessionFile.existsSync()) {
    createSessionFile(sessionFile: sessionFile);
  }

  // Begin initialization checks for the log file to persist events locally
  final logFile =
      fs.file(p.join(homeDirectory.path, kDartToolDirectoryName, kLogFileName));
  if (!logFile.existsSync()) {
    createLogFile(logFile: logFile);
  }

  // Begin initialization checks for the dismissed survey file
  final dismissedSurveyFile = fs.file(p.join(
      homeDirectory.path, kDartToolDirectoryName, kDismissedSurveyFileName));
  if (!dismissedSurveyFile.existsSync()) {
    createDismissedSurveyFile(dismissedSurveyFile: dismissedSurveyFile);
  }

  return firstRun;
}
