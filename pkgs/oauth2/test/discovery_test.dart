// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oauth2/src/discovery.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('discoverAuthorizationServerMetadata', () {
    test('discovers metadata using RFC 8414 well-known URI', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(
              request.url.toString(),
              equals(
                  'https://server.example.com/.well-known/oauth-authorization-server'));

          return Future.value(http.Response(
              jsonEncode({
                'issuer': 'https://server.example.com',
                'authorization_endpoint': 'https://server.example.com/auth',
                'token_endpoint': 'https://server.example.com/token',
                'response_types_supported': ['code'],
              }),
              200,
              headers: {'content-type': 'application/json'}));
        });

      var metadata = await discoverAuthorizationServerMetadata(
          Uri.parse('https://server.example.com'),
          httpClient: client);

      expect(metadata, isNotNull);
      expect(metadata!.issuer, equals('https://server.example.com'));
      expect(metadata.authorizationEndpoint,
          equals('https://server.example.com/auth'));
      expect(
          metadata.tokenEndpoint, equals('https://server.example.com/token'));
      expect(metadata.responseTypesSupported, equals(['code']));
    });

    test('falls back to OpenID Connect Discovery URI', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(
              request.url.toString(),
              equals(
                  'https://server.example.com/.well-known/oauth-authorization-server'));
          return Future.value(http.Response('', 404));
        })
        ..expectRequest((request) {
          expect(
              request.url.toString(),
              equals(
                  'https://server.example.com/.well-known/openid-configuration'));

          return Future.value(http.Response(
              jsonEncode({
                'issuer': 'https://server.example.com',
                'authorization_endpoint': 'https://server.example.com/auth',
                'token_endpoint': 'https://server.example.com/token',
                'response_types_supported': ['code'],
              }),
              200,
              headers: {'content-type': 'application/json'}));
        });

      var metadata = await discoverAuthorizationServerMetadata(
          Uri.parse('https://server.example.com'),
          httpClient: client);

      expect(metadata, isNotNull);
    });

    test('throws StateError on unexpected error', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          return Future.value(http.Response('', 500));
        });

      expect(
          discoverAuthorizationServerMetadata(
              Uri.parse('https://server.example.com'),
              httpClient: client),
          throwsStateError);
    });
  });

  group('discoverProtectedResourceMetadata', () {
    test('discovers metadata using RFC 9728 well-known URI', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(
              request.url.toString(),
              equals(
                  'https://resource.example.com/.well-known/oauth-protected-resource'));

          return Future.value(http.Response(
              jsonEncode({
                'resource': 'https://resource.example.com',
                'authorization_servers': ['https://server.example.com'],
                'scopes_supported': ['read', 'write'],
              }),
              200,
              headers: {'content-type': 'application/json'}));
        });

      var metadata = await discoverProtectedResourceMetadata(
          Uri.parse('https://resource.example.com'),
          httpClient: client);

      expect(metadata.resource, equals('https://resource.example.com'));
      expect(metadata.authorizationServers,
          equals(['https://server.example.com']));
      expect(metadata.scopesSupported, equals(['read', 'write']));
    });

    test('discovers metadata with path component', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          expect(
              request.url.toString(),
              equals(
                  'https://resource.example.com/.well-known/oauth-protected-resource/v1/api'));

          return Future.value(http.Response(
              jsonEncode({
                'resource': 'https://resource.example.com/v1/api',
                'authorization_servers': ['https://server.example.com'],
              }),
              200,
              headers: {'content-type': 'application/json'}));
        });

      var metadata = await discoverProtectedResourceMetadata(
          Uri.parse('https://resource.example.com/v1/api'),
          httpClient: client);

      expect(metadata.resource, equals('https://resource.example.com/v1/api'));
    });

    test('throws StateError for 404', () async {
      var client = ExpectClient()
        ..expectRequest((request) {
          return Future.value(http.Response('', 404));
        });

      expect(
          discoverProtectedResourceMetadata(
              Uri.parse('https://resource.example.com'),
              httpClient: client),
          throwsStateError);
    });
  });
}
