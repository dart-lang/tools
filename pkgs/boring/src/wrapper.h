// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Entry point for `tool/ffigen.dart` that includes the BoringSSL headers for
// which Dart FFI bindings are generated.

#ifndef BORING_WRAPPER_H
#define BORING_WRAPPER_H

// Expose BoringSSL's inline helper functions (such as `CBS_len` and `CBB_data`)
// as `static inline` definitions in the headers, and compile this file as a C
// translation unit in `src/CMakeLists.txt` with `static` stripped so the shared
// and static libraries export symbols for them.
#define BORINGSSL_ALWAYS_USE_STATIC_INLINE

#include <openssl/base.h>
#include <openssl/crypto.h>
#include <openssl/digest.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/hkdf.h>
#include <openssl/aead.h>
#include <openssl/aes.h>
#include <openssl/bn.h>
// `CBB`'s C definition in `<openssl/bytestring.h>` uses an anonymous union that
// `ffigen` would otherwise emit as an opaque struct. Hide the upstream struct
// names while including the header and redeclare them with a named union field
// (`u`) so `CBB` can be allocated directly in Dart.
#define cbb_buffer_st _bssl_hidden_cbb_buffer_st
#define cbb_child_st _bssl_hidden_cbb_child_st
#define cbb_st _bssl_hidden_cbb_st
#include <openssl/bytestring.h>
#undef cbb_st
#undef cbb_child_st
#undef cbb_buffer_st

struct cbb_buffer_st {
  uint8_t *buf;
  size_t len;
  size_t cap;
  unsigned flags;
};

struct cbb_child_st {
  struct cbb_buffer_st *base;
  size_t offset;
  uint8_t pending_len_len;
  uint8_t pending_is_asn1;
};

struct cbb_st {
  CBB *child;
  char is_child;
  union {
    struct cbb_buffer_st base;
    struct cbb_child_st child;
  } u;
};
#include <openssl/cipher.h>
#include <openssl/ec.h>
#include <openssl/ec_key.h>
#include <openssl/ecdh.h>
#include <openssl/ecdsa.h>
#include <openssl/rsa.h>
#include <openssl/curve25519.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/mem.h>
#include <openssl/bio.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>
#include <openssl/x509v3.h>

#endif // BORING_WRAPPER_H
