// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'enums.dart';
import 'initializer.dart';
import 'log_handler.dart';

class Condition {
  /// How to query the log file.
  ///
  ///
  /// Example: logFileStats.recordCount refers to the
  /// total record count being returned by [LogFileStats].
  final String field;

  /// String representation of operator.
  ///
  ///
  /// Allowed values:
  /// - '>=' `greater than or equal to`
  /// - '<=' `less than or equal to`
  /// - '>' `greater than`
  /// - '<' `less then`
  /// - '==' `equals`
  /// - '!=' `not equal`
  final String operatorString;

  /// The value we will be comparing against using the [operatorString].
  final int value;

  /// One of the conditions that need to be valid for
  /// a survey to be returned to the user.
  ///
  /// Example of raw json:
  /// ```
  /// {
  /// 	"field": "logFileStats.recordCount",
  /// 	"operator": ">=",
  /// 	"value": 1000
  /// }
  /// ```
  Condition(
    this.field,
    this.operatorString,
    this.value,
  );

  Condition.fromJson(Map<String, dynamic> json)
      : field = json['field'] as String,
        operatorString = json['operator'] as String,
        value = json['value'] as int;

  Map<String, Object?> toMap() => <String, Object?>{
        'field': field,
        'operator': operatorString,
        'value': value,
      };

  @override
  String toString() => jsonEncode(toMap());
}

/// Data class for the persisted survey contents.
///
/// [uniqueId] is the identifier for each survey, [timestamp] refers
/// to when the survey was added to the persisted file.
///
/// The boolean [snoozed] is set to `true` if the survey has been dismissed
/// temporarily by the user. When set to `false` this indicates that the survey
/// has been dismissed permanently and will not be shown to the user again.
class PersistedSurvey {
  final String uniqueId;
  final bool snoozed;
  final DateTime timestamp;

  PersistedSurvey({
    required this.uniqueId,
    required this.snoozed,
    required this.timestamp,
  });

  @override
  String toString() => jsonEncode({
        'uniqueId': uniqueId,
        'snoozed': snoozed,
        'timestamp': timestamp.toString(),
      });
}

class Survey {
  final String uniqueId;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final int snoozeForMinutes;
  final double samplingRate;
  final List<DashTool> excludeDashToolList;
  final List<Condition> conditionList;
  final List<SurveyButton> buttonList;

  /// A data class that contains the relevant information for a given
  /// survey parsed from the survey's metadata file.
  const Survey({
    required this.uniqueId,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.snoozeForMinutes,
    required this.samplingRate,
    required this.excludeDashToolList,
    required this.conditionList,
    required this.buttonList,
  });

  /// Parse the contents of the json metadata file hosted externally.
  Survey.fromJson(Map<String, dynamic> json)
      : uniqueId = json['uniqueId'] as String,
        startDate = DateTime.parse(json['startDate'] as String),
        endDate = DateTime.parse(json['endDate'] as String),
        description = json['description'] as String,
        // Handle both string and integer fields
        snoozeForMinutes = json['snoozeForMinutes'] is String
            ? int.parse(json['snoozeForMinutes'] as String)
            : json['snoozeForMinutes'] as int,
        // Handle both string and double fields
        samplingRate = json['samplingRate'] is String
            ? double.parse(json['samplingRate'] as String)
            : json['samplingRate'] as double,
        excludeDashToolList = (json['excludeDashTools'] as List<dynamic>)
            .map((e) => DashTool.fromLabel(e as String))
            .toList(),
        conditionList = (json['conditions'] as List<dynamic>).map((e) {
          return Condition.fromJson(e as Map<String, dynamic>);
        }).toList(),
        buttonList = (json['buttons'] as List<dynamic>).map((e) {
          return SurveyButton.fromJson(e as Map<String, dynamic>);
        }).toList();

  @override
  String toString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'uniqueId': uniqueId,
      'startDate': startDate.toString(),
      'endDate': endDate.toString(),
      'description': description,
      'snoozeForMinutes': snoozeForMinutes,
      'samplingRate': samplingRate,
      'conditionList': conditionList.map((e) => e.toMap()).toList(),
      'buttonList': buttonList.map((e) => e.toMap()).toList(),
    });
  }
}

class SurveyButton {
  final String buttonText;
  final String action;
  final bool promptRemainsVisible;
  final String? url;

  SurveyButton({
    required this.buttonText,
    required this.action,
    required this.promptRemainsVisible,
    this.url,
  });

  SurveyButton.fromJson(Map<String, dynamic> json)
      : buttonText = json['buttonText'] as String,
        action = json['action'] as String,
        promptRemainsVisible = json['promptRemainsVisible'] as bool,
        url = json['url'] as String?;

  Map<String, Object?> toMap() => <String, Object?>{
        'buttonText': buttonText,
        'action': action,
        'promptRemainsVisible': promptRemainsVisible,
        'url': url,
      };
}

class SurveyHandler {
  final File dismissedSurveyFile;

  SurveyHandler({required this.dismissedSurveyFile});

