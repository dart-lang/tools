// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' show Random;

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'enums.dart';
import 'event.dart';
import 'survey_handler.dart';
import 'user_property.dart';

/// Get a string representation of the current date in the following format:
/// ```text
/// yyyy-MM-dd (2023-01-09)
/// ```
String get dateStamp {
  return DateFormat('yyyy-MM-dd').format(clock.now());
}

/// Reads in a directory and returns `true` if write permissions are enabled.
///
/// Uses the [FileStat] method `modeString()` to return a string in the form
/// of `rwxrwxrwx` where the second character in the string indicates if write
/// is enabled with a `w` or disabled with `-`.
bool checkDirectoryForWritePermissions(Directory directory) {
  if (!directory.existsSync()) return false;

  final fileStat = directory.statSync();
  return fileStat.modeString()[1] == 'w';
}

/// Format time as 'yyyy-MM-dd HH:mm:ss Z' where Z is the difference between the
/// timezone of t and UTC formatted according to RFC 822.
String formatDateTime(DateTime t) {
  final sign = t.timeZoneOffset.isNegative ? '-' : '+';
  final tzOffset = t.timeZoneOffset.abs();
  final hoursOffset = tzOffset.inHours;
  final minutesOffset =
      tzOffset.inMinutes - (Duration.minutesPerHour * hoursOffset);
  assert(hoursOffset < 24);
  assert(minutesOffset < 60);

  String twoDigits(int n) => (n >= 10) ? '$n' : '0$n';
  return '$t $sign${twoDigits(hoursOffset)}${twoDigits(minutesOffset)}';
}

