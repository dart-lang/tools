// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Domain models and convenience extensions for contractual annotations
/// extracted from `package:meta`.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';

import 'api_trait.dart';

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

  /// Extracts active `package:meta` contracts from [element], or returns `null`
  /// if none are present.
  static MetaContractTrait? fromElement(Element element) {
    final contracts = <MetaContract>{};
    void check(Metadata metadata) {
      if (metadata.hasExperimental) contracts.add(MetaContract.experimental);
      if (metadata.hasImmutable) contracts.add(MetaContract.immutable);
      if (metadata.hasInternal) contracts.add(MetaContract.internal);
      if (metadata.hasMustBeOverridden) {
        contracts.add(MetaContract.mustBeOverridden);
      }
      if (metadata.hasMustCallSuper) contracts.add(MetaContract.mustCallSuper);
      if (metadata.hasNonVirtual) contracts.add(MetaContract.nonVirtual);
      if (metadata.hasProtected) contracts.add(MetaContract.protected);
      if (metadata.hasUseResult) contracts.add(MetaContract.useResult);
      if (metadata.hasVisibleForOverriding) {
        contracts.add(MetaContract.visibleForOverriding);
      }
      if (metadata.hasVisibleForTesting) {
        contracts.add(MetaContract.visibleForTesting);
      }
    }

    check(element.nonSynthetic.metadata);
    if (element is PropertyAccessorElement) {
      check(element.variable.nonSynthetic.metadata);
    }

    return contracts.isNotEmpty ? MetaContractTrait(contracts) : null;
  }

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
