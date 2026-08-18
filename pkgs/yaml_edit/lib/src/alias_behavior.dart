// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../yaml_edit.dart';

/// Defines how [YamlEditor] handles mutations when encountering YAML aliases
/// and anchors.
///
/// See `example/alias_behavior_example.dart` for usage examples.
enum AliasBehavior {
  /// Mutating an alias reference mutates the underlying anchor definition,
  /// propagating the change to all references.
  ///
  /// When modifying a child property through a path that traverses an alias
  /// reference (`*name`), the mutation path is automatically redirected to the
  /// anchor definition (`&name`).
  ///
  /// **Performance considerations:**
  /// Path redirection requires validating anchor definitions during traversal,
  /// adding O(D) time overhead where D is the depth of the mutation path.
  ///
  /// Throws an [AliasException] when attempting to remove an anchor definition
  /// node (`&name`) that has active alias references pointing to it.
  reference,

  /// Mutating an alias reference materializes (copies) the node inline before
  /// applying the change, decoupling it from the anchor template.
  ///
  /// When modifying a child property through a path that traverses an alias
  /// reference (`*name`), the referenced AST subtree is deeply cloned without
  /// aliases into standard YAML nodes and inserted inline at the reference
  /// position before applying the mutation (Asymmetric Copy-On-Write).
  ///
  /// Mutating an anchor definition directly updates the template in place so
  /// all inheriting alias references observe the change.
  ///
  /// **Performance considerations:**
  /// Materializing an alias reference inline deeply copies the referenced AST
  /// subtree, requiring O(N) time where N is the number of nodes in the aliased
  /// subtree.
  ///
  /// Throws an [AliasException] when attempting to remove an anchor definition
  /// node (`&name`) that has active alias references pointing to it.
  copyOnWrite,

  /// Any operation touching an alias node or its children throws an
  /// [AliasException].
  ///
  /// This is the default behavior of [YamlEditor], ensuring strict backwards
  /// compatibility by rejecting any modification that traverses or modifies an
  /// anchor definition (`&name`) or alias reference (`*name`).
  disallow,
}
