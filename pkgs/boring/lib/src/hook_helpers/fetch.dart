// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show TimeoutException;
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:hooks/hooks.dart';

import 'hashes.dart' show fileHashes, releaseRepository, releaseTag;
import 'targets.dart'
    show libraryFileName, releaseAssetName, releaseAssetUrl, targetTripleFor;

/// Default timeout for opening a connection and receiving response headers.
const defaultConnectionTimeout = Duration(seconds: 30);

/// Default number of attempts (initial try + retries) for transient failures.
const defaultMaxAttempts = 4;

/// Default overall wall-clock deadline across all attempts and backoff sleeps.
const defaultTotalTimeout = Duration(minutes: 6);

/// How long to wait for a single response body to finish streaming.
const _downloadTimeout = Duration(minutes: 5);

/// Maximum `Retry-After` delay honored before clamping.
const _maxRetryAfter = Duration(seconds: 60);

const _checkoutHint =
    'To build boring locally from source instead, set '
    '`buildMode: checkout` in your pubspec.yaml under '
    '`hooks.user_defines.boring`.';

/// Downloads and verifies the pre-built library for the target of [input] from
/// the GitHub release [releaseTag] of [releaseRepository], caching it in
/// [HookInput.outputDirectoryShared].
///
/// Throws a [BuildError] if no hash is registered in [fileHashes] for the
/// target, if downloading fails, or if the downloaded file's SHA-256 checksum
/// does not match [fileHashes].
Future<Uri> fetchPrebuiltLibrary(
  HookInput input, {
  required bool static,
}) async {
  final targetOS = input.config.code.targetOS;
  final targetArch = input.config.code.targetArchitecture;
  final iosSdk = targetOS == OS.iOS ? input.config.code.iOS.targetSdk : null;

  final assetRemoteName = releaseAssetName(
    targetOS,
    targetArch,
    iosSdk: iosSdk,
    static: static,
  );
  final expectedHash = fileHashes[assetRemoteName];

  if (expectedHash == null || expectedHash.isEmpty) {
    final target = targetTripleFor(targetOS, targetArch, iosSdk: iosSdk);
    throw BuildError(
      message:
          'No prebuilt boring binary is available for $target '
          '($assetRemoteName) in release $releaseTag of $releaseRepository.\n'
          '$_checkoutHint',
    );
  }

  final fileName = libraryFileName(targetOS, static: static);
  final cachedFile = File.fromUri(
    input.outputDirectoryShared
        .resolve('$releaseTag/$assetRemoteName/')
        .resolve(fileName),
  );
  if (await cachedFile.exists()) {
    final cachedHash = sha256
        .convert(await cachedFile.readAsBytes())
        .toString();
    if (cachedHash == expectedHash) {
      stdout.writeln(
        'boring: using cached prebuilt binary ($assetRemoteName).',
      );
      return cachedFile.uri;
    }
  }

  final binaryUrl = releaseAssetUrl(
    repository: releaseRepository,
    tag: releaseTag,
    assetName: assetRemoteName,
  );
  stdout.writeln('boring: fetching prebuilt binary from $binaryUrl...');

  final bytes = await downloadBytes(binaryUrl);
  final actualHash = sha256.convert(bytes).toString();

  if (actualHash != expectedHash) {
    throw BuildError(
      message:
          'SHA256 hash mismatch for prebuilt binary $assetRemoteName.\n'
          'Expected: $expectedHash\n'
          'Actual:   $actualHash\n'
          '$_checkoutHint',
    );
  }

  stdout.writeln('boring: verified SHA256 checksum ($actualHash).');

  await cachedFile.parent.create(recursive: true);
  await cachedFile.writeAsBytes(bytes);
  return cachedFile.uri;
}

