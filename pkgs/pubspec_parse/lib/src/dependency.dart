// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

part 'dependency.g.dart';

Map<String, Dependency> parseDeps(Map? source) =>
    source?.map((k, v) {
      final key = k as String;
      Dependency? value;
      try {
        value = _fromJson(v, k);
      } on CheckedFromJsonException catch (e) {
        if (e.map is! YamlMap) {
          // This is likely a "synthetic" map created from a String value
          // Use `source` to throw this exception with an actual YamlMap and
          // extract the associated error information.
          throw CheckedFromJsonException(source, key, e.className!, e.message);
        }
        rethrow;
      }

      if (value == null) {
        throw CheckedFromJsonException(
          source,
          key,
          'Pubspec',
          'Not a valid dependency value.',
        );
      }
      return MapEntry(key, value);
    }) ??
    {};

const _sourceKeys = ['sdk', 'git', 'path', 'hosted'];

/// Returns `null` if the data could not be parsed.
Dependency? _fromJson(Object? data, String name) {
  if (data is String || data == null) {
    return _$HostedDependencyFromJson({'version': data});
  }

  if (data is Map) {
    String? matchedKey;
    String? secondMatchedKey;
    String? firstUnrecognizedKey;
    for (final (key as String) in data.keys) {
      if (key == 'version') continue;
      if (matchedKey == null) {
        matchedKey = key;
      } else {
        secondMatchedKey ??= key;
      }
      if (!_sourceKeys.contains(key)) {
        firstUnrecognizedKey ??= key;
      }
    }

    if (matchedKey == null) {
      return _$HostedDependencyFromJson(data);
    } else {
      return $checkedNew<Dependency>('Dependency', data, () {
        if (firstUnrecognizedKey != null) {
          throw UnrecognizedKeysException(
            [firstUnrecognizedKey],
            data,
            _sourceKeys,
          );
        }
        if (secondMatchedKey != null) {
          throw CheckedFromJsonException(
            data,
            secondMatchedKey,
            'Dependency',
            'A dependency may only have one source.',
          );
        }

        return switch (matchedKey) {
          'git' => GitDependency.fromData(data[matchedKey]),
          'path' => PathDependency.fromData(data[matchedKey]),
          'sdk' => _$SdkDependencyFromJson(data),
          'hosted' => _$HostedDependencyFromJson(
            data,
          )..hosted?._nameOfPackage = name,
          _ => throw StateError('There is a bug in pubspec_parse.'),
        };
      });
    }
  }

  // Not a String or a Map – return null so parent logic can throw proper error
  return null;
}

sealed class Dependency {}

@JsonSerializable()
class SdkDependency extends Dependency {
  final String sdk;
  @JsonKey(fromJson: _constraintFromString)
  final VersionConstraint version;

  SdkDependency(this.sdk, {VersionConstraint? version})
    : version = version ?? VersionConstraint.any;

  @override
  bool operator ==(Object other) =>
      other is SdkDependency && other.sdk == sdk && other.version == version;

  @override
  int get hashCode => Object.hash(sdk, version);

  @override
  String toString() => 'SdkDependency: $sdk';
}

@JsonSerializable()
class GitDependency extends Dependency {
  @JsonKey(fromJson: parseGitUri)
  final Uri url;
  final String? ref;
  final String? path;

  GitDependency(this.url, {this.ref, this.path});

  factory GitDependency.fromData(Object? data) =>
      _$GitDependencyFromJson(_mapOrStringUri(data, 'git'));

  @override
  bool operator ==(Object other) =>
      other is GitDependency &&
      other.url == url &&
      other.ref == ref &&
      other.path == path;

  @override
  int get hashCode => Object.hash(url, ref, path);

  @override
  String toString() => 'GitDependency: url@$url';
}

Uri? parseGitUriOrNull(String? value) =>
    value == null ? null : parseGitUri(value);

