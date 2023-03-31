// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class EnvironmentParser {
  /// Parses an environment key into an config key.
  ///
  /// Environment keys can only contain alphanumeric characters and underscores.
  /// Treats `__` as hierarchy separator, and replaces it with `.`.
  ///
  /// Often, environment variables are uppercased.
  /// Replaces all uppercase characters with lowercase characters.
  String parseKey(String key) => key.replaceAll('__', '.').toLowerCase();

  Map<String, String> parse(Map<String, String> environment) => {
        for (final entry in environment.entries)
          parseKey(entry.key): entry.value,
      };
}
