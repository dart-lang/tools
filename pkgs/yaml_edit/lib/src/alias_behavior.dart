// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../yaml_edit.dart';

/// Defines how [YamlEditor] handles mutations when encountering YAML aliases
/// and anchors.
enum AliasBehavior {
  /// Mutating an alias reference mutates the underlying anchor definition,
  /// propagating the change to all references.
  reference,

  /// Mutating an alias reference materializes (copies) the node inline before
  /// applying the change, decoupling it from the anchor.
  ///
  /// Mutating an anchor definition directly updates the template in place.
  copyOnWrite,

  /// Any operation touching an alias node or its children throws an
  /// [AliasException] (current default behavior).
  disallow,
}