Uri parseGitUri(String value) => _tryParseScpUri(value) ?? Uri.parse(value);

/// Parses URIs like `[user@]host.xz:path/to/repo.git/`.
/// See https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a
Uri? _tryParseScpUri(String value) {
  // Find first `:`. Remember `@` before it, reject if `/` before it.
  const slashChar = 0x2F, colonChar = 0x3A, atChar = 0x40;
  var atIndex = -1;
  for (var i = 0; i < value.length; i++) {
    final char = value.codeUnitAt(i);
    if (char == slashChar) {
      // Per docs: This syntax is only recognized if there are no slashes
      // before the first colon. This helps differentiate a local path that
      // contains a colon. For example the local path foo:bar could
      // be specified as an absolute path or ./foo:bar to avoid being
      // misinterpreted as an SSH URL
      break;
    } else if (char == atChar) {
      atIndex = i;
    } else if (char == colonChar) {
      final colonIndex = i;

      // Assume a `://` means it's a real URI scheme and authority,
      // not an SCP-like URI.
      if (value.startsWith('//', colonIndex + 1)) return null;

      final user = atIndex >= 0 ? value.substring(0, atIndex) : null;
      final host = value.substring(atIndex + 1, colonIndex);
      final path = value.substring(colonIndex + 1);
      return Uri(scheme: 'ssh', userInfo: user, host: host, path: path);
    }
  }
  // No colon in value, or not before a slash.
  return null;
}

class PathDependency extends Dependency {
  final String path;

  PathDependency(this.path);

  factory PathDependency.fromData(Object? data) {
    if (data is String) {
      return PathDependency(data);
    }
    throw ArgumentError.value(data, 'path', 'Must be a String.');
  }

  @override
  bool operator ==(Object other) =>
      other is PathDependency && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'PathDependency: path@$path';
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class HostedDependency extends Dependency {
  @JsonKey(fromJson: _constraintFromString)
  final VersionConstraint version;

  @JsonKey(disallowNullValue: true)
  final HostedDetails? hosted;

  HostedDependency({VersionConstraint? version, this.hosted})
    : version = version ?? VersionConstraint.any;

  @override
  bool operator ==(Object other) =>
      other is HostedDependency &&
      other.version == version &&
      other.hosted == hosted;

  @override
  int get hashCode => Object.hash(version, hosted);

  @override
  String toString() => 'HostedDependency: $version';
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class HostedDetails {
  /// The name of the target dependency as declared in a `hosted` block.
  ///
  /// This may be null if no explicit name is present, for instance because the
  /// hosted dependency was declared as a string (`hosted: pub.example.org`).
  @JsonKey(name: 'name')
  final String? declaredName;

  @JsonKey(fromJson: parseGitUriOrNull, disallowNullValue: true)
  final Uri? url;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? _nameOfPackage;

  /// The name of this package on the package repository.
  ///
  /// If this hosted block has a [declaredName], that one will be used.
  /// Otherwise, the name will be inferred from the surrounding package name.
  String get name => declaredName ?? _nameOfPackage!;

  HostedDetails(this.declaredName, this.url);

  factory HostedDetails.fromJson(Object data) =>
      _$HostedDetailsFromJson(_mapOrStringUri(data, 'hosted'));

  @override
  bool operator ==(Object other) =>
      other is HostedDetails && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);
}

VersionConstraint _constraintFromString(String? input) =>
    input == null ? VersionConstraint.any : VersionConstraint.parse(input);

/// The `value` if it is a `Map`, or `{'url': value}` if `calue` is a `String`.
///
/// The `value` must be iether a map or a string.
/// The [name] is used as the parameter name in an error if the value
/// is not one of the allowed types.
Map _mapOrStringUri(Object? value, String name) => switch (value) {
  Map() => value,
  String() => {'url': value},
  _ => throw ArgumentError.value(value, name, 'Must be a String or a Map.'),
};
