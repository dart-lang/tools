// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart' as checks;
import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:package_config/package_config_types.dart';

extension SubjectValue<T> on Subject<T> {
  T get value {
    late T value;
    context.nest<void>(() => const [], (actual) {
      value = actual;
      return Extracted<void>.value(null);
    }, atSameLevel: true);
    return value;
  }

  void notIdenticalTo(T other) {
    context.expect(() => prefixFirst('is not identical to ', literal(other)), (
      actual,
    ) {
      if (!identical(actual, other)) return null;
      return Rejection(which: ['is identical']);
    });
  }
}

extension PackageConfigChecks on Subject<PackageConfig> {
  Subject<int> get version => has((p) => p.version, 'version');
  Subject<Iterable<Package>> get packages => has((p) => p.packages, 'packages');
  Subject<Object?> get extraData => has((p) => p.extraData, 'extraData');
  Subject<Package?> operator [](String name) => has((p) => p[name], '[$name]');
  Subject<Package?> packageOf(Uri fileUri) =>
      has((p) => p.packageOf(fileUri), 'packageOf("$fileUri")');
  Subject<Uri?> toPackageUri(Uri nonPackageUri) => has(
    (p) => p.toPackageUri(nonPackageUri),
    'toPackageUri("$nonPackageUri")',
  );
  Subject<Uri?> resolve(Uri packageUri) =>
      has((p) => p.resolve(packageUri), 'resolve("$packageUri")');
}

extension PackageChecks on Subject<Package> {
  Subject<String> get name => has((p) => p.name, 'name');
  Subject<Uri> get root => has((p) => p.root, 'root');
  Subject<Uri> get packageUriRoot =>
      has((p) => p.packageUriRoot, 'packageUriRoot');
  Subject<LanguageVersion?> get languageVersion =>
      has((p) => p.languageVersion, 'languageVersion');
  Subject<Object?> get extraData => has((p) => p.extraData, 'extraData');
  Subject<bool> get relativeRoot => has((p) => p.relativeRoot, 'relativeRoot');

  void get hasRelativeRoot => relativeRoot.isTrue();
  void get hasAbsoluteRoot => relativeRoot.isFalse();
}

extension LanguageVersionChecks on Subject<LanguageVersion> {
  Subject<int> get major => has((l) => l.major, 'major');
  Subject<int> get minor => has((l) => l.minor, 'minor');

  Subject<int> compareTo(LanguageVersion other) => context.nest(
    () => const ['compareTo'],
    (v) => Extracted.value(v.compareTo(other)),
  );

  void get isValid {
    context.expect(() => const ['is valid'], (l) {
      if (l is InvalidLanguageVersion) {
        return Rejection(actual: ['$this'], which: const ['is not valid']);
      }
      return null;
    });
  }

  void get isNotValid {
    context.expect(() => const ['is not valid'], (l) {
      if (l is! InvalidLanguageVersion) {
        return Rejection(actual: ['$this'], which: const ['is valid']);
      }
      return null;
    });
  }
}

/// Operations on the iterable below the [Subject] type.
extension IterableChecksX<E> on Subject<Iterable<E>> {
  Subject<Iterable<R>> map<R>(R Function(E) convert, [String? name]) =>
      context.nest(
        () => [name ?? 'map<$R>(...)'],
        (it) => Extracted.value(it.map(convert)),
      );

  Subject<Set<E>> toSet() =>
      context.nest(() => ['toSet()'], (it) => Extracted.value(it.toSet()));
  Subject<List<E>> toList() =>
      context.nest(() => ['toList()'], (it) => Extracted.value(it.toList()));
}
