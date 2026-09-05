// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';

final class _IdentityPair {
  final Object? o1;
  final Object? o2;

  _IdentityPair(this.o1, this.o2);

  @override
  bool operator ==(Object other) =>
      other is _IdentityPair &&
      identical(o1, other.o1) &&
      identical(o2, other.o2);

  @override
  int get hashCode => identityHashCode(o1) ^ identityHashCode(o2);
}

/// Creates a map that uses our custom [deepEquals] and [deepHashCode] functions
/// to determine equality.
Map<K, V> deepEqualsMap<K, V>() =>
    LinkedHashMap(equals: deepEquals, hashCode: deepHashCode);

/// Compares two [Object]s for deep equality. This implementation differs from
/// `package:yaml`'s deep equality notation by allowing for comparison of
/// non-scalar map keys.
///
/// Uses coinductive cycle detection to handle cyclic YAML structures.
bool deepEquals(dynamic obj1, dynamic obj2) => _deepEquals(obj1, obj2);

bool _deepEquals(dynamic obj1, dynamic obj2, [Set<_IdentityPair>? visited]) {
  if (identical(obj1, obj2)) return true;

  if (obj1 is YamlNode) obj1 = obj1.value;
  if (obj2 is YamlNode) obj2 = obj2.value;

  if (identical(obj1, obj2)) return true;

  if ((obj1 is Map && obj2 is Map) || (obj1 is List && obj2 is List)) {
    final pair = _IdentityPair(obj1, obj2);
    if (visited != null && visited.contains(pair)) return true;
    final activeVisited = visited ?? <_IdentityPair>{};
    activeVisited.add(pair);
    try {
      if (obj1 is Map && obj2 is Map) {
        return _mapDeepEquals(obj1, obj2, activeVisited);
      }
      if (obj1 is List && obj2 is List) {
        return _listDeepEquals(obj1, obj2, activeVisited);
      }
    } finally {
      activeVisited.remove(pair);
    }
  }

  return obj1 == obj2;
}

/// Compares two [List]s for deep equality.
bool listDeepEquals(List list1, List list2) => _listDeepEquals(list1, list2);

bool _listDeepEquals(List list1, List list2, [Set<_IdentityPair>? visited]) {
  if (identical(list1, list2)) return true;
  if (list1.length != list2.length) return false;

  if (list1 is YamlList) list1 = list1.nodes;
  if (list2 is YamlList) list2 = list2.nodes;

  for (var i = 0; i < list1.length; i++) {
    if (!_deepEquals(list1[i], list2[i], visited)) {
      return false;
    }
  }

  return true;
}

/// Compares two [Map]s for deep equality. Differs from `package:yaml`'s deep
/// equality notation by allowing for comparison of non-scalar map keys.
bool mapDeepEquals(Map map1, Map map2) => _mapDeepEquals(map1, map2);

bool _mapDeepEquals(Map map1, Map map2, [Set<_IdentityPair>? visited]) {
  if (identical(map1, map2)) return true;
  if (map1.length != map2.length) return false;

  if (map1 is YamlList) map1 = (map1 as YamlMap).nodes;
  if (map2 is YamlList) map2 = (map2 as YamlMap).nodes;

  return map1.keys.every((key) {
    if (!_containsKey(map2, key, visited)) return false;

    /// Because two keys may be equal by deep equality but using one key on the
    /// other map might not get a hit since they may not be both using our
    /// [deepEqualsMap].
    final key2 = _getKey(map2, key, visited);

    if (!_deepEquals(map1[key], map2[key2], visited)) {
      return false;
    }

    return true;
  });
}

/// Returns a hashcode for [value] such that structures that are equal by
/// [deepEquals] will have the same hash code.
///
/// Guards against cycles in recursive YAML structures.
int deepHashCode(Object? value, [Set<Object?>? visited]) {
  if (value is YamlScalar) {
    return (value.value as Object?).hashCode;
  }

  if (value is Map) {
    final activeVisited = visited ?? Set<Object?>.identity();
    if (!activeVisited.add(value)) return 0;
    try {
      const equality = UnorderedIterableEquality();
      final keysHash = equality.hash(
        value.keys.map((k) => deepHashCode(k, activeVisited)),
      );
      final valuesHash = equality.hash(
        value.values.map((v) => deepHashCode(v, activeVisited)),
      );
      return keysHash ^ valuesHash;
    } finally {
      activeVisited.remove(value);
    }
  } else if (value is Iterable) {
    final activeVisited = visited ?? Set<Object?>.identity();
    if (!activeVisited.add(value)) return 0;
    try {
      return const IterableEquality().hash(
        value.map((v) => deepHashCode(v, activeVisited)),
      );
    } finally {
      activeVisited.remove(value);
    }
  }

  return value.hashCode;
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode getKeyNode(YamlMap map, Object? key) {
  return map.nodes.keys.firstWhere((node) => deepEquals(node, key)) as YamlNode;
}

/// Returns the entry associated with a [mapKey] and its index in the [map].
({int index, YamlNode keyNode, YamlNode valueNode}) getYamlMapEntry(
  YamlMap map,
  Object? mapKey,
) {
  for (final (index, MapEntry(:key, :value)) in map.nodes.entries.indexed) {
    if (deepEquals(key, mapKey)) {
      return (index: index, keyNode: key, valueNode: value);
    }
  }

  throw YamlException('$mapKey not found in map', map.span);
}

/// Returns the key in [map] that is equal to the provided [key] by the notion
/// of deep equality.
Object? getKey(Map map, Object? key) => _getKey(map, key);

Object? _getKey(Map map, Object? key, [Set<_IdentityPair>? visited]) {
  return map.keys.firstWhere((k) => _deepEquals(k, key, visited));
}

/// Checks if [map] has any keys equal to the provided [key] by deep equality.
bool containsKey(Map map, Object? key) => _containsKey(map, key);

bool _containsKey(Map map, Object? key, [Set<_IdentityPair>? visited]) {
  return map.keys.where((node) => _deepEquals(node, key, visited)).isNotEmpty;
}
