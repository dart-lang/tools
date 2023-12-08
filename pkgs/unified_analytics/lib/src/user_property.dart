// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';

import 'constants.dart';
import 'session.dart';
import 'utils.dart';

class UserProperty {
  final Session session;
  final String? flutterChannel;
  final String host;
  final String? flutterVersion;
  final String dartVersion;
  final String tool;
  final String hostOsVersion;
  final String locale;
  final String? clientIde;
  final String? enabledFeatures;

  /// This class is intended to capture all of the user's
  /// metadata when the class gets initialized as well as collecting
  /// session data to send in the json payload to Google Analytics.
  UserProperty({
    required this.session,
    required this.flutterChannel,
    required this.host,
    required this.flutterVersion,
    required this.dartVersion,
    required this.tool,
    required this.hostOsVersion,
    required this.locale,
    required this.clientIde,
    required this.enabledFeatures,
  });

  /// This method will take the data in this class and convert it into
  /// a Map that is suitable for the POST request schema.
  ///
  /// This will call the [Session] object's [Session.getSessionId] method which
  /// will update the session file and get a new session id if necessary.
  ///
  /// https://developers.google.com/analytics/devguides/collection/protocol/ga4/user-properties?client_type=gtag
  Map<String, Map<String, Object?>> preparePayload() {
    return <String, Map<String, Object?>>{
      for (MapEntry<String, Object?> entry in _toMap().entries)
        entry.key: <String, Object?>{'value': entry.value}
    };
  }

  @override
  String toString() {
    return jsonEncode(_toMap());
  }

  /// Convert the data stored in this class into a map while also
  /// getting the latest session id using the [Session] class.
  Map<String, Object?> _toMap() => <String, Object?>{
        'session_id': session.getSessionId(),
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