  /// Invoking this method will persist the survey's id in
  /// the local file with either a snooze or permanently dismissed
  /// indicator.
  ///
  /// In the snoozed state, the survey will be prompted again after
  /// the survey's specified snooze period.
  ///
  /// Each entry for a survey will have the following format:
  /// ```
  /// {
  ///   "survey-unique-id": {
  ///     "status": "snoozed",  // status is either snoozed or dismissed
  ///     "timestamp": 1690219834859
  ///   }
  /// }
  /// ```
  void dismiss(Survey survey, bool permanently) {
    final contents = _parseJsonFile();

    // Add the new data and write back out to the file
    final status = permanently ? 'dismissed' : 'snoozed';
    contents[survey.uniqueId] = {
      'status': status,
      'timestamp': clock.now().millisecondsSinceEpoch,
    };

    dismissedSurveyFile.writeAsStringSync(jsonEncode(contents));
  }

  /// Retrieve a list of strings for each [Survey] persisted on disk.
  ///
  /// The survey may be in a snoozed or dismissed state based on user action.
  Map<String, PersistedSurvey> fetchPersistedSurveys() {
    final contents = _parseJsonFile();

    // Initialize the list of persisted surveys and add to them
    // as they are being parsed
    final persistedSurveys = <String, PersistedSurvey>{};
    contents.forEach((key, value) {
      value as Map<String, dynamic>;

      final uniqueId = key;
      final snoozed = value['status'] == 'snoozed' ? true : false;
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(value['timestamp'] as int);

      persistedSurveys[uniqueId] = PersistedSurvey(
        uniqueId: uniqueId,
        snoozed: snoozed,
        timestamp: timestamp,
      );
    });

    return persistedSurveys;
  }

  /// Retrieves the survey metadata file from [kContextualSurveyUrl].
  Future<List<Survey>> fetchSurveyList() async {
    final List<dynamic> body;
    try {
      final payload = await _fetchContents();
      body = jsonDecode(payload) as List<dynamic>;
      // ignore: avoid_catches_without_on_clauses
    } catch (err) {
      return [];
    }

    final surveyList = parseSurveysFromJson(body);

    return surveyList;
  }

  /// Fetches the json in string form from the remote location.
  Future<String> _fetchContents() async {
    final uri = Uri.parse(kContextualSurveyUrl);
    final response = await http.get(uri);
    return response.body;
  }

  /// Method to return a Map representation of the json persisted file.
  Map<String, dynamic> _parseJsonFile() {
    Map<String, dynamic> contents;
    try {
      contents = jsonDecode(dismissedSurveyFile.readAsStringSync())
          as Map<String, dynamic>;
    } on FormatException {
      createDismissedSurveyFile(dismissedSurveyFile: dismissedSurveyFile);
      contents = {};
    } on FileSystemException {
      createDismissedSurveyFile(dismissedSurveyFile: dismissedSurveyFile);
      contents = {};
    }

    return contents;
  }

  /// Function to ensure that each survey is still valid by
  /// checking the [Survey.startDate] and [Survey.endDate]
  /// against the current [clock] now date.
  static bool checkSurveyDate(Survey survey) {
    final now = clock.now();
    return survey.startDate.isBefore(now) && survey.endDate.isAfter(now);
  }

  /// Function that takes in a json data structure that is in
  /// the form of a list and returns a list of [Survey] items.
  ///
  /// This will also check the survey's dates to make sure it
  /// has not expired.
  static List<Survey> parseSurveysFromJson(List<dynamic> body) => body
      .map((element) {
        // Error handling to skip any surveys from the remote location
        // that fail to parse
        try {
          return Survey.fromJson(element as Map<String, dynamic>);
          // ignore: avoid_catching_errors
        } on TypeError {
          return null;
        } on FormatException {
          return null;
        } on Exception {
          return null;
        }
      })
      .whereType<Survey>()
      .where(checkSurveyDate)
      .toList();
}

class FakeSurveyHandler extends SurveyHandler {
  final List<Survey> _fakeInitializedSurveys = [];

  /// Use this class in tests if you can provide the
  /// list of [Survey] objects.
  ///
  /// Important: the surveys in the [initializedSurveys] list
  /// will have their dates checked to ensure they are valid; it is
  /// recommended to use `package:clock` to set a fixed time for testing.
  FakeSurveyHandler.fromList({
    required super.dismissedSurveyFile,
    required List<Survey> initializedSurveys,
  }) {
    // We must pass the surveys from the list to the
    // `checkSurveyDate` function here and not for the
    // `.fromString()` constructor because the `parseSurveysFromJson`
    // method already checks their date
    for (final survey in initializedSurveys) {
      if (SurveyHandler.checkSurveyDate(survey)) {
        _fakeInitializedSurveys.add(survey);
      }
    }
  }

  /// Use this class in tests if you can provide raw
  /// json strings to simulate a response from a remote server.
  FakeSurveyHandler.fromString({
    required super.dismissedSurveyFile,
    required String content,
  }) {
    final body = jsonDecode(content) as List<dynamic>;
    for (final fakeSurvey in SurveyHandler.parseSurveysFromJson(body)) {
      _fakeInitializedSurveys.add(fakeSurvey);
    }
  }

  @override
  Future<List<Survey>> fetchSurveyList() =>
      Future<List<Survey>>.value(_fakeInitializedSurveys);

  @override
  Future<String> _fetchContents() => throw UnimplementedError();
}
