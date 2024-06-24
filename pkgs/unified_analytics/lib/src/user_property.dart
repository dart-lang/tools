// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';

import 'constants.dart';
import 'event.dart';
import 'initializer.dart';
import 'utils.dart';

class UserProperty {
  final String? flutterChannel;
  final String host;
  final String? flutterVersion;
  final String dartVersion;
  final String tool;
  final String hostOsVersion;
  final String locale;
  final String? clientIde;
  final String? enabledFeatures;

  final File sessionFile;

  /// Contains instances of [Event.analyticsException] that were encountered
  /// during a workflow and will be sent to GA4 for collection.
  final Set<Event> errorSet = {};

  int? _sessionId;

  /// This class is intended to capture all of the user's
  /// metadata when the class gets initialized as well as collecting
  /// session data to send in the json payload to Google Analytics.
  UserProperty({
    required this.flutterChannel,
    required this.host,
    required this.flutterVersion,
    required this.dartVersion,
    required this.tool,
    required this.hostOsVersion,
    required this.locale,
    required this.clientIde,
    required this.enabledFeatures,
    required this.sessionFile,
  });

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
      writeSessionContents(sessionFile: sessionFile);
    } else {
      // Update the last modified timestamp with the current timestamp so that
      // we can use it for the next _lastPing calculation
      sessionFile.setLastModifiedSync(now);
    }

    return _sessionId;
  }

  /// This method will take the data in this class and convert it into
  /// a Map that is suitable for the POST request schema.
  ///
  /// This will call the [UserProperty] object's [UserProperty.getSessionId]
  /// method which will update the session file and get a new session id
  /// if necessary.
  ///
  /// https://developers.google.com/analytics/devguides/collection/protocol/ga4/user-properties?client_type=gtag
  Map<String, Map<String, Object?>> preparePayload() {
    return <String, Map<String, Object?>>{
      for (final entry in _toMap().entries)
        entry.key: <String, Object?>{'value': entry.value}
    };
  }

  @override
  String toString() {
    return jsonEncode(_toMap());
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
      final now = createSessionFile(sessionFile: sessionFile);

      errorSet.add(Event.analyticsException(
        workflow: 'UserProperty._refreshSessionData',
        error: err.runtimeType.toString(),
        description: 'message: ${err.message}\nsource: ${err.source}',
      ));

      // Fallback to setting the session id as the current time
      _sessionId = now.millisecondsSinceEpoch;
    } on FileSystemException catch (err) {
      final now = createSessionFile(sessionFile: sessionFile);

      errorSet.add(Event.analyticsException(
        workflow: 'UserProperty._refreshSessionData',
        error: err.runtimeType.toString(),
        description: err.osError?.toString(),
      ));

      // Fallback to setting the session id as the current time
      _sessionId = now.millisecondsSinceEpoch;
    }
  }

  /// Convert the data stored in this class into a map while also
  /// getting the latest session id using the [UserProperty] class.
  Map<String, Object?> _toMap() => <String, Object?>{
        'session_id': getSessionId(),
        'flutter_channel': flutterChannel,
        'host': host,
        'flutter_version': flutterVersion,
        'dart_version': dartVersion,
        'analytics_pkg_version': kPackageVersion,
        'tool': tool,
        'local_time': formatDateTime(clock.now()),
        'host_os_version': hostOsVersion,
        'locale': locale,
        'client_ide': clientIde,
        'enabled_features': enabledFeatures,
      };
}
