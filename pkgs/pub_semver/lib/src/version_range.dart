// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pub_semver.src.version_range;

import 'version.dart';
import 'version_constraint.dart';

/// Constrains versions to a fall within a given range.
///
/// If there is a minimum, then this only allows versions that are at that
/// minimum or greater. If there is a maximum, then only versions less than
/// that are allowed. In other words, this allows `>= min, < max`.
class VersionRange implements VersionConstraint {
  /// The minimum end of the range.
  ///
  /// If [includeMin] is `true`, this will be the minimum allowed version.
  /// Otherwise, it will be the highest version below the range that is not
  /// allowed.
  ///
  /// This may be `null` in which case the range has no minimum end and allows
  /// any version less than the maximum.
  final Version min;

  /// The maximum end of the range.
  ///
  /// If [includeMax] is `true`, this will be the maximum allowed version.
  /// Otherwise, it will be the lowest version above the range that is not
  /// allowed.
  ///
  /// This may be `null` in which case the range has no maximum end and allows
  /// any version greater than the minimum.
  final Version max;

  /// If `true` then [min] is allowed by the range.
  final bool includeMin;

  /// If `true`, then [max] is allowed by the range.
  final bool includeMax;

  /// Creates a new version range from [min] to [max], either inclusive or
  /// exclusive.
  ///
  /// If it is an error if [min] is greater than [max].
  ///
  /// Either [max] or [min] may be omitted to not clamp the range at that end.
  /// If both are omitted, the range allows all versions.
  ///
  /// If [includeMin] is `true`, then the minimum end of the range is inclusive.
  /// Likewise, passing [includeMax] as `true` makes the upper end inclusive.
  VersionRange({this.min, this.max,
      this.includeMin: false, this.includeMax: false}) {
    if (min != null && max != null && min > max) {
      throw new ArgumentError(
          'Minimum version ("$min") must be less than maximum ("$max").');
    }
  }

  bool operator ==(other) {
    if (other is! VersionRange) return false;

    return min == other.min &&
           max == other.max &&
           includeMin == other.includeMin &&
           includeMax == other.includeMax;
  }

  int get hashCode => min.hashCode ^ (max.hashCode * 3) ^
      (includeMin.hashCode * 5) ^ (includeMax.hashCode * 7);

  bool get isEmpty => false;

  bool get isAny => min == null && max == null;

  /// Tests if [other] falls within this version range.
  bool allows(Version other) {
    if (min != null) {
      if (other < min) return false;
      if (!includeMin && other == min) return false;
    }

    if (max != null) {
      if (other > max) return false;
      if (!includeMax && other == max) return false;

      // If the max isn't itself a pre-release, don't allow any pre-release
      // versions of the max.
      //
      // See: https://www.npmjs.org/doc/misc/semver.html
      if (!includeMax &&
          !max.isPreRelease && other.isPreRelease &&
          other.major == max.major && other.minor == max.minor &&
          other.patch == max.patch) {
        return false;
      }
    }

    return true;
  }

  VersionConstraint intersect(VersionConstraint other) {
    if (other.isEmpty) return other;

    // A range and a Version just yields the version if it's in the range.
    if (other is Version) {
      return allows(other) ? other : VersionConstraint.empty;
    }

    if (other is VersionRange) {
      // Intersect the two ranges.
      var intersectMin = min;
      var intersectIncludeMin = includeMin;
      var intersectMax = max;
      var intersectIncludeMax = includeMax;

      if (other.min == null) {
        // Do nothing.
      } else if (intersectMin == null || intersectMin < other.min) {
        intersectMin = other.min;
        intersectIncludeMin = other.includeMin;
      } else if (intersectMin == other.min && !other.includeMin) {
        // The edges are the same, but one is exclusive, make it exclusive.
        intersectIncludeMin = false;
      }

      if (other.max == null) {
        // Do nothing.
      } else if (intersectMax == null || intersectMax > other.max) {
        intersectMax = other.max;
        intersectIncludeMax = other.includeMax;
      } else if (intersectMax == other.max && !other.includeMax) {
        // The edges are the same, but one is exclusive, make it exclusive.
        intersectIncludeMax = false;
      }

      if (intersectMin == null && intersectMax == null) {
        // Open range.
        return new VersionRange();
      }

      // If the range is just a single version.
      if (intersectMin == intersectMax) {
        // If both ends are inclusive, allow that version.
        if (intersectIncludeMin && intersectIncludeMax) return intersectMin;

        // Otherwise, no versions.
        return VersionConstraint.empty;
      }

      if (intersectMin != null && intersectMax != null &&
          intersectMin > intersectMax) {
        // Non-overlapping ranges, so empty.
        return VersionConstraint.empty;
      }

      // If we got here, there is an actual range.
      return new VersionRange(min: intersectMin, max: intersectMax,
          includeMin: intersectIncludeMin, includeMax: intersectIncludeMax);
    }

    throw new ArgumentError('Unknown VersionConstraint type $other.');
  }

  String toString() {
    var buffer = new StringBuffer();

    if (min != null) {
      buffer.write(includeMin ? '>=' : '>');
      buffer.write(min);
    }

    if (max != null) {
      if (min != null) buffer.write(' ');
      buffer.write(includeMax ? '<=' : '<');
      buffer.write(max);
    }

    if (min == null && max == null) buffer.write('any');
    return buffer.toString();
  }
}