/// Construct the Map that will be converted to json for the
/// body of the request.
///
/// Follows the following schema:
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
///     "local_time": { "value": "2023-01-11 14:53:31.471816 -0500" }
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
/// contain all of the analytics files.
Directory? getHomeDirectory(FileSystem fs) {
  String? home;
  final envVars = io.Platform.environment;

  if (io.Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (io.Platform.isLinux) {
    home = envVars['HOME'];
  } else if (io.Platform.isWindows) {
    home = envVars['AppData'];
  }

  if (home == null) return null;

  return fs.directory(home);
}

/// Returns `true` if user has opted out of legacy analytics in
/// Dart or Flutter.
///
/// Checks legacy opt-out status for the Flutter
/// and Dart in the following locations.
///
/// Dart: `$HOME/.dart/dartdev.json`
/// ```
/// {
///   "firstRun": false,
///   "enabled": false,  <-- THIS USER HAS OPTED OUT
///   "disclosureShown": true,
///   "clientId": "52710e60-7c70-4335-b3a4-9d922630f12a"
/// }
/// ```
///
/// Flutter: `$HOME/.flutter`
/// ```
/// {
///   "firstRun": false,
///   "clientId": "4c3a3d1e-e545-47e7-b4f8-10129f6ab169",
///   "enabled": false  <-- THIS USER HAS OPTED OUT
/// }
/// ```
///
/// Devtools: `$HOME/.flutter-devtools/.devtools`
/// ```
/// {
///   "analyticsEnabled": false,  <-- THIS USER HAS OPTED OUT
///   "isFirstRun": false,
///   "lastReleaseNotesVersion": "2.31.0",
///   "2023-Q4": {
///     "surveyActionTaken": false,
///     "surveyShownCount": 0
///   }
/// }
/// ```
bool legacyOptOut({required FileSystem fs, required Directory home}) {
  // List of Maps for each of the config file, `key` refers to the
  // key in the json file that indicates if the user has been opted
  // out or not
  final legacyConfigFiles = [
    {
      'tool': DashTool.dartTool,
      'file': fs.file(p.join(home.path, '.dart', 'dartdev.json')),
      'key': 'enabled',
    },
    {
      'tool': DashTool.flutterTool,
      'file': fs.file(p.join(home.path, '.flutter')),
      'key': 'enabled',
    },
    {
      'tool': DashTool.devtools,
      'file': fs.file(p.join(home.path, '.flutter-devtools', '.devtools')),
      'key': 'analyticsEnabled',
    },
  ];
  for (final legacyConfigObj in legacyConfigFiles) {
    final legacyFile = legacyConfigObj['file']! as File;
    final lookupKey = legacyConfigObj['key']! as String;

    if (legacyFile.existsSync()) {
      try {
        final legacyFileObj =
            jsonDecode(legacyFile.readAsStringSync()) as Map<String, Object?>;
        if (legacyFileObj.containsKey(lookupKey) &&
            legacyFileObj[lookupKey] == false) {
          return true;
        }
      } on FormatException {
        // In the case of an error when parsing the json file, return true
        // which will result in the user being opted out of unified_analytics
        //
        // A corrupted file could mean they opted out previously but for some
        // reason, the file was written incorrectly
        return true;
      } on FileSystemException {
        return true;
      }
    }
  }

  return false;
}

/// Helper method that can be used to resolve the Dart SDK version for clients
/// of package:unified_analytics.
///
/// Input [versionString] for this method should be the returned string from
/// [io.Platform.version].
///
/// For tools that don't already have a method for resolving the Dart
/// SDK version in semver notation, this helper can be used. This uses
/// the [io.Platform.version] to parse the semver.
///
/// Example for stable version:
/// `3.3.0 (stable) (Tue Feb 13 10:25:19 2024 +0000) on "macos_arm64"` into
/// `3.3.0`.
///
/// Example for non-stable version:
/// `2.1.0-dev.8.0.flutter-312ae32` into `2.1.0 (build 2.1.0-dev.8.0 312ae32)`.
String parseDartSDKVersion(String versionString) {
  versionString = versionString.trim();
  final justVersion = versionString.split(' ')[0];

  // For non-stable versions, this regex will include build information
  return justVersion.replaceFirstMapped(RegExp(r'(\d+\.\d+\.\d+)(.+)'),
      (Match match) {
    final noFlutter = match[2]!.replaceAll('.flutter-', ' ');
    return '${match[1]} (build ${match[1]}$noFlutter)'.trim();
  });
}

/// Will use two strings to produce a double for applying a sampling
/// rate for [Survey] to be returned to the user.
double sampleRate(String string1, String string2) =>
    ((string1.hashCode + string2.hashCode) % 101) / 100;

/// Function to check if a given [Survey] can be shown again
/// by checking if it was snoozed or permanently dismissed.
///
/// If the [Survey] doesn't exist in the persisted file, then it
/// will be shown to the user.
///
/// If the [Survey] has been permanently dismissed, we will not
/// show it to the user.
///
/// If the [Survey] has been snoozed, we will check the timestamp
/// that it was snoozed at with the current time from [clock]
/// and if the snooze period has elapsed, then we will show it to the user.
bool surveySnoozedOrDismissed(
  Survey survey,
  Map<String, PersistedSurvey> persistedSurveyMap,
) {
  // If this survey hasn't been persisted yet, it is okay to pass
  // to the user
  if (!persistedSurveyMap.containsKey(survey.uniqueId)) return false;

  final persistedSurveyObj = persistedSurveyMap[survey.uniqueId]!;

  // If the survey has been dismissed permanently, we will not show the
  // survey
  if (!persistedSurveyObj.snoozed) return true;

  // Find how many minutes has elapsed from the timestamp and now
  final minutesElapsed =
      clock.now().difference(persistedSurveyObj.timestamp).inMinutes;

  return survey.snoozeForMinutes > minutesElapsed;
}

/// Due to some limitations for GA4, this function can be used to
/// truncate fields that we may not care about truncating, such as
/// the host os details.
///
/// [maxLength] represents the maximum length allowed for the string.
///
/// Example:
/// "Linux 6.2.0-1015-azure #15~22.04.1-Ubuntu SMP Fri Oct  6 13:20:44 UTC 2023"
///
/// The above string is what is returned by [io.Platform.operatingSystemVersion]
/// for certain machines running GitHub Actions, this function will truncate
/// that value down to the maximum length at 36 characters and return the below
///
/// Return:
/// "Linux 6.2.0-1015-azure #15~22."
///
/// This should only be used on fields that are okay to be truncated, this
/// should not be used for parameters on the [Event] constructors.
String truncateStringToLength(String str, int maxLength) {
  if (maxLength <= 0) {
    throw ArgumentError(
        'The length to truncate a string must be greater than 0');
  }

  if (maxLength > str.length) return str;

  return str.substring(0, maxLength);
}

/// Writes the JSON string payload to the provided [sessionFile].
///
/// The `last_ping` key:value pair has been deprecated, it remains included
/// for backward compatibility.
void writeSessionContents({required File sessionFile}) {
  final now = clock.now();
  sessionFile.writeAsStringSync('{"session_id": ${now.millisecondsSinceEpoch}, '
      '"last_ping": ${now.millisecondsSinceEpoch}}');
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
/// This class was taken from the previous `usage` package (https://github.com/dart-lang/usage/blob/master/lib/uuid/uuid.dart).
class Uuid {
  final Random _random;

  Uuid([int? seed]) : _random = Random(seed);

  /// Generate a version 4 (random) uuid. This is a uuid scheme that only uses
  /// random numbers as the source of the generated uuid.
  String generateV4() {
    // Generate xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx / 8-4-4-4-12.
    final special = 8 + _random.nextInt(4);

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
