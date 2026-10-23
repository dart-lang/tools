// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;

import 'package:boring/boring.dart' as bssl;

import 'bindings/lib.g.dart';

bool _boringInitialized = false;

/// Ensures `package:boring` (`libbssl_dart`) function pointers have been
/// registered with the underlying `sigstore_ffi` Rust library in the current
/// isolate.
void ensureBoringInitialized() {
  if (_boringInitialized) return;
  SigstoreVerifier.initBoring(_boringSymbolAddresses());
  _boringInitialized = true;
}

/// Returns the native symbol address of [pointer] while evaluating [tearOff] at
/// runtime so `@RecordUse()` records a tear-off reference to the `@Native`
/// function in `package:boring`.
///
/// Dart's `Native.addressOf` is not tracked as a `@RecordUse()`, and
/// `package:boring` (`0.4.1`) only exposes `@RecordUse()`-annotated
/// `bssl.addresses.*` getters for `*_free` and `*_cleanup` functions. Tearing
/// off the `@Native` function is tracked by `@RecordUse()` in
/// `recordedUses.calls` without invoking the C function, and checking
/// `identityHashCode(tearOff)` ensures the tear-off is evaluated at runtime
/// rather than tree-shaken as dead code.
int _addressOf(Function tearOff, ffi.Pointer<ffi.NativeType> pointer) =>
    identityHashCode(tearOff) == 0 ? 0 : pointer.address;

/// Returns the addresses of the 25 BoringSSL functions required by
/// `rust/src/boring_provider.rs` (`BoringSymbols`).
///
/// All 25 functions are required at runtime because `sigstore-verify` and
/// `sigstore-tuf` dispatch digest and signature algorithms dynamically based on
/// the certificates and keys in the runtime bundle or TUF metadata.
List<int> _boringSymbolAddresses() => <int>[
  _addressOf(
    bssl.ERR_clear_error,
    ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function()>>(
      bssl.ERR_clear_error,
    ),
  ),
  _addressOf(
    bssl.EVP_sha256,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_MD> Function()>
    >(bssl.EVP_sha256),
  ),
  _addressOf(
    bssl.EVP_sha384,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_MD> Function()>
    >(bssl.EVP_sha384),
  ),
  _addressOf(
    bssl.EVP_sha512,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_MD> Function()>
    >(bssl.EVP_sha512),
  ),
  _addressOf(
    bssl.EVP_MD_CTX_new,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_MD_CTX> Function()>
    >(bssl.EVP_MD_CTX_new),
  ),
  bssl.addresses.EVP_MD_CTX_free.address,
  _addressOf(
    bssl.EVP_DigestInit_ex,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_MD_CTX>,
          ffi.Pointer<bssl.EVP_MD>,
          ffi.Pointer<bssl.ENGINE>,
        )
      >
    >(bssl.EVP_DigestInit_ex),
  ),
  _addressOf(
    bssl.EVP_DigestUpdate,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_MD_CTX>,
          ffi.Pointer<ffi.Void>,
          ffi.Size,
        )
      >
    >(bssl.EVP_DigestUpdate),
  ),
  _addressOf(
    bssl.EVP_DigestFinal_ex,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_MD_CTX>,
          ffi.Pointer<ffi.Uint8>,
          ffi.Pointer<ffi.UnsignedInt>,
        )
      >
    >(bssl.EVP_DigestFinal_ex),
  ),
  _addressOf(
    bssl.EVP_DigestVerifyInit,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_MD_CTX>,
          ffi.Pointer<ffi.Pointer<bssl.EVP_PKEY_CTX>>,
          ffi.Pointer<bssl.EVP_MD>,
          ffi.Pointer<bssl.ENGINE>,
          ffi.Pointer<bssl.EVP_PKEY>,
        )
      >
    >(bssl.EVP_DigestVerifyInit),
  ),
  _addressOf(
    bssl.EVP_DigestVerify,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_MD_CTX>,
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
        )
      >
    >(bssl.EVP_DigestVerify),
  ),
  bssl.addresses.EVP_PKEY_free.address,
  _addressOf(
    bssl.EVP_PKEY_CTX_new,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Pointer<bssl.EVP_PKEY_CTX> Function(
          ffi.Pointer<bssl.EVP_PKEY>,
          ffi.Pointer<bssl.ENGINE>,
        )
      >
    >(bssl.EVP_PKEY_CTX_new),
  ),
  bssl.addresses.EVP_PKEY_CTX_free.address,
  _addressOf(
    bssl.EVP_PKEY_verify_init,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Int Function(ffi.Pointer<bssl.EVP_PKEY_CTX>)>
    >(bssl.EVP_PKEY_verify_init),
  ),
  _addressOf(
    bssl.EVP_PKEY_verify,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_PKEY_CTX>,
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
        )
      >
    >(bssl.EVP_PKEY_verify),
  ),
  _addressOf(
    bssl.EVP_PKEY_CTX_set_rsa_padding,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(ffi.Pointer<bssl.EVP_PKEY_CTX>, ffi.Int)
      >
    >(bssl.EVP_PKEY_CTX_set_rsa_padding),
  ),
  _addressOf(
    bssl.EVP_PKEY_CTX_set_rsa_pss_saltlen,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(ffi.Pointer<bssl.EVP_PKEY_CTX>, ffi.Int)
      >
    >(bssl.EVP_PKEY_CTX_set_rsa_pss_saltlen),
  ),
  _addressOf(
    bssl.EVP_PKEY_CTX_set_signature_md,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Int Function(
          ffi.Pointer<bssl.EVP_PKEY_CTX>,
          ffi.Pointer<bssl.EVP_MD>,
        )
      >
    >(bssl.EVP_PKEY_CTX_set_signature_md),
  ),
  _addressOf(
    bssl.EVP_pkey_ec_p256,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_PKEY_ALG> Function()>
    >(bssl.EVP_pkey_ec_p256),
  ),
  _addressOf(
    bssl.EVP_pkey_ec_p384,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_PKEY_ALG> Function()>
    >(bssl.EVP_pkey_ec_p384),
  ),
  _addressOf(
    bssl.EVP_pkey_ed25519,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_PKEY_ALG> Function()>
    >(bssl.EVP_pkey_ed25519),
  ),
  _addressOf(
    bssl.EVP_pkey_rsa,
    ffi.Native.addressOf<
      ffi.NativeFunction<ffi.Pointer<bssl.EVP_PKEY_ALG> Function()>
    >(bssl.EVP_pkey_rsa),
  ),
  _addressOf(
    bssl.EVP_PKEY_from_raw_public_key,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Pointer<bssl.EVP_PKEY> Function(
          ffi.Pointer<bssl.EVP_PKEY_ALG>,
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
        )
      >
    >(bssl.EVP_PKEY_from_raw_public_key),
  ),
  _addressOf(
    bssl.EVP_PKEY_from_subject_public_key_info,
    ffi.Native.addressOf<
      ffi.NativeFunction<
        ffi.Pointer<bssl.EVP_PKEY> Function(
          ffi.Pointer<ffi.Uint8>,
          ffi.Size,
          ffi.Pointer<ffi.Pointer<bssl.EVP_PKEY_ALG>>,
          ffi.Size,
        )
      >
    >(bssl.EVP_PKEY_from_subject_public_key_info),
  ),
];
