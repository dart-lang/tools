// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// Base interface for domain-specific, contractual, or runtime traits attached
/// to an API declaration or library.
abstract interface class ApiTrait implements Comparable<ApiTrait> {
  /// The namespace identifying the trait kind (e.g. `'meta'`, `'js'`, `'ffi'`).
  String get namespace;

  /// Text representation for human-readable parentheticals in `api.txt`.
  List<String> get parentheticalSegments;

  /// JSON serialization for `api.json`.
  Map<String, dynamic> toJson();

  /// Deserializes an [ApiTrait] from a JSON map containing a `'namespace'`
  /// field.
  static ApiTrait fromJson(Map<String, dynamic> json) {
    final namespace = json['namespace'] as String?;
    return switch (namespace) {
      'meta' => MetaContractTrait.fromJson(json),
      _ => throw FormatException('Unknown ApiTrait namespace: "$namespace"'),
    };
  }
}

/// Contractual annotations from `package:meta`.
enum MetaContract implements Comparable<MetaContract> {
  experimental('experimental'),
  immutable('immutable'),
  internal('internal'),
  mustBeOverridden('must be overridden'),
  mustCallSuper('must call super'),
  nonVirtual('non-virtual'),
  protected('protected'),
  useResult('use result'),
  visibleForOverriding('visible for overriding'),
  visibleForTesting('visible for testing');

  /// The human-readable label used for text representation in summaries.
  final String textLabel;
  const MetaContract(this.textLabel);

  @override
  int compareTo(MetaContract other) => name.compareTo(other.name);
}

/// An [ApiTrait] capturing `package:meta` contracts.
final class MetaContractTrait implements ApiTrait {
  @override
  String get namespace => 'meta';

  /// The set of active metadata contracts associated with this trait.
  final Set<MetaContract> contracts;

  MetaContractTrait(Iterable<MetaContract> contracts)
    : contracts = Set.unmodifiable(contracts.toSet().toList()..sort());

  factory MetaContractTrait.fromJson(Map<String, dynamic> json) {
    final list = json['contracts'] as List<dynamic>? ?? const [];
    final set = <MetaContract>{};
    for (final item in list) {
      if (item is String) {
        final contract = MetaContract.values
            .where((e) => e.name == item)
            .firstOrNull;
        if (contract != null) {
          set.add(contract);
        }
      }
    }
    return MetaContractTrait(set);
  }

  @override
  Map<String, dynamic> toJson() => {
    'namespace': namespace,
    'contracts': contracts.map((e) => e.name).toList(),
  };

  @override
  List<String> get parentheticalSegments =>
      contracts.map((e) => e.textLabel).toList();

  @override
  int compareTo(ApiTrait other) {
    final diff = namespace.compareTo(other.namespace);
    if (diff != 0) return diff;
    if (other is MetaContractTrait) {
      final thisStr = contracts.map((e) => e.name).join(',');
      final otherStr = other.contracts.map((e) => e.name).join(',');
      return thisStr.compareTo(otherStr);
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaContractTrait &&
          const SetEquality<MetaContract>().equals(contracts, other.contracts);

  @override
  int get hashCode =>
      Object.hash(namespace, const SetEquality<MetaContract>().hash(contracts));
}
