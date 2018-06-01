// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'dependency.dart';
import 'errors.dart';

part 'pubspec.g.dart';

@JsonSerializable(createToJson: false)
class Pubspec {
  final String name;

  @JsonKey(fromJson: _versionFromString)
  final Version version;

  final String description;
  final String homepage;

  /// If there is exactly 1 value in [authors], returns it.
  ///
  /// If there are 0 or more than 1, returns `null`.
  @Deprecated(
      'Here for completeness, but not recommended. Use `authors` instead.')
  String get author {
    if (authors.length == 1) {
      return authors.single;
    }
    return null;
  }

  final List<String> authors;
  final String documentation;

  @JsonKey(fromJson: _environmentMap)
  final Map<String, VersionConstraint> environment;

  @JsonKey(fromJson: _getDeps, nullable: false)
  final Map<String, Dependency> dependencies;

  @JsonKey(name: 'dev_dependencies', fromJson: _getDeps, nullable: false)
  final Map<String, Dependency> devDependencies;

  @JsonKey(name: 'dependency_overrides', fromJson: _getDeps, nullable: false)
  final Map<String, Dependency> dependencyOverrides;

  /// If [author] and [authors] are both provided, their values are combined
  /// with duplicates eliminated.
  Pubspec(
    this.name, {
    this.version,
    String author,
    List<String> authors,
    this.environment,
    this.homepage,
    this.documentation,
    this.description,
    Map<String, Dependency> dependencies,
    Map<String, Dependency> devDependencies,
    Map<String, Dependency> dependencyOverrides,
  })  : this.authors = _normalizeAuthors(author, authors),
        this.dependencies = dependencies ?? const {},
        this.devDependencies = devDependencies ?? const {},
        this.dependencyOverrides = dependencyOverrides ?? const {} {
    if (name == null || name.isEmpty) {
      throw new ArgumentError.value(name, 'name', '"name" cannot be empty.');
    }
  }

  factory Pubspec.fromJson(Map json) => _$PubspecFromJson(json);

  static List<String> _normalizeAuthors(String author, List<String> authors) {
    var value = new Set<String>();
    if (author != null) {
      value.add(author);
    }
    if (authors != null) {
      value.addAll(authors);
    }
    return value.toList();
  }
}

// TODO: maybe move this to `dependencies.dart`?
Map<String, Dependency> _getDeps(Map source) =>
    source?.map((k, v) {
      var key = k as String;
      var value = new Dependency.fromJson(v);
      if (value == null) {
        throw new CheckedFromJsonException(
            source, key, 'Pubspec', 'Not a valid dependency value.');
      }
      return new MapEntry(key, value);
    }) ??
    {};

Version _versionFromString(String input) => new Version.parse(input);

Map<String, VersionConstraint> _environmentMap(Map source) =>
    source.map((key, value) {
      if (key == 'dart') {
        // github.com/dart-lang/pub/blob/d84173eeb03c3/lib/src/pubspec.dart#L342
        // 'dart' is not allowed as a key!
        throw new BadKeyException(
            source, 'dart', 'Use "sdk" to for Dart SDK constraints.');
      }

      VersionConstraint constraint;
      try {
        constraint = new VersionConstraint.parse(value as String);
      } on FormatException catch (e) {
        throw new CheckedFromJsonException(
            source, key as String, 'Pubspec', e.message);
      }

      return new MapEntry(key as String, constraint);
    });
