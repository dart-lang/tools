// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A Dart client library for Sigstore cryptographic bundle inspection and
/// artifact verification, backed by `sigstore-rust` and `package:boring`.
library;

export 'src/bindings/lib.g.dart'
    show
        SigstoreBundle,
        SigstoreError,
        SigstoreVerificationPolicy,
        SigstoreVerificationResult;
export 'src/tuf_refresh.dart' show SigstoreClient;
