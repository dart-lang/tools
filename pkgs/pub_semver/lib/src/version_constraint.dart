// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pub_semver.src.version_constraint;

import 'patterns.dart';
import 'version.dart';
import 'version_range.dart';

/// A [VersionConstraint] is a predicate that can determine whether a given
/// version is valid or not.
///
/// For example, a ">= 2.0.0" constraint allows any version that is "2.0.0" or
/// greater. Version objects themselves implement this to match a specific
/// version.
abstract class VersionConstraint {
  /// A [VersionConstraint] that allows all versions.
  static VersionConstraint any = new VersionRange();

  /// A [VersionConstraint] that allows no versions -- the empty set.
  static VersionConstraint empty = const _EmptyVersion();

  /// Parses a version constraint.
  ///
  /// This string is either "any" or a series of version parts. Each part can
  /// be one of:
  ///
  ///   * A version string like `1.2.3`. In other words, anything that can be
  ///     parsed by [Version.parse()].
  ///   * A comparison operator (`<`, `>`, `<=`, or `>=`) followed by a version
  ///     string.
  ///
  /// Whitespace is ignored.
  ///
  /// Examples:
  ///
  ///     any
  ///     1.2.3-alpha
  ///     <=5.1.4
  ///     >2.0.4 <= 2.4.6
  factory VersionConstraint.parse(String text) {
    // Handle the "any" constraint.
    if (text.trim() == "any") return new VersionRange();

    var originalText = text;
    var constraints = [];

    skipWhitespace() {
      text = text.trim();
    }

    // Try to parse and consume a version number.
    matchVersion() {
      var version = START_VERSION.firstMatch(text);
      if (version == null) return null;

      text = text.substring(version.end);
      return new Version.parse(version[0]);
    }

    // Try to parse and consume a comparison operator followed by a version.
    matchComparison() {
      var comparison = START_COMPARISON.firstMatch(text);
      if (comparison == null) return null;

      var op = comparison[0];
      text = text.substring(comparison.end);
      skipWhitespace();

      var version = matchVersion();
      if (version == null) {
        throw new FormatException('Expected version number after "$op" in '
            '"$originalText", got "$text".');
      }

      switch (op) {
        case '<=': return new VersionRange(max: version, includeMax: true);
        case '<': return new VersionRange(max: version, includeMax: false);
        case '>=': return new VersionRange(min: version, includeMin: true);
        case '>': return new VersionRange(min: version, includeMin: false);
      }
      throw "Unreachable.";
    }

    while (true) {
      skipWhitespace();
      if (text.isEmpty) break;

      var version = matchVersion();
      if (version != null) {
        constraints.add(version);
        continue;
      }

      var comparison = matchComparison();
      if (comparison != null) {
        constraints.add(comparison);
        continue;
      }

      // If we got here, we couldn't parse the remaining string.
      throw new FormatException('Could not parse version "$originalText". '
          'Unknown text at "$text".');
    }

    if (constraints.isEmpty) {
      throw new FormatException('Cannot parse an empty string.');
    }

    return new VersionConstraint.intersection(constraints);
  }

  /// Creates a new version constraint that is the intersection of
  /// [constraints].
  ///
  /// It only allows versions that all of those constraints allow. If
  /// constraints is empty, then it returns a VersionConstraint that allows
  /// all versions.
  factory VersionConstraint.intersection(
      Iterable<VersionConstraint> constraints) {
    var constraint = new VersionRange();
    for (var other in constraints) {
      constraint = constraint.intersect(other);
    }
    return constraint;
  }

  /// Returns `true` if this constraint allows no versions.
  bool get isEmpty;

  /// Returns `true` if this constraint allows all versions.
  bool get isAny;

  /// Returns `true` if this constraint allows [version].
  bool allows(Version version);

  /// Creates a new [VersionConstraint] that only allows [Version]s allowed by
  /// both this and [other].
  VersionConstraint intersect(VersionConstraint other);
}

class _EmptyVersion implements VersionConstraint {
  const _EmptyVersion();

  bool get isEmpty => true;
  bool get isAny => false;
  bool allows(Version other) => false;
  VersionConstraint intersect(VersionConstraint other) => this;
  String toString() => '<empty>';
}
