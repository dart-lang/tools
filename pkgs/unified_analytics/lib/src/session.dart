// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'initializer.dart';

class Session {
  final Directory homeDirectory;
  final FileSystem fs;
  final File _sessionFile;

  late int _sessionId;
  late int _lastPing;

  Session({
    required this.homeDirectory,
    required this.fs,
  }) : _sessionFile = fs.file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kSessionFileName)) {
    _refreshSessionData();
  }

  /// This will use the data parsed from the
  /// session json file in the dart-tool directory
  /// to get the session id if the last ping was within
  /// [sessionDurationMinutes]
  ///
  /// If time since last ping exceeds the duration, then the file
  /// will be updated with a new session id and that will be returned
  ///
  /// Note, the file will always be updated when calling this method
  /// because the last ping variable will always need to be persisted
  int getSessionId() {
    _refreshSessionData();
    final DateTime now = clock.now();

    // Convert the epoch time from the last ping into datetime and
    // check if we are within the [sessionDurationMinutes]
    final DateTime lastPingDateTime =
        DateTime.fromMillisecondsSinceEpoch(_lastPing);
    if (now.difference(lastPingDateTime).inMinutes > kSessionDurationMinutes) {
      // In this case, we will need to change both the session id
      // and the last ping value
      _sessionId = now.millisecondsSinceEpoch;
    }

    // Update the last ping to reflect session activity continuing
    _lastPing = now.millisecondsSinceEpoch;

    // Rewrite the session object back to the file to persist
    // for future events
    _sessionFile.writeAsStringSync(toJson());

    return _sessionId;
  }

  /// Return a json formatted representation of the class
  String toJson() => jsonEncode(<String, int>{
        'session_id': _sessionId,
        'last_ping': _lastPing,
      });

  /// This will go to the session file within the dart-tool
  /// directory and fetch the latest data from the json to update
  /// the class's variables. If the json file is malformed, a new
  /// session file will be recreated
  ///
  /// This allows the session data in this class to always be up
  /// to date incase another tool is also calling this package and
  /// making updates to the session file
  void _refreshSessionData() {
    try {
      final String sessionFileContents = _sessionFile.readAsStringSync();
      final Map<String, Object?> sessionObj = jsonDecode(sessionFileContents);
      _sessionId = sessionObj['session_id'] as int;
      _lastPing = sessionObj['last_ping'] as int;
    } on FormatException {
      Initializer.createSessionFile(sessionFile: _sessionFile);

      final String sessionFileContents = _sessionFile.readAsStringSync();
      final Map<String, Object?> sessionObj = jsonDecode(sessionFileContents);
      _sessionId = sessionObj['session_id'] as int;
      _lastPing = sessionObj['last_ping'] as int;
    }
  }
}
