// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(feature): Implement Orphan Docregion Analysis.
// Cross-reference defined `#docregion`s with markdown injections to report
// unused ones.
/// Tooling to update code excerpts in Markdown documentation
/// from regions declared in source files elsewhere.
library;

export 'src/transform.dart';
export 'src/update.dart';
