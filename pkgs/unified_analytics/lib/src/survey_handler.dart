// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'log_handler.dart';

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
  final String operatorString;

  /// The value we will be comparing against using the [operatorString]
  final int value;

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
        dismissForDays = int.parse(json['dismissForDays']),
        moreInfoUrl = json['moreInfoURL'],
        samplingRate = double.parse(json['samplingRate']),
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
    final Uri uri = Uri.parse(kContextualSurveyUrl);
    final http.Response response = await http.get(uri);

    final List<Survey> surveyList = (jsonDecode(response.body) as List)
        .map(
          (e) => Survey.fromJson(e),
        )
        .toList();

    return surveyList;
  }
}

class FakeSurveyHandler implements SurveyHandler {
  final List<Survey> _fakeInitializedSurveys;

  /// Use this class in tests if you can provide the
  /// list of [Survey] objects
  FakeSurveyHandler({required List<Survey>? initializedSurveys})
      : _fakeInitializedSurveys = initializedSurveys ?? [];

  @override
  Future<List<Survey>> fetchSurveyList() =>
      Future<List<Survey>>.value(_fakeInitializedSurveys);
}
