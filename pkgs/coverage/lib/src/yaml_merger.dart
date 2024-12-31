import 'dart:collection';

import 'package:yaml/yaml.dart';

/// Merges two maps (of yaml) with simple override semantics, suitable for
/// merging two maps where one map defines default values that are added to
/// (and possibly overridden) by an overriding map.
class Merger {
  /// Merges a default [o1] with an overriding object [o2].
  ///
  ///   * lists are overridden.
  ///   * maps are merged recursively.
  ///   * if map values cannot be merged, the overriding value is taken.
  ///
  YamlNode merge(YamlNode o1, YamlNode o2) {
    if (o1 is YamlMap && o2 is YamlMap) {
      return mergeMap(o1, o2);
    }

    // Default to override, unless the overriding value is `null`.
    if (o2.value == null) {
      return o1;
    }
    return o2;
  }

  /// Merge maps (recursively).
  YamlMap mergeMap(YamlMap m1, YamlMap m2) {
    final Map<YamlNode, YamlNode> merged =
        HashMap<YamlNode, YamlNode>(); // equals: _equals, hashCode: _hashCode
    m1.nodeMap.forEach((k, v) {
      merged[k] = v;
    });
    m2.nodeMap.forEach((k, v) {
      final value = k.value;
      final mergedKey =
          merged.keys.firstWhere((key) => key.value == value, orElse: () => k)
              as YamlScalar;
      final o1 = merged[mergedKey];
      if (o1 != null) {
        merged[mergedKey] = merge(o1, v);
      } else {
        merged[mergedKey] = v;
      }
    });

    final result = <dynamic, dynamic>{};

    merged.forEach((key, value) {
      result[key.value] = value;
    });

    return YamlMap.wrap(result);
  }
}

extension YamlMapExtensions on YamlMap {
  /// Return [nodes] as a Map with [YamlNode] keys.
  Map<YamlNode, YamlNode> get nodeMap => nodes.cast<YamlNode, YamlNode>();
}
