// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

class SurveyHandler {
  /// Contains metadata for each survey hosted at the [kContextualSurveyUrl]
  /// endpoint; if there are no surveys available, the list will remain empty
  final List<Map<String, Object?>> surveyList = [];

  SurveyHandler();

  /// Retrieves the survey metadata file from [kContextualSurveyUrl]
  Future<void> fetchSurveyList() async {
    final Uri uri = Uri.parse(kContextualSurveyUrl);
    final http.Response response = await http.get(uri);

    // Parse the returned body and add to the list
    print(jsonDecode(response.body));
  }
}
