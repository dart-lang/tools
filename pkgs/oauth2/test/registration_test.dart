// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oauth2/src/authorization_exception.dart';
import 'package:oauth2/src/discovery.dart';
import 'package:oauth2/src/registration.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('registerClient', () {
    test('registers successfully with authorization server URL', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(request.url.toString(),
              equals('https://server.example.com/register'));
          expect(request.headers['content-type'], equals('application/json'));

          var body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_name'], equals('My App'));
          expect(body['redirect_uris'], equals(['app://callback']));

          return Future.value(http.Response(
              jsonEncode({
                'client_id': 's6BhdRkqt3',
                'client_secret': 'cf4c9Z7hO3',
                'client_id_issued_at': 2893256800,
                'client_secret_expires_at': 2893276800,
              }),
              201,
              headers: {'content-type': 'application/json'}));
        });

      var metadata = const OAuthClientMetadata(
          clientName: 'My App', redirectUris: ['app://callback']);
      var info = await registerClient(
          Uri.parse('https://server.example.com'), metadata,
          httpClient: client);

      expect(info.clientId, equals('s6BhdRkqt3'));
      expect(info.clientSecret, equals('cf4c9Z7hO3'));
      expect(info.clientIdIssuedAt, equals(2893256800));
      expect(info.clientSecretExpiresAt, equals(2893276800));
    });

    test('registers successfully using metadata registration_endpoint',
        () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(request.url.toString(),
              equals('https://server.example.com/api/v1/register'));

          return Future.value(http.Response(
              jsonEncode({
                'client_id': 's6BhdRkqt3',
              }),
              201,
              headers: {'content-type': 'application/json'}));
        });

      var serverMetadata = const OAuthServerMetadata(
          issuer: 'https://server.example.com',
          authorizationEndpoint: 'https://server.example.com/auth',
          tokenEndpoint: 'https://server.example.com/token',
          responseTypesSupported: ['code'],
          registrationEndpoint: 'https://server.example.com/api/v1/register');

      var metadata =
          const OAuthClientMetadata(redirectUris: ['app://callback']);
      var info = await registerClient(
          Uri.parse('https://server.example.com'), metadata,
          metadata: serverMetadata, httpClient: client);

      expect(info.clientId, equals('s6BhdRkqt3'));
    });

    test('throws AuthorizationException on error response', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          return Future.value(http.Response(
              jsonEncode({
                'error': 'invalid_redirect_uri',
                'error_description': 'The redirect_uri is not allowed.'
              }),
              400,
              headers: {'content-type': 'application/json'}));
        });

      var metadata =
          const OAuthClientMetadata(redirectUris: ['app://callback']);

      expect(
          registerClient(Uri.parse('https://server.example.com'), metadata,
              httpClient: client),
          throwsA(isA<AuthorizationException>().having(
              (e) => e.error, 'error', equals('invalid_redirect_uri'))));
    });

    test('throws StateError on unexpected status code without JSON', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          return Future.value(http.Response('Internal Server Error', 500));
        });

      var metadata =
          const OAuthClientMetadata(redirectUris: ['app://callback']);

      expect(
          registerClient(Uri.parse('https://server.example.com'), metadata,
              httpClient: client),
          throwsStateError);
    });

    test('throws ArgumentError on insecure authorizationServerUrl', () async {
      var metadata =
          const OAuthClientMetadata(redirectUris: ['app://callback']);
      expect(
          () =>
              registerClient(Uri.parse('http://server.example.com'), metadata),
          throwsArgumentError);
    });

    test('throws ArgumentError on insecure metadata registration_endpoint',
        () async {
      var serverMetadata = const OAuthServerMetadata(
          issuer: 'https://server.example.com',
          authorizationEndpoint: 'https://server.example.com/auth',
          tokenEndpoint: 'https://server.example.com/token',
          responseTypesSupported: ['code'],
          registrationEndpoint: 'http://server.example.com/api/v1/register');
      var metadata =
          const OAuthClientMetadata(redirectUris: ['app://callback']);
      expect(
          () => registerClient(
              Uri.parse('https://server.example.com'), metadata,
              metadata: serverMetadata),
          throwsArgumentError);
    });
  });
}
