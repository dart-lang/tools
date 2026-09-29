[![Build Status](https://github.com/dart-lang/tools/actions/workflows/boring.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/boring.yaml)
[![pub package](https://img.shields.io/pub/v/boring.svg)](https://pub.dev/packages/boring)
[![package publisher](https://img.shields.io/pub/publisher/boring.svg)](https://pub.dev/packages/boring/publisher)

Raw `ffigen` bindings to Google's
[BoringSSL](https://boringssl.googlesource.com/boringssl/) (`bssl_dart`).

> [!WARNING]
> `package:boring` is not meant to be used directly by application developers.
> It is meant to facilitate code reuse for developers building higher-level
> cryptography packages on top of BoringSSL.

> [!NOTE]
> This package is currently experimental and published under the
> [labs.dart.dev](https://dart.dev/dart-team-packages) pub publisher in order
> to solicit feedback.
>
> For packages in the labs.dart.dev publisher we generally plan to either
> graduate the package into a supported publisher (dart.dev, tools.dart.dev)
> after a period of feedback and iteration, or discontinue the package.
> These packages have a much higher expected rate of API and breaking changes.
>
> Your feedback is valuable and will help us evolve this package. For general
> feedback, suggestions, and comments, please file an issue in the
> [bug tracker](https://github.com/dart-lang/tools/issues).

## Error Handling

BoringSSL signals failure through return values and pushes details onto a
per-thread error queue. A Dart isolate may resume on a different OS thread
after an `await`, and every package using `package:boring` on a thread shares
its queue, so:

- Read errors with `extractBoringSslError()`, which also clears the queue,
  right after the failing call. Don't leave an `await` in between, and don't
  defer it to a `finally` that may run after one, such as the release of an
  `async` `BoringArena.using`.
- Discard errors you ignore with `ERR_clear_error()`, for example when a failed
  signature verification just means `false`. Otherwise they are reported for
  the next, unrelated failure.
- Call `ERR_clear_error()` before a call whose errors you report, so errors
  left behind by other code aren't attributed to it.

## Native Asset Build Modes

Configured in `pubspec.yaml` under `hooks.user_defines.boring`:

```yaml
hooks:
  user_defines:
    boring:
      buildMode: fetch # 'fetch', 'checkout', or 'local'
```

- **`fetch`** *(default)*: Downloads prebuilt binaries from GitHub Releases
  verified against pinned SHA-256 checksums, falling back to local compilation
  if unavailable.
- **`checkout`**: Always compiles BoringSSL locally from bundled sources via
  CMake and Ninja.
- **`local`**: Uses a custom prebuilt dynamic library at `localPath`, which is
  bundled as is, without [tree-shaking](#tree-shaking).

`fetch` and `checkout` provide a dynamic library with all of BoringSSL when
linking is disabled (`dart run`, `dart test`, and Flutter debug builds), and a
static library for [tree-shaking](#tree-shaking) when it is enabled. Every
GitHub Release has both for each prebuilt target.

## Tree-Shaking

When linking is enabled (`dart build`, and Flutter profile and release builds),
`hook/link.dart` links a dynamic library with only the functions the
application uses from the static library. The bindings are annotated with
`@RecordUse()`, so the Dart compiler records which of them the application
calls, tears off, or takes the address of with `addresses.*`. For the
[example](example/boring_example.dart), the bundled library shrinks from 2.9 MB
to 240 KB on Linux x64.

- Use `addresses.X` rather than `Native.addressOf(X)` for the address of a
  function, for example for a `NativeFinalizer`. `Native.addressOf` isn't
  recorded, so the function would be missing from the library.
- Without recorded uses, for example with `flutter config
  --no-enable-record-use`, all functions are kept.
- Linking requires a C toolchain for the target (Clang or GCC, Xcode, MSVC, or
  the Android NDK). Without one, for example when cross-compiling, the `fetch`
  build mode bundles the prebuilt dynamic library instead, which is not
  tree-shaken, and prints a warning.

## Conformance Testing

CI checks the bundled BoringSSL and the generated bindings against two external
suites, calling BoringSSL directly through the bindings (see
[`test/conformance/`](test/conformance/)):

- [**Project Wycheproof**](https://github.com/C2SP/wycheproof)
  (`./tool/run_conformance_tests.sh`): AES-GCM, ChaCha20-Poly1305,
  XChaCha20-Poly1305, AES-CBC, AES Key Wrap, Ed25519, ECDSA (P-256, P-384,
  P-521), RSA PKCS#1 v1.5 and RSA-PSS signatures, RSA-OAEP, ECDH, HKDF, HMAC,
  and PBKDF2.
- [**x509-limbo**](https://x509-limbo.com) (`./tool/run_x509_limbo_tests.sh`):
  9,770 of the 9,793 path validation testcases run against `X509_verify_cert`,
  and 9,237 (94.5%) agree. The divergences, mostly name constraint types
  BoringSSL does not support and CA/Browser Forum profile checks it leaves to
  the caller, are listed and explained in
  [`test/conformance/x509_limbo_expected_failures.txt`][limbo-failures].

[limbo-failures]: test/conformance/x509_limbo_expected_failures.txt

## License

See [LICENSE](LICENSE) for details. BoringSSL is licensed under Apache 2.0 and
BSD-style licenses; see
[`third_party/boringssl/LICENSE`](third_party/boringssl/LICENSE).
