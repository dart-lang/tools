// Copyright (c) 2021, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'yaml_exception.dart';

/// A listener that is notified of [YamlException]s during scanning/parsing.
///
/// Pass an instance to the `errorListener` parameter of `loadYaml` (and
/// related functions) together with `recover: true` to observe the errors
/// that parsing recovered from, instead of only seeing the first one thrown.
/// This is useful for tools (like linters or IDEs) that want to report every
/// problem in a document rather than stopping at the first.
///
/// ```dart
/// final listener = ErrorCollector();
/// final doc = loadYaml(invalidYaml, recover: true, errorListener: listener);
/// for (final error in listener.errors) {
///   print(error.message);
/// }
/// ```
abstract class ErrorListener {
  /// This method is invoked when an [error] has been found in the YAML.
  void onError(YamlException error);
}

/// An [ErrorListener] that collects all errors into [errors], in the order
/// they were encountered.
///
/// This is a convenience implementation for the common case of wanting to
/// gather every recovered-from error for later inspection, rather than
/// handling each one as it's reported.
///
/// ```dart
/// final listener = ErrorCollector();
/// loadYaml(invalidYaml, recover: true, errorListener: listener);
/// print('Found ${listener.errors.length} error(s)');
/// ```
class ErrorCollector extends ErrorListener {
  final List<YamlException> errors = [];

  @override
  void onError(YamlException error) => errors.add(error);
}
