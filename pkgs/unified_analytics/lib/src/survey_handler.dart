// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

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
      : field = json['field'],
        operatorString = json['operator'],
        value = json['value'];

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
      : uniqueId = json['uniqueId'],
        url = json['url'],
        startDate = DateTime.parse(json['startDate']),
        endDate = DateTime.parse(json['endDate']),
        description = json['description'],
        // Handle both string and integer fields
        dismissForDays = json['dismissForDays'].runtimeType == String
            ? int.parse(json['dismissForDays'])
            : json['dismissForDays'],
        moreInfoUrl = json['moreInfoURL'],
        // Handle both string and double fields
        samplingRate = json['samplingRate'].runtimeType == String
            ? double.parse(json['samplingRate'])
            : json['samplingRate'],
        conditionList = (json['conditions'] as List)
            .map((e) => Condition.fromJson(e))
            .toList();

  @override
  String toString() {
    final JsonEncoder encoder = JsonEncoder.withIndent('  ');
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
  const SurveyHandler();

  /// Retrieves the survey metadata file from [kContextualSurveyUrl]
  Future<List<Survey>> fetchSurveyList() async {
    final List<dynamic> body;
    final Uri uri = Uri.parse(kContextualSurveyUrl);
    try {
      final http.Response response = await http.get(uri);
      body = jsonDecode(response.body) as List;
      // ignore: avoid_catches_without_on_clauses
    } catch (err) {
      return [];
    }

    final List<Survey> surveyList = body
        .map((element) {
          // Error handling to skip any surveys from the remote location
          // that fail to parse
          try {
            return Survey.fromJson(element);
            // ignore: avoid_catches_without_on_clauses
          } catch (err) {
            return null;
          }
        })
        .whereType<Survey>()
        .where((survey) => checkSurveyDate(survey))
        .toList();

    return surveyList;
  }
}

class FakeSurveyHandler implements SurveyHandler {
  final List<Survey> _fakeInitializedSurveys = [];

  /// Use this class in tests if you can provide the
  /// list of [Survey] objects
  FakeSurveyHandler({required List<Survey> initializedSurveys}) {
    for (final Survey survey in initializedSurveys) {
      if (checkSurveyDate(survey)) {
        _fakeInitializedSurveys.add(survey);
      }
    }
  }

  @override
  Future<List<Survey>> fetchSurveyList() =>
      Future<List<Survey>>.value(_fakeInitializedSurveys);
}
