// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

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

/// Returns `null` if the data could not be parsed.
Dependency _fromJson(dynamic data) {
  var value =
      SdkDependency.tryFromData(data) ?? HostedDependency.tryFromData(data);

  if (value != null) {
    return value;
  }

  if (data is Map) {
    try {
      return _fromMap(data);
    } on ArgumentError catch (e) {
      throw new CheckedFromJsonException(
          data, e.name, 'Dependency', e.message.toString());
    }
  }

  return null;
}

Dependency _fromMap(Map data) {
  assert(data.entries.isNotEmpty);
  if (data.entries.length > 1) {
    throw new CheckedFromJsonException(data, data.keys.skip(1).first as String,
        'Dependency', 'Expected only one key.');
  }

  var entry = data.entries.single;
  var key = entry.key as String;

  if (entry.value == null) {
    throw new CheckedFromJsonException(
        data, key, 'Dependency', 'Cannot be null.');
  }

  switch (key) {
    case 'path':
      return new PathDependency.fromData(entry.value);
    case 'git':
      return new GitDependency.fromData(entry.value);
  }

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
  final String sdk;
  @JsonKey(fromJson: _constraintFromString)
  final VersionConstraint version;

  SdkDependency(this.sdk, {this.version}) : super._();

  static SdkDependency tryFromData(Object data) {
    if (data is Map && data.containsKey('sdk')) {
      return _$SdkDependencyFromJson(data);
    }
    return null;
  }

  @override
  String get _info => sdk;
}

@JsonSerializable(createToJson: false)
class GitDependency extends Dependency {
  @JsonKey(fromJson: _parseUri, required: true, disallowNullValue: true)
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

Uri _parseUri(String value) => Uri.parse(value);

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
      : this.version = version ?? VersionConstraint.any,
        super._();

  static HostedDependency tryFromData(Object data) {
    if (data == null || data is String) {
      data = {'version': data};
    }

    if (data is Map) {
      if (data.isEmpty ||
          data.containsKey('version') ||
          data.containsKey('hosted')) {
        return _$HostedDependencyFromJson(data);
      }
    }

    return null;
  }

  @override
  String get _info => version.toString();
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class HostedDetails {
  @JsonKey(required: true, disallowNullValue: true)
  final String name;

  @JsonKey(fromJson: _parseUri, disallowNullValue: true)
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
