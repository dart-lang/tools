// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
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

/// Converts [data] into a [Dependency] object.
///
/// If [data] is not a valid representation of a dependency,
/// returns null so that the parent logic can throw the proper error.
Dependency? _fromJson(Object? data, String name) {
  if (data is String || data == null) {
    return _$HostedDependencyFromJson({'version': data});
  }

  if (data is Map) {
    final matchedKeys = data.keys
        .cast<String>()
        .where((key) => key != 'version')
        .toList();

    if (data.isEmpty || (matchedKeys.isEmpty && data.containsKey('version'))) {
      return _$HostedDependencyFromJson(data);
    } else {
      final firstUnrecognizedKey = matchedKeys.firstWhereOrNull(
        (k) => !_sourceKeys.contains(k),
      );

      return $checkedNew<Dependency>('Dependency', data, () {
        if (firstUnrecognizedKey != null) {
          throw UnrecognizedKeysException(
            [firstUnrecognizedKey],
            data,
            _sourceKeys,
          );
        }
        if (matchedKeys.length > 1) {
          throw CheckedFromJsonException(
            data,
            matchedKeys[1],
            'Dependency',
            'A dependency may only have one source.',
          );
        }

        final key = matchedKeys.single;

        return switch (key) {
          'git' => GitDependency.fromData(
            data[key],
            version: _optionalConstraintFromData(data),
          ),
          'path' => PathDependency.fromData(data[key]),
          'sdk' => _$SdkDependencyFromJson(data),
          'hosted' => _$HostedDependencyFromJson(
            data,
          )..hosted?._nameOfPackage = name,
          _ => throw StateError('There is a bug in pubspec_parse.'),
        };
      });
    }
  }

  return null;
}

sealed class Dependency {
  /// Creates a JSON representation of the data of this object.
  Map<String, dynamic> toJson();
}

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

  @override
  Map<String, dynamic> toJson() => {'sdk': sdk, 'version': version.toString()};
}

@JsonSerializable()
class GitDependency extends Dependency {
  @JsonKey(fromJson: parseGitUri)
  final Uri url;
  final String? ref;
  final String? path;

  /// A pattern used to find version tagged commits in the repository.
  ///
  /// Must contain a single `{{version}}` marker, for example `v{{version}}`.
  /// Cannot be combined with [ref].
  ///
  /// See https://dart.dev/tools/pub/dependencies#git-packages.
  final String? tagPattern;

  /// The version constraint specified next to the `git` source.
  ///
  /// `null` if no constraint is specified, which pub treats as any version.
  /// This is mostly useful together with [tagPattern].
  @JsonKey(includeFromJson: false)
  final VersionConstraint? version;

  GitDependency(this.url, {this.ref, this.path, this.tagPattern, this.version});

  factory GitDependency.fromData(Object? data, {VersionConstraint? version}) {
    if (data is String) {
      data = {'url': data};
    }

    if (data is Map) {
      final parsed = _$GitDependencyFromJson(data);
      _validateTagPattern(data, parsed);
      return GitDependency(
        parsed.url,
        ref: parsed.ref,
        path: parsed.path,
        tagPattern: parsed.tagPattern,
        version: version,
      );
    }

    throw ArgumentError.value(data, 'git', 'Must be a String or a Map.');
  }

