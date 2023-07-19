// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'log_handler.dart';

/// Function to ensure that each survey is still valid by
/// checking the [Survey.startDate] and [Survey.endDate]
/// against the current [clock.now()] date
bool checkSurveyDate(Survey survey) {
  if (survey.startDate.isBefore(clock.now()) &&
      survey.endDate.isAfter(clock.now())) return true;

  return false;
}

/// Function that takes in a json data structure that is in
/// the form of a list and returns a list of [Survey]s
List<Survey> parseSurveysFromJson(List<dynamic> body) => body
    .map((element) {
      // Error handling to skip any surveys from the remote location
      // that fail to parse
      try {
        return Survey.fromJson(element as Map<String, dynamic>);
        // ignore: avoid_catches_without_on_clauses
      } catch (err) {
        return null;
      }
    })
    .whereType<Survey>()
    .where(checkSurveyDate)
    .toList();

class Condition {
  /// How to query the log file
  ///
  ///
  /// Example: logFileStats.recordCount refers to the
  /// total record count being returned by [LogFileStats]
  final String field;

  /// String representation of operator
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

  /// The value we will be comparing against using the [operatorString]
  final int value;

  /// One of the conditions that need to be valid for
  /// a survey to be returned to the user
  ///
  /// Example of raw json
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

class Survey {
  final String uniqueId;
  final String url;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final int dismissForDays;
  final String moreInfoUrl;
  final double samplingRate;
  final List<Condition> conditionList;

  Survey(
    this.uniqueId,
    this.url,
    this.startDate,
    this.endDate,
    this.description,
    this.dismissForDays,
    this.moreInfoUrl,
    this.samplingRate,
    this.conditionList,
  );

  /// Parse the contents of the json metadata file hosted externally
  Survey.fromJson(Map<String, dynamic> json)
      : uniqueId = json['uniqueId'] as String,
        url = json['url'] as String,
        startDate = DateTime.parse(json['startDate'] as String),
        endDate = DateTime.parse(json['endDate'] as String),
        description = json['description'] as String,
        // Handle both string and integer fields
        dismissForDays = json['dismissForDays'] is String
            ? int.parse(json['dismissForDays'] as String)
            : json['dismissForDays'] as int,
        moreInfoUrl = json['moreInfoURL'] as String,
        // Handle both string and double fields
        samplingRate = json['samplingRate'] is String
            ? double.parse(json['samplingRate'] as String)
            : json['samplingRate'] as double,
        conditionList = (json['conditions'] as List<dynamic>).map((e) {
          e as Map<String, dynamic>;
          return Condition.fromJson(e);
        }).toList();

  @override
  String toString() {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'uniqueId': uniqueId,
      'url': url,
      'startDate': startDate.toString(),
      'endDate': endDate.toString(),
      'description': description,
      'dismissForDays': dismissForDays,
      'moreInfoUrl': moreInfoUrl,
      'samplingRate': samplingRate,
      'conditionList': conditionList.map((e) => e.toMap()).toList(),
    });
  }
}

class SurveyHandler {
  final File _dismissedSurveyFile;

  SurveyHandler({
    required Directory homeDirectory,
    required FileSystem fs,
  }) : _dismissedSurveyFile = fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kDismissedSurveyFileName,
        ));

  /// Retrieves the survey metadata file from [kContextualSurveyUrl]
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

  /// Fetches the json in string form from the remote location
  Future<String> _fetchContents() async {
    final uri = Uri.parse(kContextualSurveyUrl);
    final response = await http.get(uri);
    return response.body;
  }

  /// Invoking this method will persist the survey's id in
  /// the local file containing dismissed survey ids to ensure that
  /// it won't be shown to the user again.
  void dismiss(Survey survey) =>
      _dismissedSurveyFile.writeAsStringSync('${survey.uniqueId}\n',
          mode: FileMode.writeOnlyAppend);

  /// Retrieve a list of strings for each dismissed [Survey] persisted on disk
  List<String> fetchDismissedSurveys() =>
      _dismissedSurveyFile.readAsLinesSync();
}

class FakeSurveyHandler implements SurveyHandler {
  @override
  final File _dismissedSurveyFile;
  final List<Survey> _fakeInitializedSurveys = [];

  /// Use this class in tests if you can provide the
  /// list of [Survey] objects
  ///
  /// Important: the surveys in the [initializedSurveys] list
  /// will have their dates checked to ensure they are valid; it is
  /// recommended to use `package:clock` to set a fixed time for testing
  FakeSurveyHandler.fromList({
    required Directory homeDirectory,
    required FileSystem fs,
    required List<Survey> initializedSurveys,
  }) : _dismissedSurveyFile = fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kDismissedSurveyFileName,
        )) {
    // We must pass the surveys from the list to the
    // `checkSurveyDate` function here and not for the
    // `.fromString()` constructor because the `parseSurveysFromJson`
    // method already checks their date
    for (final survey in initializedSurveys) {
      if (checkSurveyDate(survey)) {
        _fakeInitializedSurveys.add(survey);
      }
    }
  }

  /// Use this class in tests if you can provide raw
  /// json strings to mock a response from a remote server
  FakeSurveyHandler.fromString({
    required Directory homeDirectory,
    required FileSystem fs,
    required String content,
  }) : _dismissedSurveyFile = fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kDismissedSurveyFileName,
        )) {
    final body = jsonDecode(content) as List<dynamic>;
    for (final fakeSurvey in parseSurveysFromJson(body)) {
      _fakeInitializedSurveys.add(fakeSurvey);
    }
  }

  @override
  Future<List<Survey>> fetchSurveyList() =>
      Future<List<Survey>>.value(_fakeInitializedSurveys);

  @override
  Future<String> _fetchContents() => throw UnimplementedError();

  @override
  void dismiss(Survey survey) =>
      _dismissedSurveyFile.writeAsStringSync('${survey.uniqueId}\n',
          mode: FileMode.writeOnlyAppend);

  @override
  List<String> fetchDismissedSurveys() =>
      _dismissedSurveyFile.readAsLinesSync();
}
