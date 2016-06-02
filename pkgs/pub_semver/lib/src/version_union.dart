// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'utils.dart';
import 'version.dart';
import 'version_constraint.dart';
import 'version_range.dart';

/// A version constraint representing a union of multiple disjoint version
/// ranges.
///
/// An instance of this will only be created if the version can't be represented
/// as a non-compound value.
class VersionUnion implements VersionConstraint {
  /// The constraints that compose this union.
  ///
  /// This list has two invariants:
  ///
  /// * Its contents are sorted from lowest to highest matched versions.
  /// * Its contents are disjoint and non-adjacent. In other words, for any two
  ///   constraints next to each other in the list, there's some version between
  ///   those constraints that they don't match.
  final List<VersionRange> ranges;

  bool get isEmpty => false;

  bool get isAny => false;

  /// Creates a union from a list of ranges with no pre-processing.
  ///
  /// It's up to the caller to ensure that the invariants described in [ranges]
  /// are maintained. They are not verified by this constructor. To
  /// automatically ensure that they're maintained, use [new
  /// VersionConstraint.unionOf] instead.
  VersionUnion.fromRanges(this.ranges);

  bool allows(Version version) =>
      ranges.any((constraint) => constraint.allows(version));

  bool allowsAll(VersionConstraint other) {
    var ourRanges = ranges.iterator;
    var theirRanges = _rangesFor(other).iterator;

    // Because both lists of ranges are ordered by minimum version, we can
    // safely move through them linearly here.
    ourRanges.moveNext();
    theirRanges.moveNext();
    while (ourRanges.current != null && theirRanges.current != null) {
      if (ourRanges.current.allowsAll(theirRanges.current)) {
        theirRanges.moveNext();
      } else {
        ourRanges.moveNext();
      }
    }

    // If our ranges have allowed all of their ranges, we'll have consumed all
    // of them.
    return theirRanges.current == null;
  }

  bool allowsAny(VersionConstraint other) {
    var ourRanges = ranges.iterator;
    var theirRanges = _rangesFor(other).iterator;

    // Because both lists of ranges are ordered by minimum version, we can
    // safely move through them linearly here.
    ourRanges.moveNext();
    theirRanges.moveNext();
    while (ourRanges.current != null && theirRanges.current != null) {
      if (ourRanges.current.allowsAny(theirRanges.current)) {
        return true;
      }

      // Move the constraint with the higher max value forward. This ensures
      // that we keep both lists in sync as much as possible.
      if (compareMax(ourRanges.current, theirRanges.current) < 0) {
        ourRanges.moveNext();
      } else {
        theirRanges.moveNext();
      }
    }

    return false;
  }

  VersionConstraint intersect(VersionConstraint other) {
    var ourRanges = ranges.iterator;
    var theirRanges = _rangesFor(other).iterator;

    // Because both lists of ranges are ordered by minimum version, we can
    // safely move through them linearly here.
    var newRanges = <VersionRange>[];
    ourRanges.moveNext();
    theirRanges.moveNext();
    while (ourRanges.current != null && theirRanges.current != null) {
      var intersection = ourRanges.current
          .intersect(theirRanges.current);

      if (!intersection.isEmpty) newRanges.add(intersection);

      // Move the constraint with the higher max value forward. This ensures
      // that we keep both lists in sync as much as possible, and that large
      // ranges have a chance to match multiple small ranges that they contain.
      if (compareMax(ourRanges.current, theirRanges.current) < 0) {
        ourRanges.moveNext();
      } else {
        theirRanges.moveNext();
      }
    }

    if (newRanges.isEmpty) return VersionConstraint.empty;
    if (newRanges.length == 1) return newRanges.single;

    return new VersionUnion.fromRanges(newRanges);
  }

  /// Returns [constraint] as a list of ranges.
  ///
  /// This is used to normalize ranges of various types.
  List<VersionRange> _rangesFor(VersionConstraint constraint) {
    if (constraint.isEmpty) return [];
    if (constraint is VersionUnion) return constraint.ranges;
    if (constraint is VersionRange) return [constraint];
    throw new ArgumentError('Unknown VersionConstraint type $constraint.');
  }

  VersionConstraint union(VersionConstraint other) =>
      new VersionConstraint.unionOf([this, other]);

  bool operator ==(other) {
    if (other is! VersionUnion) return false;
    return const ListEquality().equals(ranges, other.ranges);
  }

  int get hashCode => const ListEquality().hash(ranges);

  String toString() => ranges.join(" or ");
}
