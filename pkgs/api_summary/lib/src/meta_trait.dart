// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Domain models and convenience extensions for contractual annotations
/// extracted from `package:meta`.
library;

import 'package:collection/collection.dart';

import 'api_declaration.dart';
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

/// Convenience extensions for querying `package:meta` contractual annotations.
extension ApiDeclarationMetaSugar on ApiDeclaration {
  bool get isExperimental => hasMeta(MetaContract.experimental);
  bool get isImmutable => hasMeta(MetaContract.immutable);
  bool get isInternal => hasMeta(MetaContract.internal);
  bool get isMustBeOverridden => hasMeta(MetaContract.mustBeOverridden);
  bool get isMustCallSuper => hasMeta(MetaContract.mustCallSuper);
  bool get isNonVirtual => hasMeta(MetaContract.nonVirtual);
  bool get isProtected => hasMeta(MetaContract.protected);
  bool get isUseResult => hasMeta(MetaContract.useResult);
  bool get isVisibleForOverriding => hasMeta(MetaContract.visibleForOverriding);
  bool get isVisibleForTesting => hasMeta(MetaContract.visibleForTesting);

  bool hasMeta(MetaContract contract) => traits.any(
    (trait) => trait is MetaContractTrait && trait.contracts.contains(contract),
  );
}
