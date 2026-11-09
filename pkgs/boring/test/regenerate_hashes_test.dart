// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert' show jsonEncode, utf8;
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:test/test.dart';

import '../tool/regenerate_hashes.dart';

void main() {
  group('resolveRemoteAssetHashes', () {
    test(
      'reads SHA-256 digests from the GitHub Releases API without downloading '
      'binaries',
      () async {
        var apiCalls = 0;
        var downloadCalls = 0;
        String? authHeader;
        final server = await _bindServer((request) async {
          if (request.uri.path == '/repos/dart-lang/tools/releases/tags/v1') {
            apiCalls++;
            authHeader = request.headers.value(HttpHeaders.authorizationHeader);
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'assets': [
                  {'name': 'asset-a.so', 'digest': 'sha256:$_hashA'},
                  {'name': 'asset-b.a', 'digest': 'sha256:$_hashB'},
                ],
              }),
            );
            await request.response.close();
            return;
          }
          downloadCalls++;
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        });

        final baseUri = _serverUri(server);
        final resolved = await resolveRemoteAssetHashes(
          repository: 'dart-lang/tools',
          tag: 'v1',
          assetNames: ['asset-a.so', 'asset-b.a', 'asset-missing.so'],
          apiBaseUri: baseUri,
          downloadBaseUri: baseUri,
          githubToken: 'test-token-123',
          delay: (_) async {},
        );

        expect(apiCalls, 1);
        expect(downloadCalls, 0);
        expect(authHeader, 'Bearer test-token-123');
        expect(resolved.hashes, {'asset-a.so': _hashA, 'asset-b.a': _hashB});
        expect(resolved.missing, ['asset-missing.so']);
      },
    );

    test(
      'falls back to downloading individual assets with retries when the API '
      'is rate-limited or an asset lacks a digest',
      () async {
        var downloadAttempts = 0;
        final server = await _bindServer((request) async {
          if (request.uri.path == '/repos/dart-lang/tools/releases/tags/v2') {
            request.response.statusCode = HttpStatus.forbidden;
            await request.response.close();
            return;
          }
          if (request.uri.path ==
              '/dart-lang/tools/releases/download/v2/asset-a.so') {
            downloadAttempts++;
            if (downloadAttempts == 1) {
              request.response.statusCode = HttpStatus.gatewayTimeout;
              await request.response.close();
              return;
            }
            request.response.add(_bytesA);
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });

        final delays = <Duration>[];
        final baseUri = _serverUri(server);
        final resolved = await resolveRemoteAssetHashes(
          repository: 'dart-lang/tools',
          tag: 'v2',
          assetNames: ['asset-a.so', 'asset-missing.so'],
          apiBaseUri: baseUri,
          downloadBaseUri: baseUri,
          delay: (duration) async => delays.add(duration),
        );

        expect(downloadAttempts, 2);
        expect(delays, [const Duration(seconds: 1)]);
        expect(resolved.hashes, {'asset-a.so': _hashA});
        expect(resolved.missing, ['asset-missing.so']);
      },
    );

    test('downloads only assets whose API metadata lacks a digest', () async {
      final downloadedPaths = <String>[];
      final server = await _bindServer((request) async {
        if (request.uri.path == '/repos/dart-lang/tools/releases/tags/v3') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'assets': [
                {'name': 'asset-a.so', 'digest': 'sha256:$_hashA'},
                {'name': 'asset-b.a', 'digest': null},
              ],
            }),
          );
          await request.response.close();
          return;
        }
        downloadedPaths.add(request.uri.path);
        request.response.add(_bytesB);
        await request.response.close();
      });

      final baseUri = _serverUri(server);
      final resolved = await resolveRemoteAssetHashes(
        repository: 'dart-lang/tools',
        tag: 'v3',
        assetNames: ['asset-a.so', 'asset-b.a'],
        apiBaseUri: baseUri,
        downloadBaseUri: baseUri,
        delay: (_) async {},
      );

      expect(downloadedPaths, [
        '/dart-lang/tools/releases/download/v3/asset-b.a',
      ]);
      expect(resolved.hashes, {'asset-a.so': _hashA, 'asset-b.a': _hashB});
      expect(resolved.missing, isEmpty);
    });

    test(
      'falls back immediately on API 429 and retries 429 on asset downloads',
      () async {
        var apiCalls = 0;
        var downloadAttempts = 0;
        final server = await _bindServer((request) async {
          if (request.uri.path == '/repos/dart-lang/tools/releases/tags/v4') {
            apiCalls++;
            request.response.statusCode = HttpStatus.tooManyRequests;
            await request.response.close();
            return;
          }
          if (request.uri.path ==
              '/dart-lang/tools/releases/download/v4/asset-a.so') {
            downloadAttempts++;
            if (downloadAttempts == 1) {
              request.response.statusCode = HttpStatus.tooManyRequests;
              await request.response.close();
              return;
            }
            request.response.add(_bytesA);
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });

        final delays = <Duration>[];
        final baseUri = _serverUri(server);
        final resolved = await resolveRemoteAssetHashes(
          repository: 'dart-lang/tools',
          tag: 'v4',
          assetNames: ['asset-a.so'],
          apiBaseUri: baseUri,
          downloadBaseUri: baseUri,
          delay: (duration) async => delays.add(duration),
        );

        expect(apiCalls, 1);
        expect(downloadAttempts, 2);
        expect(delays, [const Duration(seconds: 1)]);
        expect(resolved.hashes, {'asset-a.so': _hashA});
        expect(resolved.missing, isEmpty);
      },
    );
  });
}

final _bytesA = utf8.encode('alpha-binary-payload');
final _bytesB = utf8.encode('bravo-binary-payload');
final _hashA = sha256.convert(_bytesA).toString();
final _hashB = sha256.convert(_bytesB).toString();

Future<HttpServer> _bindServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen(handler);
  return server;
}

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');