/// Downloads [url] with retries on transient HTTP (`408`, `429`, rate-limit
/// `403`, `5xx`), network, or timeout errors, or throws a [BuildError] if the
/// download fails.
///
/// Honors `HTTPS_PROXY` environment variables, `Retry-After` headers (capped at
/// 60s), and an overall [totalTimeout] across all attempts.
Future<List<int>> downloadBytes(
  Uri url, {
  int maxAttempts = defaultMaxAttempts,
  Duration totalTimeout = defaultTotalTimeout,
  Future<void> Function(Duration) delay = Future<void>.delayed,
  DateTime Function() now = DateTime.now,
}) async {
  final ({int statusCode, List<int> bytes}) response;
  try {
    response = await fetchHttpWithRetry(
      url,
      maxAttempts: maxAttempts,
      totalTimeout: totalTimeout,
      delay: delay,
      now: now,
    );
  } on HttpFetchException catch (e) {
    throw BuildError(message: '${e.message}\n$_checkoutHint');
  }
  if (response.statusCode != HttpStatus.ok) {
    throw BuildError(
      message:
          'Failed to download prebuilt boring binary from $url '
          '(HTTP ${response.statusCode}).\n$_checkoutHint',
    );
  }
  return response.bytes;
}

/// Sends a `GET` request to [url] with exponential-backoff retries on transient
/// HTTP (`408`, `429`, `403` responses carrying `Retry-After` or
/// `x-ratelimit-remaining: 0`, and `5xx`), network, or timeout errors.
///
/// Honors `Retry-After` headers (delay-seconds or HTTP-date, capped at 60s)
/// before falling back to `1s`, `2s`, `4s`, and enforces an overall
/// [totalTimeout] across all attempts. Returns the non-retryable HTTP status
/// and body bytes (`200` or permanent status codes such as `404`), or throws an
/// [HttpFetchException] when retries or [totalTimeout] are exhausted.
Future<({int statusCode, List<int> bytes})> fetchHttpWithRetry(
  Uri url, {
  HttpClient? client,
  int maxAttempts = defaultMaxAttempts,
  Duration totalTimeout = defaultTotalTimeout,
  Future<void> Function(Duration) delay = Future<void>.delayed,
  DateTime Function() now = DateTime.now,
  String logPrefix = 'boring: ',
}) async {
  assert(maxAttempts >= 1, 'maxAttempts must be at least 1.');
  final ownsClient = client == null;
  final effectiveClient =
      client ??
      (HttpClient()
        ..connectionTimeout = defaultConnectionTimeout
        ..findProxy = HttpClient.findProxyFromEnvironment);
  final stopwatch = Stopwatch()..start();
  try {
    return await _runFetchLoop(
      effectiveClient,
      url,
      maxAttempts: maxAttempts,
      totalTimeout: totalTimeout,
      stopwatch: stopwatch,
      delay: delay,
      now: now,
      logPrefix: logPrefix,
    );
  } finally {
    if (ownsClient) {
      effectiveClient.close(force: true);
    }
  }
}

Future<({int statusCode, List<int> bytes})> _runFetchLoop(
  HttpClient client,
  Uri url, {
  required int maxAttempts,
  required Duration totalTimeout,
  required Stopwatch stopwatch,
  required Future<void> Function(Duration) delay,
  required DateTime Function() now,
  required String logPrefix,
}) async {
  for (var attempt = 1; ; attempt++) {
    Duration remaining() => totalTimeout - stopwatch.elapsed;
    if (remaining() <= Duration.zero) {
      throw HttpFetchException(
        'Timed out downloading from $url after ${totalTimeout.inSeconds}s.',
      );
    }
    try {
      return await _sendOnce(client, url, remaining: remaining, now: now);
    } on _RetryableDownloadFailure catch (failure) {
      final backoff =
          failure.retryAfter ?? Duration(seconds: 1 << (attempt - 1));
      if (attempt >= maxAttempts || remaining() <= backoff) {
        throw HttpFetchException(failure.message);
      }
      stdout.writeln(
        '$logPrefix${failure.summary}; retrying in ${backoff.inSeconds}s '
        '(attempt ${attempt + 1} of $maxAttempts)...',
      );
      await delay(backoff);
    }
  }
}

