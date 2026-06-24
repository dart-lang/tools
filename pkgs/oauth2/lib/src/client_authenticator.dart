// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A callback used to add additional client authentication headers or body
/// parameters to a token request (e.g., for JWT assertions per RFC 7523).
typedef ClientAuthenticator = FutureOr<void> Function(
    Map<String, String> headers, Map<String, String> body);
