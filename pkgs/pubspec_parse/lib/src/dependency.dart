// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'errors.dart';

part 'dependency.g.dart';

Map<String, Dependency> parseDeps(Map source) =>
    source?.map((k, v) {
      var key = k as String;
      Dependency value;
      try {
        value = _fromJson(v);
      } on CheckedFromJsonException catch (e) {
        if (e.map is! YamlMap) {
          // This is likely a "synthetic" map created from a String value
          // Use `source` to throw this exception with an actual YamlMap and
          // extract the associated error information.

          var message = e.message;
          var innerError = e.innerError;
          // json_annotation should handle FormatException...
          // https://github.com/dart-lang/json_serializable/issues/233
          if (innerError is FormatException) {
            message = innerError.message;
          }
          throw new CheckedFromJsonException(source, key, e.className, message);
        }
        rethrow;
      }

      if (value == null) {
        throw new CheckedFromJsonException(
            source, key, 'Pubspec', 'Not a valid dependency value.');
      }
      return new MapEntry(key, value);
    }) ??
    {};

const _sourceKeys = const ['sdk', 'git', 'path', 'hosted'];

/// Returns `null` if the data could not be parsed.
Dependency _fromJson(dynamic data) {
  if (data is String || data == null) {
    return _$HostedDependencyFromJson({'version': data});
  }

  if (data is Map) {
    var matchedKeys =
        data.keys.cast<String>().where((key) => key != 'version').toList();

    if (data.isEmpty || (matchedKeys.isEmpty && data.containsKey('version'))) {
      return _$HostedDependencyFromJson(data);
    } else {
      var weirdKey = matchedKeys.firstWhere((k) => !_sourceKeys.contains(k),
          orElse: () => null);

      if (weirdKey != null) {
        throw new InvalidKeyException(
            data, weirdKey, 'Unsupported dependency key.');
      }
      if (matchedKeys.length > 1) {
        throw new CheckedFromJsonException(data, matchedKeys[1], 'Dependency',
            'A dependency may only have one source.');
      }

      var key = matchedKeys.single;

      try {
        switch (key) {
          case 'git':
            return new GitDependency.fromData(data[key]);
          case 'path':
            return new PathDependency.fromData(data[key]);
          case 'sdk':
            return _$SdkDependencyFromJson(data);
          case 'hosted':
            return _$HostedDependencyFromJson(data);
        }
        throw new StateError('There is a bug in pubspec_parse.');
      } on ArgumentError catch (e) {
        throw new CheckedFromJsonException(
            data, e.name, 'Dependency', e.message.toString());
      }
    }
  }

  // Not a String or a Map – return null so parent logic can throw proper error
  return null;
}

abstract class Dependency {
  Dependency._();

  String get _info;

  @override
  String toString() => '$runtimeType: $_info';
}

@JsonSerializable(createToJson: false)
class SdkDependency extends Dependency {
  @JsonKey(nullable: false, disallowNullValue: true, required: true)
  final String sdk;
  @JsonKey(fromJson: _constraintFromString)
  final VersionConstraint version;

  SdkDependency(this.sdk, {this.version}) : super._();

  @override
  String get _info => sdk;
}

@JsonSerializable(createToJson: false)
class GitDependency extends Dependency {
  @JsonKey(fromJson: parseGitUri, required: true, disallowNullValue: true)
  final Uri url;
  final String ref;
  final String path;

  GitDependency(this.url, this.ref, this.path) : super._();

  factory GitDependency.fromData(Object data) {
    if (data is String) {
      data = {'url': data};
    }

    if (data is Map) {
      return _$GitDependencyFromJson(data);
    }

    throw new ArgumentError.value(data, 'git', 'Must be a String or a Map.');
  }

  @override
  String get _info => 'url@$url';
}

Uri parseGitUri(String value) => _tryParseScpUri(value) ?? Uri.parse(value);

/// Supports URIs like `[user@]host.xz:path/to/repo.git/`
/// See https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a
Uri _tryParseScpUri(String value) {
  var colonIndex = value.indexOf(':');

  if (colonIndex < 0) {
    return null;
  } else if (colonIndex == value.indexOf('://')) {
    // If the first colon is part of a scheme, it's not an scp-like URI
    return null;
  }
  var slashIndex = value.indexOf('/');

  if (slashIndex >= 0 && slashIndex < colonIndex) {
    // Per docs: This syntax is only recognized if there are no slashes before
    // the first colon. This helps differentiate a local path that contains a
    // colon. For example the local path foo:bar could be specified as an
    // absolute path or ./foo:bar to avoid being misinterpreted as an ssh url.
    return null;
  }

  var atIndex = value.indexOf('@');
  if (colonIndex > atIndex) {
    var user = atIndex >= 0 ? value.substring(0, atIndex) : null;
    var host = value.substring(atIndex + 1, colonIndex);
    var path = value.substring(colonIndex + 1);
    return new Uri(scheme: 'ssh', userInfo: user, host: host, path: path);
  }
  return null;
}

class PathDependency extends Dependency {
  final String path;

  PathDependency(this.path) : super._();

  factory PathDependency.fromData(Object data) {
    if (data is String) {
      return new PathDependency(data);
    }
    throw new ArgumentError.value(data, 'path', 'Must be a String.');
  }

  @override
  String get _info => 'path@$path';
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class HostedDependency extends Dependency {
  @JsonKey(fromJson: _constraintFromString)
  final VersionConstraint version;

  @JsonKey(disallowNullValue: true)
  final HostedDetails hosted;

  HostedDependency({VersionConstraint version, this.hosted})
      : version = version ?? VersionConstraint.any,
        super._();

  @override
  String get _info => version.toString();
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class HostedDetails {
  @JsonKey(required: true, disallowNullValue: true)
  final String name;

  @JsonKey(fromJson: parseGitUri, disallowNullValue: true)
  final Uri url;

  HostedDetails(this.name, this.url);

  factory HostedDetails.fromJson(Object data) {
    if (data is String) {
      data = {'name': data};
    }

    if (data is Map) {
      return _$HostedDetailsFromJson(data);
    }

    throw new ArgumentError.value(data, 'hosted', 'Must be a Map or String.');
  }
}

VersionConstraint _constraintFromString(String input) =>
    new VersionConstraint.parse(input);