/// Sends a single `GET` request to [url], capping each await by the time
/// [remaining] in the overall deadline so that [fetchHttpWithRetry]'s
/// `totalTimeout` is strict.
Future<({int statusCode, List<int> bytes})> _sendOnce(
  HttpClient client,
  Uri url, {
  required Duration Function() remaining,
  required DateTime Function() now,
}) async {
  Duration capped(Duration limit) => _minDuration(limit, remaining());
  try {
    final request = await client
        .getUrl(url)
        .timeout(capped(defaultConnectionTimeout));
    final response = await request.close().timeout(
      capped(defaultConnectionTimeout),
    );
    final statusCode = response.statusCode;
    if (_isRetryableStatus(statusCode, response.headers)) {
      final retryAfter = _parseRetryAfter(response.headers, now);
      await response.drain<void>().timeout(capped(defaultConnectionTimeout));
      throw _RetryableDownloadFailure(
        message: 'Failed to download from $url (HTTP $statusCode).',
        summary: 'HTTP $statusCode from $url',
        retryAfter: retryAfter,
      );
    }
    if (statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(capped(defaultConnectionTimeout));
      return (statusCode: statusCode, bytes: const <int>[]);
    }
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add).timeout(capped(_downloadTimeout));
    return (statusCode: statusCode, bytes: builder.takeBytes());
  } on IOException catch (e) {
    throw _RetryableDownloadFailure(
      message: 'Network error downloading from $url: $e',
      summary: 'network error from $url ($e)',
    );
  } on TimeoutException catch (e) {
    throw _RetryableDownloadFailure(
      message: 'Timed out downloading from $url: $e',
      summary: 'timeout from $url',
    );
  }
}

bool _isRetryableStatus(int statusCode, HttpHeaders headers) {
  if (statusCode == HttpStatus.requestTimeout ||
      statusCode == HttpStatus.tooManyRequests ||
      (statusCode >= 500 && statusCode < 600)) {
    return true;
  }
  if (statusCode == HttpStatus.forbidden) {
    // `headers[name]` instead of `headers.value(name)`, which throws an
    // `HttpException` (an `IOException`) on duplicate header lines.
    return (headers[HttpHeaders.retryAfterHeader]?.isNotEmpty ?? false) ||
        (headers['x-ratelimit-remaining']?.any((v) => v.trim() == '0') ??
            false);
  }
  return false;
}

Duration? _parseRetryAfter(HttpHeaders headers, DateTime Function() now) {
  final raw = headers[HttpHeaders.retryAfterHeader]?.firstOrNull?.trim();
  if (raw == null || raw.isEmpty) return null;
  final seconds = int.tryParse(raw);
  if (seconds != null) {
    return _clampRetryAfter(Duration(seconds: seconds));
  }
  try {
    return _clampRetryAfter(HttpDate.parse(raw).difference(now()));
  } on FormatException {
    return null;
  } on HttpException {
    return null;
  }
}

Duration _clampRetryAfter(Duration duration) {
  if (duration <= Duration.zero) return Duration.zero;
  return duration > _maxRetryAfter ? _maxRetryAfter : duration;
}

Duration _minDuration(Duration a, Duration b) => a <= b ? a : b;

/// Exception thrown by [fetchHttpWithRetry] when all retry attempts or the
/// overall deadline are exhausted.
final class HttpFetchException implements Exception {
  final String message;

  const HttpFetchException(this.message);

  @override
  String toString() => message;
}

final class _RetryableDownloadFailure implements Exception {
  final String message;
  final String summary;
  final Duration? retryAfter;

  const _RetryableDownloadFailure({
    required this.message,
    required this.summary,
    this.retryAfter,
  });
}
