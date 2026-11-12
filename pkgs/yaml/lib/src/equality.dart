// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import 'yaml_node.dart';

/// Returns a [Map] that compares its keys based on [deepEquals].
Map<K, V> deepEqualsMap<K, V>() =>
    LinkedHashMap(equals: deepEquals, hashCode: deepHashCode);

/// Pair of values with pairwise identity equality.
///
/// Cannot use `(Object?, Object?)` since that has undefined identity.
final class _IdPair {
  final Object? value1;
  final Object? value2;
  _IdPair(this.value1, this.value2);

  @override
  bool operator ==(Object other) =>
      other is _IdPair &&
      identical(value1, other.value1) &&
      identical(value2, other.value2);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(value1), identityHashCode(value2));
}

/// Whether two objects are structurally equivalent.
///
/// Considers two NaN values to be equivalent, handles self-referential
/// structures, and considers [YamlScalar]s to be equal to their values.
bool deepEquals(Object? obj1, Object? obj2) {
  // Stack with alternating first and second operand.
  final parents = <Object?>[];

  // Used to avoid repeated traversal of the same value pair.
  //
  // During the recursive traversal of the first occurrence of a pair,
  // a recurrence (meaning a cyclic structure) is considered a match.
  // After the first recursive traversal, if equivalence has not
  // been disproven, a second occurrence is known to also be equivalent.
  final seen = HashSet<_IdPair>();

  bool equals(Object? obj1, Object? obj2) {
    if (obj1 is YamlScalar) obj1 = obj1.value;
    if (obj2 is YamlScalar) obj2 = obj2.value;

    // _parents is guaranteed to have even length.
    for (var i = 0; i < parents.length; i += 2) {
      var loop1 = identical(obj1, parents[i]);
      var loop2 = identical(obj2, parents[i + 1]);
      // If both structures loop in the same place, they're equal at that point
      // in the structure. If one loops and the other doesn't, they're not
      // equal.
      if (loop1) {
        return loop2;
      } else if (loop2) {
        return false;
      }
    }

    parents
      ..add(obj1)
      ..add(obj2);
    try {
      if (obj1 is List && obj2 is List) {
        if (seen.add(_IdPair(obj1, obj2))) {
          // First occurrence, recurse.
          if (obj1.length != obj2.length) return false;
          for (var i = 0; i < obj1.length; i++) {
            if (!equals(obj1[i], obj2[i])) return false;
          }
        }
        return true;
      }
      if (obj1 is Map && obj2 is Map) {
        if (seen.add(_IdPair(obj1, obj2))) {
          // First occurrence, recurse.
          if (obj1.length != obj2.length) return false;
          for (final key in obj1.keys) {
            if (!obj2.containsKey(key) || !equals(obj1[key], obj2[key])) {
              return false;
            }
          }
        }
        return true;
      }
      // Whether the objects are just equal.
      // For numbers, also considers two NaNs equivalent.
      return obj1 == obj2 ||
          obj1 is num && obj2 is num && obj1.isNaN && obj2.isNaN;
    } finally {
      parents.length -= 2;
    }
  }

  return equals(obj1, obj2);
}

/// Returns a hash code for [obj] such that structurally equivalent objects
/// will have the same hash code.
///
/// This supports deep equality for maps and lists, including those with
/// self-referential structures, and returns the same hash code for
/// [YamlScalar]s and their values.
int deepHashCode(Object? obj) {
  // Used for detecting cyclic objects and avoiding repeated traversal.
  final seen = Map<Object, int>.identity();

  int deepHashCodeInner(Object? value) {
    if (value is Map) {
      final cachedHash = seen[value];
      if (cachedHash != null) return cachedHash;
      seen[value] = seen.length; // Hash for cyclic occurrences.
      const equality = UnorderedIterableEquality<Object?>();
      return seen[value] = Object.hash(
          equality.hash(value.keys.map(deepHashCodeInner)),
          equality.hash(value.values.map(deepHashCodeInner)));
    } else if (value is Iterable) {
      final cachedHash = seen[value];
      if (cachedHash != null) return cachedHash;
      seen[value] = seen.length;
      return seen[value] = const IterableEquality<Object?>().hash(
        value.map(deepHashCodeInner),
      );
    } else if (value is YamlScalar) {
      return (value.value as Object?).hashCode;
    } else {
      return value.hashCode;
    }
  }

  return deepHashCodeInner(obj);
}
