# Reusing the BoringSSL Packaged with the Dart SDK

The Dart SDK (`dart` and `dartaotruntime`) already compiles and statically links Google's [`//third_party/boringssl`](https://github.com/dart-lang/sdk/tree/main/third_party/boringssl) (`libcrypto` + `libssl`) to power `dart:io` (`SecureSocket`, `SecurityContext`, and X.509 TLS certificate validation).

This document explains:
1. Why `package:boring` cannot `dlopen(NULL)` an **unmodified** stock `dart` / `dartaotruntime` binary at runtime today.
2. Three concrete architectures for reusing the Dart SDK's bundled BoringSSL—both for **first-party tools inside `dart-lang/sdk`** (such as `dart pub` / `pkg/dartdev` using `boring_sigstore`) and for **external Dart packages** using `package:boring`'s build hook (`hook/build.dart`).

---

## 1. Why an Unmodified Stock `dart` Binary Cannot Be Reused Out-of-the-Box

Running `nm -D` on a stock `dart` or `dartaotruntime` executable shows **zero exported BoringSSL symbols** (only the `Dart_*` embedding API symbols and three weak `OPENSSL_memory_*` hooks). Three build settings in `dart-lang/sdk` prevent out-of-the-box runtime symbol lookup:

1. **Hidden Symbol Visibility (`-fvisibility=hidden` & Version Scripts):**
   - [`//third_party/boringssl/BUILD.gn`](https://github.com/dart-lang/sdk/blob/main/third_party/boringssl/BUILD.gn) compiles `source_set("boringssl")` with `BORINGSSL_IMPLEMENTATION` and default `-fvisibility=hidden`.
   - [`//runtime/bin/dart_exported_symbols.ld`](https://github.com/dart-lang/sdk/blob/main/runtime/bin/dart_exported_symbols.ld) (and its `.exp` / `.def` counterparts on macOS and Windows) explicitly restricts the dynamic symbol table (`.dynsym`) of `dart` and `dartaotruntime` to `Dart_*`.
2. **Linker Dead-Code Elimination (`--gc-sections` / `/OPT:REF` / `-dead_strip`):**
   - Because `dart:io` only calls the subset of BoringSSL used by TLS and `SecureSocket` (`SSL_*`, `X509_verify_cert`, SHA-2, AES, RSA/ECDSA), the linker strips unreferenced BoringSSL translation units and functions (such as `ED25519_verify`, `X25519`, or specific `CBS_get_any_asn1_element` helpers) from the final `dart` binary.
3. **`bssl_dart_` Symbol Prefixing:**
   - `package:boring` compiles BoringSSL with `-DBORINGSSL_PREFIX=bssl_dart` so that every `@Native` binding in [`lib/src/bindings/bindings.g.dart`](../lib/src/bindings/bindings.g.dart) looks up `bssl_dart_<symbol>` (`assetId: 'package:boring/boring.dart'`).
   - This prefix is essential when `package:boring` is bundled into Flutter apps or standalone binaries to avoid dynamic linker collisions with unprefixed system `libcrypto`/`libssl` or other native plugins, whereas `dart-lang/sdk` compiles `//third_party/boringssl` unprefixed.

---

## 2. Three Ways to Reuse the Dart SDK's BoringSSL

When building `dart-lang/sdk` (for example, integrating `package:boring` into `pkg/dartdev` for `dart pub` package attestation verification, or enabling zero-download SDK reuse for external packages), we control `//third_party/boringssl/BUILD.gn`, `//runtime/bin/BUILD.gn`, and `//utils/dartdev/BUILD.gn`.

| Strategy | Sharing Level | Extra SDK Binary Size | Extra `.so`/`.dylib`/`.dll` Files | New `sdk/DEPS` Required | Symbol Interposition Safety |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Strategy A: `bssl_dart_*` Trampolines inside `dart` / `dartaotruntime`** (`LookupInExecutable`) | **Binary-level** (shares `dart`'s linked `libcrypto` object code in RAM & disk) | **~80 – 120 KB** | **0** | **0** | **Safe** (unprefixed BoringSSL stays `-fvisibility=hidden`; only `bssl_dart_*` is exported) |
| **Strategy B: GN `shared_library("bssl_dart")` in `dart-sdk/bin/lib/`** (`DynamicLoadingSystem` / `local`) | **Source-level** (compiles `libbssl_dart.so` from `//third_party/boringssl/src`) | **~1.80 MB** | **1** (`libbssl_dart.so`) | **0** | **Safe** (`BORINGSSL_PREFIX=bssl_dart` + version script) |
| **Strategy C: Direct Unprefixed Exports from `dart`** | **Binary-level** | **~60 – 100 KB** | **0** | **0** | **Unsafe on ELF/Linux** (exporting unprefixed `X509_*`/`EVP_*` from `dart` risks colliding with OpenSSL 3.x FFI plugins) |

---

### Strategy A (Recommended): Binary-Level Reuse via `bssl_dart_*` Trampolines in `dart` / `dartaotruntime`

Instead of exporting all ~3,000 unprefixed BoringSSL symbols or recompiling `//third_party/boringssl` twice, we link a small generated C/C++ translation unit (`boring_sdk_exports.cc`) into `//runtime/bin:dart` and `//runtime/bin:dartaotruntime` containing **1-line `DART_EXPORT` wrapper trampolines** for the exact symbols declared in [`lib/src/bindings/bindings.g.dart`](../lib/src/bindings/bindings.g.dart).

#### 1. C Trampoline Target in `//runtime/bin/BUILD.gn`

```c
// runtime/bin/boring_sdk_exports.cc
// Auto-generated from package:boring's @Native symbol list.
#include <openssl/asn1.h>
#include <openssl/bn.h>
#include <openssl/bytestring.h>
#include <openssl/crypto.h>
#include <openssl/curve25519.h>
#include <openssl/evp.h>
#include <openssl/x509.h>

#include "include/dart_api.h"  // For DART_EXPORT

extern "C" {

DART_EXPORT int bssl_dart_X509_verify_cert(X509_STORE_CTX* ctx) {
  return X509_verify_cert(ctx);
}

DART_EXPORT int bssl_dart_CBS_get_any_asn1_element(
    CBS* cbs, CBS* out, unsigned* out_tag, size_t* out_header_len) {
  return CBS_get_any_asn1_element(cbs, out, out_tag, out_header_len);
}

DART_EXPORT int bssl_dart_ED25519_verify(
    const uint8_t* message, size_t message_len, const uint8_t signature[64],
    const uint8_t public_key[32]) {
  return ED25519_verify(message, message_len, signature, public_key);
}

// ... (236 trampolines for Sigstore verification, or ~310 for all of package:boring)

}  // extern "C"
```

And add `bssl_dart_*;` to `runtime/bin/dart_exported_symbols.ld` (alongside `runtime/bin/dart_exported_symbols.exp` on macOS and `.def` generation on Windows):

```ld
{
  global:
    Dart_*;
    bssl_dart_*;
    OPENSSL_memory_*;
  local:
    *;
};
```

#### Why This Works Cleanly
- **Zero Symbol Collisions:** All internal unprefixed BoringSSL functions (`X509_verify_cert`, `EVP_DigestVerify`, `SHA256`, etc.) remain `-fvisibility=hidden` inside `dart`. Any external FFI library loaded by a user that links against system OpenSSL 3.x will never collide with `dart`'s internal BoringSSL.
- **Prevents `--gc-sections` Stripping While Sharing 100% of `libcrypto` Object Code:** Because each `bssl_dart_*` function is marked `DART_EXPORT` and listed in `dart_exported_symbols.ld`, the linker retains any BoringSSL function not already called by `dart:io` (such as `ED25519_verify`), while **reusing 100% of the SHA-2, AES, ECDSA, RSA, X.509, `CBS` ASN.1, and `BIGNUM` machine code** already linked into `dart`. The net binary size increase to `dart` / `dartaotruntime` is only **~80–120 KB** (compared to **1.80 MB** for a separate `libbssl_dart.so`).
- **Zero Changes to `package:boring` Source Code:** Every `@Native(..., symbol: 'bssl_dart_...', assetId: 'package:boring/boring.dart')` annotation in `package:boring` works unmodified.

#### 2. Wiring Up `dartdev` (`dart pub`) Inside `dart-lang/sdk`
The Dart VM's native assets kernel synthesizer ([`pkg/vm/lib/native_assets/synthesizer.dart`](https://github.com/dart-lang/sdk/blob/main/pkg/vm/lib/native_assets/synthesizer.dart)) and runtime resolver ([`runtime/vm/ffi/native_assets.cc`](https://github.com/dart-lang/sdk/blob/main/runtime/vm/ffi/native_assets.cc)) natively support `['executable']` (`NativeAssets::DlopenExecutable`, which calls `dlopen(NULL, RTLD_LAZY)` on POSIX and `GetModuleHandle(NULL)` on Windows).

In `//utils/dartdev/BUILD.gn`, embedding a synthesized `vm:ffi:native-assets` library into `dartdev_aot.dart.snapshot`:

```yaml
format-version: [1, 0, 0]
native-assets:
  linux_x64:
    "package:boring/boring.dart": ["executable"]
```

instructs the Dart VM to resolve all `package:boring/boring.dart` symbols directly from the running `dart` / `dartaotruntime` process—with **zero external `.so`/`.dylib`/`.dll` files** and **zero runtime file I/O**.

#### 3. Wiring Up `hook/build.dart` for External `package:boring` Users (`LookupInExecutable`)
When Strategy A is present in the host Dart SDK, `package:boring`'s [`hook/build.dart`](../hook/build.dart) can also allow external Dart CLI/server packages and `dart test` runs to reuse the SDK's built-in `bssl_dart_*` symbols via `LookupInExecutable()` from `package:code_assets`:

```dart
// In hook/build.dart:
case BuildModeEnum.sdk:
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: _assetName, // 'boring.dart'
      linkMode: LookupInExecutable(),
    ),
  );
```

When `linkMode: LookupInExecutable()` is emitted by `hook/build.dart`, `package:boring` requires **zero network downloads and zero CMake/C compilation** during `dart run` and `dart test`.

---

### Strategy B: Source-Level Reuse via a GN `shared_library("bssl_dart")` Target in `//third_party/boringssl/BUILD.gn`

If the Dart VM team prefers not to add `bssl_dart_*` trampolines to `//runtime/bin:dart`'s dynamic export table, `dart-lang/sdk` can still reuse `//third_party/boringssl/src` at the **source and GN build level** by emitting `dart-sdk/bin/lib/libbssl_dart.so` (`.dylib` / `.dll`).

#### 1. Adding `shared_library("bssl_dart")` in `//third_party/boringssl/BUILD.gn`

```gn
# In //third_party/boringssl/BUILD.gn
shared_library("bssl_dart") {
  sources = crypto_sources
  public_configs = [ ":boringssl_config" ]
  cflags = [ "-fvisibility=hidden" ]
  defines = [
    "BORINGSSL_IMPLEMENTATION",
    "BORINGSSL_SHARED_LIBRARY",
    "BORINGSSL_PREFIX=bssl_dart",
  ]
  if (is_linux || is_android) {
    ldflags = [ "-Wl,--version-script=" +
                rebase_path("bssl_dart_exports.lds", root_build_dir) ]
  }
}
```

With a version script (`bssl_dart_exports.lds`) exporting only the `bssl_dart_*` symbols required by `package:boring` and `--gc-sections` enabled, `libbssl_dart.so` compiles to **1.80 MB** (`0.85 MB` gzipped) on Linux x64.

#### 2. Resolving `libbssl_dart.so` in `dartdev` and `hook/build.dart`
- **Inside `dartdev` (`//utils/dartdev/BUILD.gn`):** Map `"package:boring/boring.dart"` in `vm:ffi:native-assets` to `["relative", "../lib/libbssl_dart.so"]` (relative to `dart-sdk/bin/snapshots/dartdev_aot.dart.snapshot`).
- **In `package:boring`'s `hook/build.dart`:** Check whether `File.fromUri(Uri.file(Platform.resolvedExecutable).resolve('../lib/$dylibFileName'))` exists in the active Dart SDK before downloading from GitHub Releases in `_fetchPrebuiltBinary`. If present, copy or reference the SDK's `libbssl_dart` directly—giving offline and Linux-distro builds instant access to `libbssl_dart` with **zero new `DEPS` in `dart-lang/sdk`**.

---

### Strategy C: Direct Unprefixed Exports from `dart` (Why Strategy A Is Preferred)

A third theoretical option is adding the unprefixed BoringSSL functions (`X509_verify_cert`, `EVP_DigestSign`, `CBS_get_any_asn1_element`, etc.) directly to `runtime/bin/dart_exported_symbols.ld` and generating `package:boring`'s bindings without `BORINGSSL_PREFIX=bssl_dart` when targeting the SDK.

**Why Strategy A (`bssl_dart_*` trampolines) is strongly preferred over Strategy C:**
- On Linux/ELF systems, symbols exported in `.dynsym` by the main executable (`dart`) take precedence in the global dynamic symbol table (`RTLD_GLOBAL`).
- If `dart` exports unprefixed `EVP_*`, `X509_*`, or `SSL_*` symbols and a Dart application loads *another* native library or FFI plugin dynamically linked against system OpenSSL (`libcrypto.so.3`), the dynamic loader can route OpenSSL 3.x internal calls into BoringSSL (or vice versa), causing ABI segfaults.
- Exporting only the `bssl_dart_*` trampoline namespace (Strategy A) guarantees 100% symbol isolation while still achieving full binary-level code sharing inside `dart`.
