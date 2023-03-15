// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

class FakeGAClient implements GAClient {
  @override
  String get apiSecret => throw UnimplementedError();

  @override
  String get measurementId => throw UnimplementedError();

  @override
  String get postUrl => throw UnimplementedError();

  @override
  http.Client get _client => throw UnimplementedError();

  @override
  void close() {}

  @override
  Future<http.Response> sendData(Map<String, Object?> body) =>
      Future<http.Response>.value(http.Response('', 200));
}

class GAClient {
  final String measurementId;
  final String apiSecret;
  final String postUrl;
  final http.Client _client;

  GAClient({
    required this.measurementId,
    required this.apiSecret,
  })  : postUrl =
            '$kAnalyticsUrl?measurement_id=$measurementId&api_secret=$apiSecret',
        _client = http.Client();

  /// Closes the http client's connection to prevent lingering requests
  void close() => _client.close();

  /// Receive the payload in Map form and parse
  /// into JSON to send to GA
  Future<http.Response> sendData(Map<String, Object?> body) {
    return _client.post(
      Uri.parse(postUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );
  }
}
