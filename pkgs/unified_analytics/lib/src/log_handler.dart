// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'initializer.dart';

/// Data class that will be returned when analyzing the
/// persisted log file on the client's machine
class LogFileStats {
  /// The oldest timestamp in the log file
  final DateTime startDateTime;

  /// Number of minutes from [startDateTime] to [DateTime.now()]
  final int minsFromStartDateTime;

  /// The latest timestamp in the log file
  final DateTime endDateTime;

  /// Number of minutes from [endDateTime] to [DateTime.now()]
  final int minsFromEndDateTime;

  /// The number of unique session ids found in the log file
  final int sessionCount;

  /// The number of unique flutter channels found in the log file
  final int flutterChannelCount;

  /// The number of unique tools found in the log file
  final int toolCount;

  /// The map containing all of the events in the file along with
  /// how many times they have occured
  final Map<String, int> eventCount;

  /// Total number of records in the log file
  final int recordCount;

  /// Contains the data from the [LogHandler.logFileStats] method
  const LogFileStats({
    required this.startDateTime,
    required this.minsFromStartDateTime,
    required this.endDateTime,
    required this.minsFromEndDateTime,
    required this.sessionCount,
    required this.flutterChannelCount,
    required this.toolCount,
    required this.recordCount,
    required this.eventCount,
  });

  @override
  String toString() => jsonEncode(<String, Object?>{
        'startDateTime': startDateTime.toString(),
        'minsFromStartDateTime': minsFromStartDateTime,
        'endDateTime': endDateTime.toString(),
        'minsFromEndDateTime': minsFromEndDateTime,
        'sessionCount': sessionCount,
        'flutterChannelCount': flutterChannelCount,
        'toolCount': toolCount,
        'recordCount': recordCount,
        'eventCount': eventCount,
      });
}

/// This class is responsible for writing to a log
/// file that has been initialized by the [Initializer]
///
/// It will be treated as an append only log and will be limited
/// to have has many data records as specified by [kLogFileLength]
class LogHandler {
  final FileSystem fs;
  final Directory homeDirectory;
  final File logFile;

  /// A log handler constructor that will delegate saving
  /// logs and retrieving stats from the persisted log
  LogHandler({
    required this.fs,
    required this.homeDirectory,
  }) : logFile = fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kLogFileName,
        ));

  /// Get stats from the persisted log file
  ///
  /// Note that some developers may only be Dart
  /// developers and will not have any data for flutter
  /// related metrics
  LogFileStats? logFileStats() {
    // Parse each line of the log file through [LogItem],
    // some returned records may be null if malformed, they will be
    // removed later through `whereType<LogItem>`
    final List<LogItem> records = logFile
        .readAsLinesSync()
        .map((String e) => LogItem.fromRecord(jsonDecode(e)))
        .whereType<LogItem>()
        .toList();

    if (records.isEmpty) return null;

    // Get the start and end dates for the log file
    final DateTime startDateTime = records.first.localTime;
    final DateTime endDateTime = records.last.localTime;

    // Map with counters for user properties
    final Map<String, Set<Object>> counter = <String, Set<Object>>{
      'sessions': <int>{},
      'flutter_channel': <String>{},
      'tool': <String>{},
    };

    // Map of counters for each event
    final Map<String, int> eventCount = <String, int>{};
    for (LogItem record in records) {
      counter['sessions']!.add(record.sessionId);
      counter['tool']!.add(record.tool);
      if (record.flutterChannel != null) {
        counter['flutter_channel']!.add(record.flutterChannel!);
      }

      // Count each event, if it doesn't exist in the [eventCount]
      // it will be added first
      if (!eventCount.containsKey(record.eventName)) {
        eventCount[record.eventName] = 0;
      }
      eventCount[record.eventName] = eventCount[record.eventName]! + 1;
    }

    return LogFileStats(
      startDateTime: startDateTime,
      minsFromStartDateTime: DateTime.now().difference(startDateTime).inMinutes,
      endDateTime: endDateTime,
      minsFromEndDateTime: DateTime.now().difference(endDateTime).inMinutes,
      sessionCount: counter['sessions']!.length,
      flutterChannelCount: counter['flutter_channel']!.length,
      toolCount: counter['tool']!.length,
      eventCount: eventCount,
      recordCount: records.length,
    );
  }

  /// Saves the data passed in as a single line in the log file
  ///
  /// This will keep the max number of records limited to equal to
  /// or less than [kLogFileLength] records
  void save({required Map<String, Object?> data}) {
    List<String> records = logFile.readAsLinesSync();
    final String content = '${jsonEncode(data)}\n';

    // When the record count is less than the max, add as normal;
    // else drop the oldest records until equal to max
    if (records.length < kLogFileLength) {
      logFile.writeAsStringSync(content, mode: FileMode.writeOnlyAppend);
    } else {
      records.add(content);
      records = records.skip(records.length - kLogFileLength).toList();

      logFile.writeAsStringSync(records.join('\n'));
    }
  }
}

