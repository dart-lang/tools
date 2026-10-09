## 0.4.2-wip

- Update BoringSSL to e98a6564.
- Moved the package to the
  [dart-lang/tools](https://github.com/dart-lang/tools) repository.
- The package is now licensed under the BSD 3-Clause license used by other
  Dart packages.
- An unknown `buildMode` under `hooks.user_defines.boring` is an error instead
  of silently using `fetch`.
- The `fetch` build mode honors the `HTTPS_PROXY` family of environment
  variables and no longer hangs on a stalled download.
- The prebuilt macOS libraries run on macOS 10.15 (x64) and 11 (arm64) and
  later, instead of only on the macOS version they were built on.
- The Windows libraries link the C runtime statically, so they don't require
  the Visual C++ Redistributable.
- The prebuilt libraries are built from the vendored BoringSSL by CI, which
  pins them in an automated pull request, so the `fetch` and `checkout` build
  modes use the same sources.
- Prebuilt libraries for Android (arm, arm64, x64) and iOS (arm64, and the
  arm64 and x64 simulators), so Flutter apps no longer compile BoringSSL from
  source.
- The libraries no longer reference libc++ when built with it, which failed
  to link on Android.

## 0.4.1

- Fixed `libbssl_dart.so` dynamically linking `libc++_shared.so` on Android when
  built from source with CMake (`LINKER_LANGUAGE C`).

## 0.4.0

- **Breaking**: `package:boring` now only exposes the raw `ffigen` BoringSSL
  bindings (`package:boring/bindings.dart`) plus a minimal FFI toolkit. The
  high-level Dart crypto, X.509, and ASN.1 APIs from 0.3.0 were removed.
- Added `opensslAllocator` (`OPENSSL_malloc` / `OPENSSL_free`, scrubbed with
  `OPENSSL_cleanse`) with `nativeFree`, `addresses.*` symbol addresses for all
  `*_free` / `*_cleanup` functions, `NativeHandle<T>`, and
  `extractBoringSslError()`.
- Added `BoringArena`, an `opensslAllocator`-backed arena with `using`,
  `onReleaseAll`, `move` (for BoringSSL's `set0` ownership transfer),
  Future-aware `BoringArena.run`, and `BoringArena.stream`, plus `copyBytes`,
  `cbs()`, `cbb()`, and `CBB.toBytes()`.
- Added tree-shaking: the bindings are annotated with `@RecordUse()`, and when
  linking is enabled (`dart build`, and Flutter profile and release builds),
  `hook/link.dart` links a dynamic library with only the functions the
  application uses. `addresses.*` are now getters of the `SymbolAddresses`
  extension, so their uses are recorded too.
- **Breaking**: Removed the bindings to 29 functions that BoringSSL declares but
  that aren't compiled, such as `EVP_bf_cbc` and `RSA_generate_key` from
  `decrepit/`. They failed to resolve when called.
- Every GitHub Release now has the dynamic and the static library for each
  prebuilt target. The Linux libraries are built on Ubuntu 22.04, and require
  glibc 2.35 instead of 2.38.

## 0.3.0

Expanded cryptographic primitives to match modern native application and
`package:webcrypto` capabilities:

- **X25519 Key Agreement**: Added `BoringX25519` (`generateKeyPair`,
  `publicKeyFromPrivate`, `computeSharedSecret`), `KeyType.x25519`,
  `BoringPrivateKey.generateX25519()`, and `deriveSharedSecret` / `deriveBits`
  support for X25519 keys.
- **Constant-Time Verification**: Added `BoringCrypto.timingSafeEqual` (wrapping
  `CRYPTO_memcmp`), `BoringHmac.verify`, and `BoringHmac.verifyStream`.
- **Key Generation & Raw Key Import/Export**: Added
  `BoringPrivateKey.generateEd25519()`, `BoringPrivateKey.fromRawKey()`,
  `BoringPublicKey.fromRawKey()`, and `.toRawBytes()` for 32-byte Ed25519/X25519
  keys, plus optional `password` support on `BoringPrivateKey.fromPem` and
  `toPem` for encrypted PKCS#8 PEM keys. Also allowed `BoringEd25519.sign` to
  accept a 32-byte seed directly.
- **PBKDF2**: Added `BoringPbkdf2.deriveBits` and `deriveKey` for password-based
  key derivation (RFC 2898 / PKCS #5 v2.0) across all supported hash algorithms.
- **Symmetric Ciphers (AES-CBC & AES-CTR)**: Added `BoringCipher` and
  `CipherAlgorithm` supporting AES-128/192/256 in CBC mode (with PKCS#7 padding)
  and CTR mode (standard 128-bit counter stream).
- **AES Key Wrap**: Added `BoringAesKeyWrap.wrap` and `unwrap` for RFC 3394 /
  NIST SP 800-38F key wrapping.
- **RSA-PSS**: Added Probabilistic Signature Scheme support to
  `BoringPrivateKey.sign` and `BoringPublicKey.verify` via `RsaSignaturePadding.pss`
  and configurable `pssSaltLength`.
- **RSA-OAEP**: Added `BoringPublicKey.encryptOaep` and
  `BoringPrivateKey.decryptOaep` for RFC 8017 asymmetric encryption with
  configurable OAEP hash, MGF1 hash, and optional labels.
- **ECDH Key Agreement**: Added `BoringPrivateKey.deriveSharedSecret` and
  `deriveBits` for elliptic-curve Diffie-Hellman key agreement across P-256,
  P-384, and P-521.
- **Streaming APIs**: Added stream-based operations:
  - `BoringDigest.hashStream` and `sha1Stream`/`sha224Stream`/`sha256Stream`/`sha384Stream`/`sha512Stream`/`blake2b256Stream`.
  - `BoringHmac.computeStream`, `verifyStream`, and `sha256Stream`/`sha384Stream`/`sha512Stream`.
  - `BoringPrivateKey.signStream` and `BoringPublicKey.verifyStream` for RSA,
    ECDSA, and Ed25519.
- **Deterministic Disposal & Memory Cleansing**: Added `.dispose()` to
  `BoringPrivateKey`, `BoringPublicKey`, `X509Certificate`, `X509Verifier`,
  `DigestContext`, and `HmacContext`, and ensured ephemeral secret buffers in
  FFI arenas are scrubbed via `OPENSSL_cleanse` before deallocation.
- **Wycheproof Conformance**: Added conformance test suites for AES-CBC, AES Key
  Wrap, PBKDF2, RSA-PSS, RSA-OAEP, and ECDH.

`X509Verifier` can now check peer identity, key usage and chain length, and the
package is validated against the [x509-limbo](https://x509-limbo.com) path
validation suite.

- **Breaking:** `X509Certificate.keyUsage` now returns `int?` (`null` when the
  certificate does not carry a `keyUsage` extension) instead of `0xFFFFFFFF`.
- `X509Certificate` gained `sha256Fingerprint`, `authorityKeyIdentifier`,
  `signatureAlgorithm` (OID), and `signatureAlgorithmName`.
- `X509Verifier` gained `addTrustedCertificates` and
  `addTrustedCertificatesPem`.
- `X509Verifier.verify` gained seven options:
  - `peerNames`: names the leaf must assert, as `X509PeerName.dnsName`,
    `X509PeerName.ipAddress` or `X509PeerName.emailAddress`. Several DNS names
    are matched with OR semantics.
  - `hostnameFlags`: `X509HostnameFlag.neverCheckSubject` (the default, which
    suppresses BoringSSL's legacy subject common name fallback) and
    `X509HostnameFlag.noWildcards`.
  - `purpose`: an `X509Purpose` enabling key usage and extended key usage
    checks, e.g. `X509Purpose.tlsServer`.
  - `maxIntermediates`: a chain length limit, excluding leaf and trust anchor.
  - `insecurelyAllowWeakSignatureDigests`: opts out of the weak digest
    rejection described below.
  - `insecurelyAllowWeakKeys` and `minimumRsaKeyBits`: opt out of, and tune,
    the key strength rejection described below.
- **Behaviour change:** `X509Verifier.verify` now rejects a chain containing a
  certificate signed with MD4, MD5 or SHA-1. `X509_verify_cert` applies no
  signature algorithm policy of its own — BoringSSL has neither OpenSSL's
  `X509_VERIFY_PARAM_set_auth_level` nor its `set1_sigalgs` — so the verified
  chain is walked afterwards. The trust anchor is exempt, since its
  self-signature is never verified. Pass
  `insecurelyAllowWeakSignatureDigests: true` to restore the old behaviour.
- **Behaviour change:** the same walk now also rejects weak public keys: RSA
  below `minimumRsaKeyBits` (2048 by default, as the CA/Browser Forum baseline
  requirements demand), EC on any curve other than P-256, P-384 and P-521, DSA,
  and keys BoringSSL cannot decode at all such as P-192. Unlike the digest
  check this includes the trust anchor, whose key signs the certificate below
  it. Ed25519, ML-DSA and future algorithms are deliberately left alone rather
  than rejected as unrecognised. Pass `insecurelyAllowWeakKeys: true` to
  restore the old behaviour.
- `X509VerificationResult` gained `errorDepth`, the position in the chain at
  which verification failed.
- Added the x509-limbo conformance suite (`./tool/run_x509_limbo_tests.sh`),
  covering 9,770 chain building and validation testcases. 94.5% agree with the
  suite; the remainder are listed with an explanation in
  `test/conformance/x509_limbo_expected_failures.txt`.

This release also removes hand-written parsing logic from the Dart layer. Every
ASN.1 operation is now delegated to BoringSSL, keeping `package:boring` a thin
wrapper rather than a reimplementation.

- **Breaking:** `Asn1Value.identifier` (the raw DER identifier octet) is
  replaced by `Asn1Value.tag`, which holds BoringSSL's `CBS_ASN1_TAG`. Use
  `tagClass`, `isConstructed`, and `tagNumber` instead of decoding it by hand.
- **Breaking:** the `Asn1Value` constructor is now private; values are produced
  by `Asn1Reader`.
- The DER reader is now backed by BoringSSL's `CBS` parser:
  - Tag/length parsing uses `CBS_get_any_asn1_element`.
  - `asObjectIdentifier()` uses `CBS_asn1_oid_to_text`.
  - `asInteger()` uses `CBS_is_valid_asn1_integer` with `BN_bin2bn`/`BN_bn2dec`.
  - `asBoolean()` uses `CBS_get_asn1_bool`.
  - `asString()` uses `ASN1_STRING_to_UTF8`, which correctly transcodes every
    ASN.1 string type BoringSSL supports.
  - `Asn1Tag` and `Asn1Class` now re-export BoringSSL's `CBS_ASN1_*` constants.
  - As a result, DER encoding rules are enforced by BoringSSL: non-minimal
    long-form lengths and non-minimal `INTEGER` encodings are now rejected.
- `Asn1Value.asString()` accepts an optional `stringType` for IMPLICIT
  context-specific tags, where the tag number identifies the `CHOICE`
  alternative rather than the underlying string type.
- Certificate validity times are parsed with `ASN1_TIME_to_posix` instead of
  slicing the `GeneralizedTime` string in Dart.
- Fixed `X509Extension.stringValue` mangling non-ASCII values in the raw
  (non-DER) fallback path, which decoded UTF-8 bytes as UTF-16 code units.
- Internal: the repeated FFI marshalling patterns are now shared combinators
  (`withResource`, `withOutputBuffer`, `withSizedOutput`, `takeOwnedString`,
  `withMemBioString`, `withMemBufBio`), removing every hand-written
  `try`/`finally` around a BoringSSL `X_new` / `X_free` pair and the
  duplicated BIO-to-string reader. This also fixes a latent bug in that reader,
  which decoded UTF-8 in fixed 1 KiB chunks and could split a multi-byte
  sequence across a chunk boundary.

## 0.2.0

- Added a minimal ASN.1 DER reader (`package:boring/asn1.dart`) for decoding the
  application-specific payloads of X.509 extensions:
  - `Asn1Reader`, `Asn1Value`, `Asn1Class`, `Asn1Tag`, and `Asn1Exception`.
  - Decodes strings, integers, booleans, object identifiers, and nested
    constructed elements, including long-form lengths and context-specific tags.
- Added X.509 v3 extension support to `X509Certificate`:
  - `extensions` enumerates every extension with its OID, short name,
    criticality, and raw DER payload.
  - `getExtension(oid)` and `getExtensionString(oid)` look up an extension by
    dotted-decimal OID, transparently unwrapping DER-encoded ASN.1 strings and
    falling back to raw UTF-8 payloads.
  - `subjectAlternativeNames` and `issuerAlternativeNames` decode
    `GeneralName` entries, with `emailAddresses`, `dnsNames`, and `uris`
    convenience getters.
  - `keyUsage`, `extendedKeyUsage`, `isCertificateAuthority`, and
    `subjectKeyIdentifier`.
- Added `X509Oid` constants for standard X.509 extensions, Certificate
  Transparency SCTs, and all Sigstore Fulcio OIDC extensions
  (`1.3.6.1.4.1.57264.1.*`), plus `KeyUsage` bit constants.
- Added a Project Wycheproof conformance test suite (`tool/run_conformance_tests.sh`)
  covering AEAD, Ed25519, ECDSA, RSA, HKDF, and HMAC.
- Added GitHub Actions CI running formatting, analysis, unit tests, and the
  conformance suite.

## 0.1.0

- Initial release of `package:boring`.
- High-performance cryptography and PKI powered by BoringSSL with Dart Native Assets.
- Isolated symbols with `bssl_dart` prefix to guarantee 100% collision-free execution alongside Flutter and Dart VM internal BoringSSL.
- Cryptographic primitives:
  - CSPRNG (`BoringRand.secureRandom`)
  - Digests (`BoringDigest`: SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, streaming `DigestContext`)
  - HMAC (`BoringHmac`: SHA-256, SHA-384, SHA-512, streaming `HmacContext`)
  - HKDF (`BoringHkdf`: extract, expand, deriveBits)
  - AEAD (`BoringAead`: AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305, XChaCha20-Poly1305)
  - Ed25519 (`BoringEd25519`: keypair generation, sign, verify)
  - Asymmetric Keys (`BoringPrivateKey`, `BoringPublicKey`: RSA, ECDSA P-256/P-384/P-521, PKCS#8 & SPKI DER/PEM)
- PKI & X.509:
  - Certificate parsing (`X509Certificate`: DER and PEM, metadata getters, public key extraction)
  - Chain verification (`X509Verifier`: trust store management, intermediate chain resolution, time-based verification)
