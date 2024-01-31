// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'analytics.dart';
import 'constants.dart';
import 'event.dart';
import 'initializer.dart';

class Session {
  final Directory homeDirectory;
  final FileSystem fs;
  final File sessionFile;
  final Analytics _analyticsInstance;

  late int _sessionId;
  late int _lastPing;

  /// Ensure we are only sending once per invocation for this class.
  var _errorEventSent = false;

  Session({
    required this.homeDirectory,
    required this.fs,
    required Analytics analyticsInstance,
  })  : sessionFile = fs.file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kSessionFileName)),
        _analyticsInstance = analyticsInstance {
    _refreshSessionData();
  }

  /// This will use the data parsed from the
  /// session json file in the dart-tool directory
  /// to get the session id if the last ping was within
  /// [kSessionDurationMinutes].
  ///
  /// If time since last ping exceeds the duration, then the file
  /// will be updated with a new session id and that will be returned.
  ///
  /// Note, the file will always be updated when calling this method
  /// because the last ping variable will always need to be persisted.
  int getSessionId() {
    _refreshSessionData();
    final now = clock.now();

    // Convert the epoch time from the last ping into datetime and check if we
    // are within the kSessionDurationMinutes.
    final lastPingDateTime = DateTime.fromMillisecondsSinceEpoch(_lastPing);
    if (now.difference(lastPingDateTime).inMinutes > kSessionDurationMinutes) {
      // In this case, we will need to change both the session id
      // and the last ping value
      _sessionId = now.millisecondsSinceEpoch;
    }

    // Update the last ping to reflect session activity continuing
    _lastPing = now.millisecondsSinceEpoch;

    // Rewrite the session object back to the file to persist
    // for future events
    sessionFile.writeAsStringSync(toJson());

    return _sessionId;
  }

  /// Return a json formatted representation of the class.
  String toJson() => jsonEncode(<String, int>{
        'session_id': _sessionId,
        'last_ping': _lastPing,
      });

  /// This will go to the session file within the dart-tool
  /// directory and fetch the latest data from the json to update
  /// the class's variables. If the json file is malformed, a new
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
      _lastPing = sessionObj['last_ping'] as int;
    }

    try {
      parseContents();
    } on FormatException catch (err) {
      Initializer.createSessionFile(sessionFile: sessionFile);

      if (!_errorEventSent) {
        _analyticsInstance.send(Event.analyticsException(
          workflow: 'Session._refreshSessionData',
          error: err.runtimeType.toString(),
          description: 'message: ${err.message}\nsource: ${err.source}',
        ));
        _errorEventSent = true;
      }

      parseContents();
    } on FileSystemException catch (err) {
      Initializer.createSessionFile(sessionFile: sessionFile);

      if (!_errorEventSent) {
        _analyticsInstance.send(Event.analyticsException(
          workflow: 'Session._refreshSessionData',
          error: err.runtimeType.toString(),
          description: err.osError?.toString(),
        ));
        _errorEventSent = true;
      }

      parseContents();
    }
  }
}
