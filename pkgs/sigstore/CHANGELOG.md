# Changelog

## 0.2.5-wip

- Move to `dart-lang/tools` monorepo.

## 0.2.4

- Fix `CheckoutMode.dependencies` in `hook/build.dart` to track `rust/src/boring_provider.rs` instead of the removed `rust/aws-lc-rs-boring/src/lib.rs` path. Native binaries are unchanged (`binaries-v0.2.1`).

## 0.2.3

- Bump `package:boring` constraint to `^0.4.2` for the BoringSSL intermediate certificate blocklist update ([`GHSA-3pvf-h66p-qwjp`](https://github.com/dart-lang/tools/security/advisories/GHSA-3pvf-h66p-qwjp)). Native binaries are unchanged (`binaries-v0.2.1`).

## 0.2.2

- Documentation-only release: describe the `sigstore_crypto::CryptoProvider` integration, correct the native library size reduction to the measured ~60% (the README and the 0.2.0 entry previously claimed ~70%), and note that ML-DSA signatures are not supported. Native binaries are unchanged (`binaries-v0.2.1`).

## 0.2.1

- **Fix**: The default `fetch` build mode of 0.2.0 downloaded the `binaries-v0.1.4` native library, which predates the `package:boring` migration, so the first call failed with `Failed to lookup symbol 'sigstore_SigstoreVerifier_init_boring_mv1'`. 0.2.1 ships matching `binaries-v0.2.1` precompiled binaries.
- `fetch` mode now refuses to use a precompiled binary whose SHA-256 hash is not pinned in `hashes.dart` (previously such downloads ran unverified) and names the supported targets in the error.
- Add precompiled binaries for `aarch64-unknown-linux-gnu` and `x86_64-apple-darwin`; `fetch` mode now covers Linux x64/arm64, macOS x64/arm64, and Windows x64, matching the platforms `package:boring` ships prebuilt BoringSSL for.
- Replace the `[patch.crates-io]` `aws-lc-rs` shim crate with the `sigstore_crypto::CryptoProvider` API of `sigstore-rust` 0.15.0, implemented over `package:boring`; the BoringSSL symbol table shrinks from 28 to 25 functions.
- Upgrade to `sigstore-rust` 0.15.0. `SigstoreBundle.toJson()` now emits the canonical v0.3 media type `application/vnd.dev.sigstore.bundle.v0.3+json` (previously `application/vnd.dev.sigstore.bundle+json;version=0.3`).

## 0.2.0

- **Breaking**: `SigstoreClient.refreshTrustedRoot` now returns `Future<String>` instead of `String` and accepts an optional `HttpClient? httpClient` parameter.
- Replace `aws-lc-rs` / `aws-lc-sys` with a `package:boring` (`libbssl_dart`) cryptographic shim, eliminating the bundled AWS-LC C/assembly library and routing all hashing, RSA, ECDSA, and Ed25519 operations through `package:boring`.
- Replace embedded `tokio`, `reqwest`, `hyper`, and `rustls` HTTP stack with a state-machine TUF bridge (`SigstoreTufUpdater`) driven by `dart:io` `HttpClient` while retaining `sigstore-tuf`'s full TUF root rotation, metadata verification, and target caching engine in Rust.
- Reduce precompiled `libsigstore_ffi` binary size by ~60% (3.99 MB to 1.51 MB for the Linux x64 dynamic library; 3.05 MB to 1.27 MB on macOS arm64, 3.15 MB to 1.29 MB on Windows x64).
- Upgrade `code_assets` to `^2.1.0` and `hooks` to `^2.2.0`.

## 0.1.5

- Update documentation and package description to correctly reference `sigstore-rust`.

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
