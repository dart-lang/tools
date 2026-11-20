// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';

/// Header elements whose [Element.generatedId] must be computed once inline
/// parsing of their children is done.
///
/// Kept out of [Element] so the public AST API doesn't change.
final _pending = Expando<bool>('pendingHeaderId');

/// Marks [element] so `Document` generates its id after inline parsing.
void markPendingHeaderId(Element element) => _pending[element] = true;

/// Whether [element] was marked with [markPendingHeaderId].
bool hasPendingHeaderId(Element element) => _pending[element] ?? false;
