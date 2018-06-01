// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/src/errors.dart';

part 'dependency.g.dart';

Map<String, Dependency> parseDeps(Map source) =>
    source?.map((k, v) {
      var key = k as String;
      var value = _fromJson(v);
      if (value == null) {
        throw new CheckedFromJsonException(
            source, key, 'Pubspec', 'Not a valid dependency value.');
      }
      return new MapEntry(key, value);
    }) ??
    {};

/// Returns `null` if the data could not be parsed.
Dependency _fromJson(dynamic data) {
  if (data == null) {
    return new HostedDependency(VersionConstraint.any);
  } else if (data is String) {
    return new HostedDependency(new VersionConstraint.parse(data));
  } else if (data is Map) {
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
  if (data.entries.isEmpty) {
// TODO: provide list of supported keys?
    throw new CheckedFromJsonException(
        data, null, 'Dependency', 'Must provide at least one key.');
  }

  if (data.containsKey('sdk')) {
    return new SdkDependency.fromData(data);
  }

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

class SdkDependency extends Dependency {
  final String name;
  final VersionConstraint version;

  SdkDependency(this.name, {this.version}) : super._();

  factory SdkDependency.fromData(Map data) {
    VersionConstraint version;
    if (data.containsKey('version')) {
      version = new VersionConstraint.parse(data['version'] as String);
    }
    return new SdkDependency(data['sdk'] as String, version: version);
  }

  @override
  String get _info => name;
}

@JsonSerializable(createToJson: false)
class GitDependency extends Dependency {
  @JsonKey(fromJson: _parseUri)
  final Uri url;
  final String ref;
  final String path;

  GitDependency(this.url, this.ref, this.path) : super._() {
    if (url == null) {
      throw new ArgumentError.value(url, 'url', '"url" cannot be null.');
    }
  }

  factory GitDependency.fromData(Object data) {
    if (data is String) {
      data = {'url': data};
    }

    if (data is Map) {
      // TODO: Need JsonKey.required
      // https://github.com/dart-lang/json_serializable/issues/216
      if (!data.containsKey('url')) {
        throw new BadKeyException(data, 'url', '"url" is required.');
      }

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

// TODO: support explicit host?
class HostedDependency extends Dependency {
  final VersionConstraint constraint;

  HostedDependency(this.constraint) : super._();

  @override
  String get _info => constraint.toString();
}
