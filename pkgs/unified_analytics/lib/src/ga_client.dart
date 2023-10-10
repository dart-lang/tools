// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

class FakeGAClient implements GAClient {
  const FakeGAClient();

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
  })  : postUrl = '$kAnalyticsUrl?'
            'measurement_id=$measurementId&api_secret=$apiSecret',
        _client = http.Client();

  /// Closes the http client's connection to prevent lingering requests.
  void close() => _client.close();

  /// Receive the payload in Map form and parse
  /// into JSON to send to GA.
  ///
  /// The [http.Response] returned from this method can be
  /// checked to ensure that events have been sent. A response
  /// status code of `2xx` indicates a successful send event.
  /// A response status code of `500` indicates an error occured on the send
  /// can the error message can be found in the [http.Response.body].
  Future<http.Response> sendData(Map<String, Object?> body) async {
    final uri = Uri.parse(postUrl);

    // Using a try catch all since post method can result in several
    // errors; clients using this method can check the awaited status
    // code to get a specific error message if the status code returned
    // is a 500 error status code
    try {
      return await _client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return Future<http.Response>.value(
        http.Response(
          error.toString(),
          500,
          headers: <String, String>{
            'content-type': 'text/plain; charset=utf-8',
          },
        ),
      );
    }
  }
}
