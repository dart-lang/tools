// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parsing of the SLSA build provenance carried in a Sigstore bundle, and the
/// policy that binds a package attestation to the package it is served for.
///
/// `package:sigstore/sigstore.dart` verifies the cryptographic material of a
/// bundle and exposes the signer identity from the Fulcio certificate. It does
/// not expose the signed payload, so the DSSE envelope of the bundle is parsed
/// here, in pure Dart. This library does not touch the native bindings and can
/// be imported on every platform.
///
/// Parsing the statement separately from verifying it is safe as long as the
/// exact same bundle JSON is handed to `package:sigstore/sigstore.dart` for
/// signature verification and to `BuildProvenance.parseBundle`: the payload
/// inspected here is then guaranteed to be the payload the signature was
/// verified over. Do both in one place, from one string.
///
/// `pub` and `pub.dev` both verify package attestations with this library. The
/// signer identity strings that `package:sigstore/sigstore.dart` reports and
/// that `GitHubWorkflowIdentity.tryParse` parses must agree between the client
/// and the server, which is why the parser lives next to the bindings.
library;

export 'src/provenance.dart';
export 'src/provenance_policy.dart';
