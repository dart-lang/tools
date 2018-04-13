// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'version.dart';
import 'version_range.dart';

/// Returns whether [range1] is immediately next to, but not overlapping,
/// [range2].
bool areAdjacent(VersionRange range1, VersionRange range2) {
  if (range1.max != range2.min) return false;

  return (range1.includeMax && !range2.includeMin) ||
      (!range1.includeMax && range2.includeMin);
}

/// Returns whether [range1] allows lower versions than [range2].
bool allowsLower(VersionRange range1, VersionRange range2) {
  if (range1.min == null) return range2.min != null;
  if (range2.min == null) return false;

  var comparison = range1.min.compareTo(range2.min);
  if (comparison == -1) return true;
  if (comparison == 1) return false;
  return range1.includeMin && !range2.includeMin;
}

/// Returns whether [range1] allows higher versions than [range2].
bool allowsHigher(VersionRange range1, VersionRange range2) {
  if (range1.max == null) return range2.max != null;
  if (range2.max == null) return false;

  // `<1.0.0-dev.1` allows higher versions than `<1.0.0`, such as `1.0.0-dev.0`.
  if (disallowedByPreRelease(range2, range1.max)) return true;

  // `<1.0.0` doesn't allow any versions higher than `<1.0.0-dev`.
  if (disallowedByPreRelease(range1, range2.max)) return false;

  var comparison = range1.max.compareTo(range2.max);
  if (comparison == 1) return true;
  if (comparison == -1) return false;
  return range1.includeMax && !range2.includeMax;
}

/// Returns whether [range1] allows only versions lower than those allowed by
/// [range2].
bool strictlyLower(VersionRange range1, VersionRange range2) {
  if (range1.max == null || range2.min == null) return false;

  // `<1.0.0` doesn't allow any versions allowed by `>=1.0.0-dev.0`.
  if (disallowedByPreRelease(range1, range2.min)) return true;

  //if (disallowedByPreRelease(range2, range1.min)) return true;

  var comparison = range1.max.compareTo(range2.min);
  if (comparison == -1) return true;
  if (comparison == 1) return false;
  return !range1.includeMax || !range2.includeMin;
}

/// Returns whether [range1] allows only versions higher than those allowed by
/// [range2].
bool strictlyHigher(VersionRange range1, VersionRange range2) =>
    strictlyLower(range2, range1);

// Returns whether [other] is disallowed by [range] because we disallow
// pre-release versions that have the same major, minor, and patch version as
// the max of a range, but only if neither the max nor the min is a pre-release
// of that version.
//
// This ensures that `^1.2.3` doesn't include `2.0.0-pre`, while also allowing
// both `>=2.0.0-pre.2 <2.0.0` and `>=1.2.3 <2.0.0-pre.7` to match
// `2.0.0-pre.5`.
//
// It's worth noting that this is different than [NPM's semantics][]. NPM
// disallows **all** pre-release versions unless their major, minor, and
// patch numbers match those of a prerelease min or max. This ensures that
// no prerelease versions will ever be selected if the user doesn't
// explicitly allow them.
//
// [NPM's semantics]: https://www.npmjs.org/doc/misc/semver.html#prerelease-tags
//
// Instead, we ensure that release versions will always be preferred over
// prerelease versions by ordering the release versions first in
// [Version.prioritize]. This means that constraints like `any` or
// `>1.2.3` can still match prerelease versions if they're the only things
// available.
bool disallowedByPreRelease(VersionRange range, Version other) {
  var maxIsReleaseOfOther = !range.includeMax &&
      !range.max.isPreRelease &&
      other.isPreRelease &&
      _equalsWithoutPreRelease(other, range.max);
  var minIsPreReleaseOfOther = range.min != null &&
      range.min.isPreRelease &&
      _equalsWithoutPreRelease(other, range.min);
  return maxIsReleaseOfOther && !minIsPreReleaseOfOther;
}

bool _equalsWithoutPreRelease(Version version1, Version version2) =>
    version1.major == version2.major &&
    version1.minor == version2.minor &&
    version1.patch == version2.patch;
