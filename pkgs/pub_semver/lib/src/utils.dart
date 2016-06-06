// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'version_range.dart';

/// Returns whether [range1] is immediately next to, but not overlapping,
/// [range2].
bool areAdjacent(VersionRange range1, VersionRange range2) {
  if (range1.max != range2.min) return false;

  return (range1.includeMax && !range2.includeMin) ||
      (!range1.includeMax && range2.includeMin);
}

/// A [Comparator] that compares the maximum versions of [range1] and [range2].
int compareMax(VersionRange range1, VersionRange range2) {
  if (range1.max == null) {
    if (range2.max == null) return 0;
    return 1;
  } else if (range2.max == null) {
    return -1;
  }

  var result = range1.max.compareTo(range2.max);
  if (result != 0) return result;
  if (range1.includeMax != range2.includeMax) return range1.includeMax ? 1 : -1;
  return 0;
}