/// Data class for each record persisted on the client's machine
class LogItem {
  final String eventName;
  final int sessionId;
  final String? flutterChannel;
  final String host;
  final String? flutterVersion;
  final String dartVersion;
  final String tool;
  final DateTime localTime;

  LogItem({
    required this.eventName,
    required this.sessionId,
    this.flutterChannel,
    required this.host,
    this.flutterVersion,
    required this.dartVersion,
    required this.tool,
    required this.localTime,
  });

  /// Serves a parser for each record in the log file
  ///
  /// Using this method guarantees that we have parsed out
  /// fields that are necessary for the [LogHandler.logFileStats]
  /// method
  ///
  /// If the returned value is [null], that indicates a malformed
  /// record which can be discarded during analysis
  ///
  /// Example of what a record looks like:
  /// ```
  /// {
  ///     "client_id": "d40133a0-7ea6-4347-b668-ffae94bb8774",
  ///     "events": [
  ///         {
  ///             "name": "hot_reload_time",
  ///             "params": {
  ///                 "time_ns": 345
  ///             }
  ///         }
  ///     ],
  ///     "user_properties": {
  ///         "session_id": {
  ///             "value": 1675193534342
  ///         },
  ///         "flutter_channel": {
  ///             "value": "ey-test-channel"
  ///         },
  ///         "host": {
  ///             "value": "macOS"
  ///         },
  ///         "flutter_version": {
  ///             "value": "Flutter 3.6.0-7.0.pre.47"
  ///         },
  ///         "dart_version": {
  ///             "value": "Dart 2.19.0"
  ///         },
  ///         "tool": {
  ///             "value": "flutter-tools"
  ///         },
  ///         "local_time": {
  ///             "value": "2023-01-31 14:32:14.592898"
  ///         }
  ///     }
  /// }
  /// ```
  static LogItem? fromRecord(Map<String, Object?> record) {
    if (!record.containsKey('user_properties') ||
        !record.containsKey('events')) {
      return null;
    }

    // Using a try/except here to parse out the fields if possible,
    // if not, it will quietly return null and won't get processed
    // downstream
    try {
      // Parse out values from the top level key = 'events' and return
      // a map for the one event in the value
      final Map<String, Object?> eventProp =
          ((record['events']! as List<Object?>).first as Map<String, Object?>);
      final String eventName = eventProp['name'] as String;

      // Parse the data out of the `user_properties` value
      final Map<String, Object?> userProps =
          record['user_properties'] as Map<String, Object?>;

      // Parse out the values from the top level key = 'user_properties`
      final int? sessionId =
          (userProps['session_id']! as Map<String, Object?>)['value'] as int?;
      final String? flutterChannel = (userProps['flutter_channel']!
          as Map<String, Object?>)['value'] as String?;
      final String? host =
          (userProps['host']! as Map<String, Object?>)['value'] as String?;
      final String? flutterVersion = (userProps['flutter_version']!
          as Map<String, Object?>)['value'] as String?;
      final String? dartVersion = (userProps['dart_version']!
          as Map<String, Object?>)['value'] as String?;
      final String? tool =
          (userProps['tool']! as Map<String, Object?>)['value'] as String?;
      final String? localTimeString = (userProps['local_time']!
          as Map<String, Object?>)['value'] as String?;

      // If any of the above values are null, return null since that
      // indicates the record is malformed; note that `flutter_version`
      // and `flutter_channel` are nullable fields in the log file
      final List<Object?> values = <Object?>[
        // Values associated with the top level key = 'events'
        eventName,

        // Values associated with the top level key = 'events'
        sessionId,
        host,
        dartVersion,
        tool,
        localTimeString,
      ];
      for (Object? value in values) {
        if (value == null) return null;
      }

      // Parse the local time from the string extracted
      final DateTime localTime = DateTime.parse(localTimeString!);

      return LogItem(
        eventName: eventName,
        sessionId: sessionId!,
        flutterChannel: flutterChannel,
        host: host!,
        flutterVersion: flutterVersion,
        dartVersion: dartVersion!,
        tool: tool!,
        localTime: localTime,
      );
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }
}
