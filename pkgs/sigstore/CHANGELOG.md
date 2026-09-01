# Changelog

## 0.1.4

- Add comprehensive API documentation to all FFI types, enums, variants, and methods.
- Pin upstream `sigstore-rust` commit with `TOB-SIGSTORE-5` fix, removing custom trusted root validation workaround.
- Simplify verification entry point in Rust bridge.
- Remove redundant conformance binary forwarder.
- Collapse generated bindings and fixtures in GitHub PR reviews and diffs via `.gitattributes`.

## 0.1.3

- Validate artifact hex digest length in conformance test runner.
- Ensure `HttpClient` instances are cleanly closed in build hook and tool scripts.
- Add `dart_dependency_validator.yaml` to configure dependencies for native asset build hooks.
- Remove unused `logging` dependency.
- Map `SigstoreError::InternalError` explicitly in Rust bindings.

## 0.1.2

- Optimize precompiled Rust binary size using release profile size optimizations, LTO, single codegen unit, and symbol stripping.

## 0.1.1

- Expose `SigstoreClient.refreshTrustedRoot` for updating Sigstore TUF metadata and trusted root anchors.

## 0.1.0

- Initial release.
- Cryptographic artifact verification via `SigstoreVerifier`.
- Support for keyless verification with Rekor transparency log and Fulcio certificate validation.
- Support for Sigstore Bundle (v0.1, v0.2, v0.3) inspection and verification.
- Support for `local`, `checkout`, and precompiled `fetch` build modes via Dart Native Assets.
