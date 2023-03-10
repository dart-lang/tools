// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:math' show Random;

import 'package:file/file.dart';

import 'enums.dart';
import 'user_property.dart';

/// Format time as 'yyyy-MM-dd HH:mm:ss Z' where Z is the difference between the
/// timezone of t and UTC formatted according to RFC 822.
String formatDateTime(DateTime t) {
  final String sign = t.timeZoneOffset.isNegative ? '-' : '+';
  final Duration tzOffset = t.timeZoneOffset.abs();
  final int hoursOffset = tzOffset.inHours;
  final int minutesOffset =
      tzOffset.inMinutes - (Duration.minutesPerHour * hoursOffset);
  assert(hoursOffset < 24);
  assert(minutesOffset < 60);

  String twoDigits(int n) => (n >= 10) ? '$n' : '0$n';
  return '$t $sign${twoDigits(hoursOffset)}${twoDigits(minutesOffset)}';
}

/// Construct the Map that will be converted to json for the
/// body of the request
///
/// Follows the following schema
///
/// ```
/// {
///   "client_id": "46cc0ba6-f604-4fd9-aa2f-8a20beb24cd4",
///   "events": [{ "name": "testing", "params": { "time_ns": 345 } }],
///   "user_properties": {
///     "session_id": { "value": 1673466750423 },
///     "flutter_channel": { "value": "ey-test-channel" },
///     "host": { "value": "macos" },
///     "flutter_version": { "value": "Flutter 3.6.0-7.0.pre.47" },
///     "dart_version": { "value": "Dart 2.19.0" },
///     "tool": { "value": "flutter-tools" },
///     "local_time": { "value": "2023-01-11 14:53:31.471816" }
///   }
/// }
/// ```
/// https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag
Map<String, Object?> generateRequestBody({
  required String clientId,
  required DashEvent eventName,
  required Map<String, Object?> eventData,
  required UserProperty userProperty,
}) =>
    <String, Object?>{
      'client_id': clientId,
      'events': <Map<String, Object?>>[
        <String, Object?>{
          'name': eventName.label,
          'params': eventData,
        }
      ],
      'user_properties': userProperty.preparePayload()
    };

/// This will use environment variables to get the user's
/// home directory where all the directory will be created that will
/// contain all of the analytics files
Directory getHomeDirectory(FileSystem fs) {
  String? home;
  Map<String, String> envVars = io.Platform.environment;

  if (io.Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (io.Platform.isLinux) {
    home = envVars['HOME'];
  } else if (io.Platform.isWindows) {
    home = envVars['UserProfile'];
  }

  return fs.directory(home!);
}

/// A UUID generator.
///
/// This will generate unique IDs in the format:
///
///     f47ac10b-58cc-4372-a567-0e02b2c3d479
///
/// The generated uuids are 128 bit numbers encoded in a specific string format.
/// For more information, see
/// [en.wikipedia.org/wiki/Universally_unique_identifier](http://en.wikipedia.org/wiki/Universally_unique_identifier).
///
/// This class was taken from the previous `usage` package (https://github.com/dart-lang/usage/blob/master/lib/uuid/uuid.dart)
class Uuid {
  final Random _random = Random();

  /// Generate a version 4 (random) uuid. This is a uuid scheme that only uses
  /// random numbers as the source of the generated uuid.
  String generateV4() {
    // Generate xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx / 8-4-4-4-12.
    int special = 8 + _random.nextInt(4);

    return '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}-'
        '${_bitsDigits(16, 4)}-'
        '4${_bitsDigits(12, 3)}-'
        '${_printDigits(special, 1)}${_bitsDigits(12, 3)}-'
        '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}';
  }

  String _bitsDigits(int bitCount, int digitCount) =>
      _printDigits(_generateBits(bitCount), digitCount);

  int _generateBits(int bitCount) => _random.nextInt(1 << bitCount);

  String _printDigits(int value, int count) =>
      value.toRadixString(16).padLeft(count, '0');
}
