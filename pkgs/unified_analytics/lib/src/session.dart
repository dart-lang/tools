// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'error_handler.dart';
import 'event.dart';
import 'initializer.dart';

class Session {
  final Directory homeDirectory;
  final FileSystem fs;
  final File sessionFile;
  final ErrorHandler _errorHandler;

  int? _sessionId;

  Session({
    required this.homeDirectory,
    required this.fs,
    required ErrorHandler errorHandler,
  })  : sessionFile = fs.file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kSessionFileName)),
        _errorHandler = errorHandler;

  /// This will use the data parsed from the
  /// session file in the dart-tool directory
  /// to get the session id if the last ping was within
  /// [kSessionDurationMinutes].
  ///
  /// If time since last ping exceeds the duration, then the file
  /// will be updated with a new session id and that will be returned.
  ///
  /// Note, the file will always be updated when calling this method
  /// because the last ping variable will always need to be persisted.
  int? getSessionId() {
    _refreshSessionData();
    final now = clock.now();

    // Convert the epoch time from the last ping into datetime and check if we
    // are within the kSessionDurationMinutes.
    final lastPingDateTime = sessionFile.lastModifiedSync();
    if (now.difference(lastPingDateTime).inMinutes > kSessionDurationMinutes) {
      // Update the session file with the latest session id
      _sessionId = now.millisecondsSinceEpoch;
      sessionFile.writeAsStringSync('{"session_id": $_sessionId}');
    } else {
      // Update the last modified timestamp with the current timestamp so that
      // we can use it for the next _lastPing calculation
      sessionFile.setLastModifiedSync(now);
    }

    return _sessionId;
  }

  /// Preps the [Session] class with the data found in the session file.
  ///
  /// We must check if telemetry is enabled to refresh the session data
  /// because the refresh method will write to the session file and for
  /// users that have opted out, we have to leave the session file empty
  /// per the privacy document
  void initialize(bool telemetryEnabled) {
    if (telemetryEnabled) _refreshSessionData();
  }

  /// This will go to the session file within the dart-tool
  /// directory and fetch the latest data from the session file to update
  /// the class's variables. If the session file is malformed, a new
  /// session file will be recreated.
  ///
  /// This allows the session data in this class to always be up
  /// to date incase another tool is also calling this package and
  /// making updates to the session file.
  void _refreshSessionData() {
    /// Using a nested function here to reduce verbosity
    void parseContents() {
      final sessionFileContents = sessionFile.readAsStringSync();
      final sessionObj =
          jsonDecode(sessionFileContents) as Map<String, Object?>;
      _sessionId = sessionObj['session_id'] as int;
    }

    try {
      // Failing to parse the contents will result in the current timestamp
      // being used as the session id and will get used to recreate the file
      parseContents();
    } on FormatException catch (err) {
      final now = clock.now();
      Initializer.createSessionFile(
        sessionFile: sessionFile,
        sessionIdOverride: now,
      );

      _errorHandler.log(Event.analyticsException(
        workflow: 'Session._refreshSessionData',
        error: err.runtimeType.toString(),
        description: 'message: ${err.message}\nsource: ${err.source}',
      ));

      // Fallback to setting the session id as the current time
      _sessionId = now.millisecondsSinceEpoch;
    } on FileSystemException catch (err) {
      final now = clock.now();
      Initializer.createSessionFile(
        sessionFile: sessionFile,
        sessionIdOverride: now,
      );

      _errorHandler.log(Event.analyticsException(
        workflow: 'Session._refreshSessionData',
        error: err.runtimeType.toString(),
        description: err.osError?.toString(),
      ));

      // Fallback to setting the session id as the current time
      _sessionId = now.millisecondsSinceEpoch;
      // ignore: avoid_catching_errors
    }
  }
}