  static void _validateTagPattern(Map data, GitDependency parsed) {
    final tagPattern = parsed.tagPattern;
    if (tagPattern == null) {
      return;
    }
    if (tagPattern.split(_tagPatternVersionMarker).length != 2) {
      throw CheckedFromJsonException(
        data,
        'tag_pattern',
        'GitDependency',
        'Must contain a single "$_tagPatternVersionMarker".',
      );
    }
    if (parsed.ref != null) {
      throw CheckedFromJsonException(
        data,
        'tag_pattern',
        'GitDependency',
        'Cannot be used together with "ref".',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GitDependency &&
      other.url == url &&
      other.ref == ref &&
      other.path == path &&
      other.tagPattern == tagPattern &&
      other.version == version;

  @override
  int get hashCode => Object.hash(url, ref, path, tagPattern, version);

  @override
  String toString() => 'GitDependency: url@$url';

  @override
  Map<String, dynamic> toJson() => {
    'git': {
      'url': url.toString(),
      'ref': ?ref,
      'path': ?path,
      'tag_pattern': ?tagPattern,
    },
    'version': ?version?.toString(),
  };
}

const _tagPatternVersionMarker = '{{version}}';

Uri? _parseUriOrNull(String? value) => value == null ? null : Uri.parse(value);

Uri parseGitUri(String value) => _tryParseScpUri(value) ?? Uri.parse(value);

/// Supports URIs like `[user@]host.xz:path/to/repo.git/`
/// See https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a
Uri? _tryParseScpUri(String value) {
  final colonIndex = value.indexOf(':');

  if (colonIndex < 0) {
    return null;
  } else if (colonIndex == value.indexOf('://')) {
    // If the first colon is part of a scheme, it's not an scp-like URI
    return null;
  }
  final slashIndex = value.indexOf('/');

  if (slashIndex >= 0 && slashIndex < colonIndex) {
    // Per docs: This syntax is only recognized if there are no slashes before
    // the first colon. This helps differentiate a local path that contains a
    // colon. For example the local path foo:bar could be specified as an
    // absolute path or ./foo:bar to avoid being misinterpreted as an ssh url.
    return null;
  }

  final atIndex = value.indexOf('@');
  if (colonIndex > atIndex) {
    final user = atIndex >= 0 ? value.substring(0, atIndex) : null;
    final host = value.substring(atIndex + 1, colonIndex);
    final path = value.substring(colonIndex + 1);
    return Uri(scheme: 'ssh', userInfo: user, host: host, path: path);
  }
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

  @override
  Map<String, dynamic> toJson() => {'path': path};
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

  @override
  Map<String, dynamic> toJson() => {
    'version': version.toString(),
    if (hosted != null) 'hosted': hosted!.toJson(),
  };
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class HostedDetails {
  /// The name of the target dependency as declared in a `hosted` block.
  ///
  /// This may be null if no explicit name is present, for instance because the
  /// hosted dependency was declared as a string (`hosted: pub.example.org`).
  @JsonKey(name: 'name')
  final String? declaredName;

  @JsonKey(fromJson: _parseUriOrNull, disallowNullValue: true)
  final Uri? url;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? _nameOfPackage;

  /// The name of this package on the package repository.
  ///
  /// If this hosted block has a [declaredName], that one will be used.
  /// Otherwise, the name will be inferred from the surrounding package name.
  String get name => declaredName ?? _nameOfPackage!;

  HostedDetails(this.declaredName, this.url);

  factory HostedDetails.fromJson(Object data) {
    if (data is String) {
      data = {'url': data};
    }

    if (data is Map) {
      return _$HostedDetailsFromJson(data);
    }

    throw ArgumentError.value(data, 'hosted', 'Must be a Map or String.');
  }

  @override
  bool operator ==(Object other) =>
      other is HostedDetails && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);

  /// Creates a JSON representation of the data of this object.
  Map<String, dynamic> toJson() => {
    if (declaredName != null) 'name': declaredName,
    'url': url.toString(),
  };
}

VersionConstraint _constraintFromString(String? input) =>
    input == null ? VersionConstraint.any : VersionConstraint.parse(input);

VersionConstraint? _optionalConstraintFromData(Map data) {
  final value = data['version'];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw CheckedFromJsonException(
      data,
      'version',
      'GitDependency',
      '`$value` is not a String.',
    );
  }
  try {
    return VersionConstraint.parse(value);
  } on FormatException catch (e) {
    throw CheckedFromJsonException(data, 'version', 'GitDependency', e.message);
  }
}
