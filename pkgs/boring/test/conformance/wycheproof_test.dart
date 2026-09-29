// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Runs [Project Wycheproof](https://github.com/C2SP/wycheproof) test vectors
/// against the bundled BoringSSL, through the raw bindings.
///
/// Clone the vectors and run this suite with `./tool/run_conformance_tests.sh`.
/// The suite is skipped if the vectors are not found.
///
/// Each primitive at the end of this file is a short sequence of BoringSSL
/// calls, so the suite covers both the BoringSSL build and the generated
/// bindings for those functions.
library;

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:boring/bindings.dart' as ssl;
import 'package:test/test.dart';

typedef _Json = Map<String, dynamic>;

Directory? _findWycheproofDir() {
  final env = Platform.environment['WYCHEPROOF_DIR'];
  if (env != null && Directory(env).existsSync()) {
    return Directory(env);
  }

  const candidates = [
    'build/wycheproof/testvectors_v1',
    '../build/wycheproof/testvectors_v1',
    '/tmp/wycheproof/testvectors_v1',
  ];

  for (final candidate in candidates) {
    final d = Directory(candidate);
    if (d.existsSync()) return d;
  }
  return null;
}

void main() {
  final vectors = _findWycheproofDir();

  group('Project Wycheproof Conformance', () {
    if (vectors == null) {
      test(
        'Wycheproof test vectors available',
        () {},
        skip:
            'Wycheproof test vectors not found. '
            'Run ./tool/run_conformance_tests.sh to clone and run the suite.',
      );
      return;
    }

    /// Declares a test running [check] on the test cases in [filename].
    void suite(
      String filename,
      bool Function(_Json group, _Json testCase) check, {
      bool Function(_Json group)? where,
    }) => test(filename, () {
      _expectResults(File('${vectors.path}/$filename'), check, where: where);
    });

    group('HKDF', () {
      for (final (filename, md) in [
        ('hkdf_sha256_test.json', ssl.EVP_sha256),
        ('hkdf_sha384_test.json', ssl.EVP_sha384),
        ('hkdf_sha512_test.json', ssl.EVP_sha512),
      ]) {
        suite(
          filename,
          (_, t) => _matches(
            _hkdf(
              md(),
              _hex(t['ikm']),
              _hex(t['salt']),
              _hex(t['info']),
              t['size'] as int,
            ),
            t['okm'],
          ),
        );
      }
    });

    group('HMAC', () {
      for (final (filename, md) in [
        ('hmac_sha256_test.json', ssl.EVP_sha256),
        ('hmac_sha384_test.json', ssl.EVP_sha384),
        ('hmac_sha512_test.json', ssl.EVP_sha512),
      ]) {
        suite(
          filename,
          (_, t) =>
              _matches(_hmac(md(), _hex(t['key']), _hex(t['msg'])), t['tag']),
          // Truncated tags are left to the caller.
          where: (g) => g['tagSize'] == ssl.EVP_MD_size(md()) * 8,
        );
      }
    });

    group('AEAD', () {
      suite(
        'aes_gcm_test.json',
        (g, t) => _openMatches(
          g['keySize'] == 128
              ? ssl.EVP_aead_aes_128_gcm()
              : ssl.EVP_aead_aes_256_gcm(),
          t,
        ),
        where: (g) =>
            g['ivSize'] == 96 &&
            g['tagSize'] == 128 &&
            (g['keySize'] == 128 || g['keySize'] == 256),
      );
      suite(
        'chacha20_poly1305_test.json',
        (_, t) => _openMatches(ssl.EVP_aead_chacha20_poly1305(), t),
        where: (g) => g['ivSize'] == 96 && g['tagSize'] == 128,
      );
      suite(
        'xchacha20_poly1305_test.json',
        (_, t) => _openMatches(ssl.EVP_aead_xchacha20_poly1305(), t),
        where: (g) => g['ivSize'] == 192 && g['tagSize'] == 128,
      );
    });

    group('Ed25519', () {
      suite(
        'ed25519_test.json',
        (g, t) =>
            _verify(_hex(g['publicKeyDer']), _hex(t['msg']), _hex(t['sig'])),
      );
    });

    group('ECDSA', () {
      for (final (filename, md) in [
        ('ecdsa_secp256r1_sha256_test.json', ssl.EVP_sha256),
        ('ecdsa_secp384r1_sha384_test.json', ssl.EVP_sha384),
        ('ecdsa_secp521r1_sha512_test.json', ssl.EVP_sha512),
      ]) {
        suite(
          filename,
          (g, t) => _verify(
            _hex(g['publicKeyDer']),
            _hex(t['msg']),
            _hex(t['sig']),
            md: md(),
          ),
        );
      }
    });

    group('RSA PKCS#1 v1.5 Signatures', () {
      for (final bits in [2048, 3072, 4096]) {
        suite(
          'rsa_signature_${bits}_sha256_test.json',
          (g, t) => _verify(
            _hex(g['publicKeyDer']),
            _hex(t['msg']),
            _hex(t['sig']),
            md: ssl.EVP_sha256(),
          ),
        );
      }
    });

    group('AES-CBC', () {
      suite(
        'aes_cbc_pkcs5_test.json',
        (_, t) => _matches(
          _aesCbcDecrypt(_hex(t['key']), _hex(t['iv']), _hex(t['ct'])),
          t['msg'],
        ),
      );
    });

    group('AES Key Wrap', () {
      suite(
        'aes_wrap_test.json',
        (_, t) =>
            _matches(_aesKeyUnwrap(_hex(t['key']), _hex(t['ct'])), t['msg']),
      );
    });

    group('PBKDF2', () {
      for (final (filename, md) in [
        ('pbkdf2_hmacsha1_test.json', ssl.EVP_sha1),
        ('pbkdf2_hmacsha224_test.json', ssl.EVP_sha224),
        ('pbkdf2_hmacsha256_test.json', ssl.EVP_sha256),
        ('pbkdf2_hmacsha384_test.json', ssl.EVP_sha384),
        ('pbkdf2_hmacsha512_test.json', ssl.EVP_sha512),
      ]) {
        suite(
          filename,
          (_, t) => _matches(
            _pbkdf2(
              md(),
              _hex(t['password']),
              _hex(t['salt']),
              t['iterationCount'] as int,
              t['dkLen'] as int,
            ),
            t['dk'],
          ),
        );
      }
    });

    group('RSA-PSS Signatures', () {
      for (final bits in [2048, 3072, 4096]) {
        suite(
          'rsa_pss_${bits}_sha256_mgf1_32_test.json',
          (g, t) => _verify(
            _hex(g['publicKeyDer']),
            _hex(t['msg']),
            _hex(t['sig']),
            md: ssl.EVP_sha256(),
            pssSaltLength: g['sLen'] as int,
          ),
        );
      }
    });

    group('RSA-OAEP Decryption', () {
      for (final bits in [2048, 3072, 4096]) {
        suite(
          'rsa_oaep_${bits}_sha256_mgf1sha256_test.json',
          (g, t) => _matches(
            _rsaOaepDecrypt(
              _hex(g['privateKeyPkcs8']),
              _hex(t['ct']),
              _hex(t['label']),
            ),
            t['msg'],
          ),
        );
      }
    });

    group('ECDH Key Agreement', () {
      for (final curve in ['secp256r1', 'secp384r1', 'secp521r1']) {
        suite(
          'ecdh_${curve}_pem_test.json',
          (_, t) => _matches(
            _ecdh(t['private'] as String, t['public'] as String),
            t['shared'],
          ),
        );
      }
    });
  });
}

/// Runs [check] on the test cases in the Wycheproof file [file], skipping test
/// groups that [where] rejects.
///
/// [check] returns whether BoringSSL accepted the test case. `valid` test cases
/// must be accepted and `invalid` ones rejected, while `acceptable` ones may go
/// either way.
void _expectResults(
  File file,
  bool Function(_Json group, _Json testCase) check, {
  bool Function(_Json group)? where,
}) {
  final json = jsonDecode(file.readAsStringSync()) as _Json;
  var checked = 0;
  for (final group in (json['testGroups'] as List).cast<_Json>()) {
    if (where != null && !where(group)) continue;
    for (final testCase in (group['tests'] as List).cast<_Json>()) {
      final bool accepted;
      try {
        accepted = check(group, testCase);
      } finally {
        // Rejections leave errors on BoringSSL's thread-local error queue.
        ssl.ERR_clear_error();
      }
      checked++;
      final result = testCase['result'] as String;
      if (result == 'acceptable') continue;
      expect(
        accepted,
        result == 'valid',
        reason: 'tcId ${testCase['tcId']} is $result: ${testCase['comment']}',
      );
    }
  }
  expect(checked, isPositive, reason: 'No test cases found in ${file.path}');
}

/// Decodes a Wycheproof hex string.
Uint8List _hex(Object? hex) {
  final digits = hex as String;
  if (digits.length.isOdd) {
    throw FormatException('Odd number of hex digits', digits);
  }
  final bytes = Uint8List(digits.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(digits.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return bytes;
}

/// Whether [actual] is not null and hex-encodes to [expected].
bool _matches(Uint8List? actual, Object? expected) =>
    actual != null &&
    actual.map((b) => b.toRadixString(16).padLeft(2, '0')).join() == expected;

/// Whether the AEAD test case [t] opens under [aead] to its plaintext.
bool _openMatches(ffi.Pointer<ssl.EVP_AEAD> aead, _Json t) => _matches(
  _aeadOpen(
    aead,
    _hex(t['key']),
    _hex(t['iv']),
    _hex('${t['ct']}${t['tag']}'),
    _hex(t['aad']),
  ),
  t['msg'],
);

// The primitives below return null (or false) when BoringSSL rejects their
// inputs. Every BoringArena allocation is scrubbed by OPENSSL_free on release.

/// HKDF (RFC 5869) of [length] bytes.
Uint8List? _hkdf(
  ffi.Pointer<ssl.EVP_MD> md,
  List<int> ikm,
  List<int> salt,
  List<int> info,
  int length,
) => ssl.BoringArena.run((arena) {
  final out = arena<ffi.Uint8>(length);
  if (ssl.HKDF(
        out,
        length,
        md,
        arena.copyBytes(ikm),
        ikm.length,
        arena.copyBytes(salt),
        salt.length,
        arena.copyBytes(info),
        info.length,
      ) !=
      1) {
    return null;
  }
  return Uint8List.fromList(out.asTypedList(length));
});

/// HMAC (RFC 2104) of [message], with the full-length tag.
Uint8List? _hmac(
  ffi.Pointer<ssl.EVP_MD> md,
  List<int> key,
  List<int> message,
) => ssl.BoringArena.run((arena) {
  final out = arena<ffi.Uint8>(ssl.EVP_MD_size(md));
  final outLen = arena<ffi.UnsignedInt>();
  final result = ssl.HMAC(
    md,
    arena.copyBytes(key),
    key.length,
    arena.copyBytes(message),
    message.length,
    out,
    outLen,
  );
  if (result == ffi.nullptr) return null;
  return Uint8List.fromList(out.asTypedList(outLen.value));
});

/// Opens [sealed] (ciphertext followed by tag) with [aead].
Uint8List? _aeadOpen(
  ffi.Pointer<ssl.EVP_AEAD> aead,
  List<int> key,
  List<int> nonce,
  List<int> sealed,
  List<int> aad,
) => ssl.BoringArena.run((arena) {
  final ctx = ssl.EVP_AEAD_CTX_new(
    aead,
    arena.copyBytes(key),
    key.length,
    ssl.EVP_AEAD_DEFAULT_TAG_LENGTH,
  );
  if (ctx == ffi.nullptr) return null;
  arena.using(ctx, ssl.EVP_AEAD_CTX_free);
  final out = arena<ffi.Uint8>(sealed.length);
  final outLen = arena<ffi.Size>();
  if (ssl.EVP_AEAD_CTX_open(
        ctx,
        out,
        outLen,
        sealed.length,
        arena.copyBytes(nonce),
        nonce.length,
        arena.copyBytes(sealed),
        sealed.length,
        arena.copyBytes(aad),
        aad.length,
      ) !=
      1) {
    return null;
  }
  return Uint8List.fromList(out.asTypedList(outLen.value));
});

/// Verifies [signature] over [message] with the DER-encoded
/// SubjectPublicKeyInfo [spki].
///
/// [md] is the message digest, which Ed25519 does not take. RSA keys use
/// PKCS #1 v1.5 padding, unless [pssSaltLength] is given for RSA-PSS.
bool _verify(
  List<int> spki,
  List<int> message,
  List<int> signature, {
  ffi.Pointer<ssl.EVP_MD>? md,
  int? pssSaltLength,
}) => ssl.BoringArena.run((arena) {
  final key = ssl.EVP_parse_public_key(arena.cbs(spki));
  if (key == ffi.nullptr) return false;
  arena.using(key, ssl.EVP_PKEY_free);
  final ctx = arena.using(ssl.EVP_MD_CTX_new(), ssl.EVP_MD_CTX_free);
  final pctx = arena<ffi.Pointer<ssl.EVP_PKEY_CTX>>();
  if (ssl.EVP_DigestVerifyInit(
        ctx,
        pctx,
        md ?? ffi.nullptr,
        ffi.nullptr,
        key,
      ) !=
      1) {
    return false;
  }
  if (pssSaltLength != null &&
      (ssl.EVP_PKEY_CTX_set_rsa_padding(
                pctx.value,
                ssl.RSA_PKCS1_PSS_PADDING,
              ) !=
              1 ||
          ssl.EVP_PKEY_CTX_set_rsa_pss_saltlen(pctx.value, pssSaltLength) !=
              1)) {
    return false;
  }
  return ssl.EVP_DigestVerify(
        ctx,
        arena.copyBytes(signature),
        signature.length,
        arena.copyBytes(message),
        message.length,
      ) ==
      1;
});

/// AES-CBC decryption with PKCS #7 padding.
Uint8List? _aesCbcDecrypt(
  List<int> key,
  List<int> iv,
  List<int> ciphertext,
) => ssl.BoringArena.run((arena) {
  final cipher = switch (key.length) {
    16 => ssl.EVP_aes_128_cbc(),
    24 => ssl.EVP_aes_192_cbc(),
    32 => ssl.EVP_aes_256_cbc(),
    _ => null,
  };
  // EVP_DecryptInit_ex reads a full IV, however long the buffer is.
  if (cipher == null || iv.length != ssl.EVP_CIPHER_iv_length(cipher)) {
    return null;
  }
  final ctx = arena.using(ssl.EVP_CIPHER_CTX_new(), ssl.EVP_CIPHER_CTX_free);
  if (ssl.EVP_DecryptInit_ex(
        ctx,
        cipher,
        ffi.nullptr,
        arena.copyBytes(key),
        arena.copyBytes(iv),
      ) !=
      1) {
    return null;
  }
  final out = arena<ffi.Uint8>(
    ciphertext.length + ssl.EVP_CIPHER_block_size(cipher),
  );
  final outLen = arena<ffi.Int>();
  if (ssl.EVP_DecryptUpdate(
        ctx,
        out,
        outLen,
        arena.copyBytes(ciphertext),
        ciphertext.length,
      ) !=
      1) {
    return null;
  }
  final updated = outLen.value;
  if (ssl.EVP_DecryptFinal_ex(ctx, out + updated, outLen) != 1) return null;
  return Uint8List.fromList(out.asTypedList(updated + outLen.value));
});

/// AES key unwrap (RFC 3394).
Uint8List? _aesKeyUnwrap(List<int> key, List<int> wrapped) =>
    ssl.BoringArena.run((arena) {
      // AES_unwrap_key rejects these too, but the output is sized from them.
      if (wrapped.length < 24 || wrapped.length % 8 != 0) return null;
      final aesKey = arena<ssl.AES_KEY>();
      if (ssl.AES_set_decrypt_key(
            arena.copyBytes(key),
            key.length * 8,
            aesKey,
          ) !=
          0) {
        return null;
      }
      final out = arena<ffi.Uint8>(wrapped.length - 8);
      final written = ssl.AES_unwrap_key(
        aesKey,
        ffi.nullptr,
        out,
        arena.copyBytes(wrapped),
        wrapped.length,
      );
      if (written <= 0) return null;
      return Uint8List.fromList(out.asTypedList(written));
    });

/// PBKDF2 (RFC 8018) with HMAC, deriving [length] bytes.
Uint8List? _pbkdf2(
  ffi.Pointer<ssl.EVP_MD> md,
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) => ssl.BoringArena.run((arena) {
  final out = arena<ffi.Uint8>(length);
  if (ssl.PKCS5_PBKDF2_HMAC(
        arena.copyBytes(password),
        password.length,
        arena.copyBytes(salt),
        salt.length,
        iterations,
        md,
        length,
        out,
      ) !=
      1) {
    return null;
  }
  return Uint8List.fromList(out.asTypedList(length));
});

/// RSA-OAEP decryption with SHA-256 and MGF1-SHA-256, using the PKCS #8
/// private key [pkcs8].
Uint8List? _rsaOaepDecrypt(
  List<int> pkcs8,
  List<int> ciphertext,
  List<int> label,
) => ssl.BoringArena.run((arena) {
  final key = ssl.EVP_parse_private_key(arena.cbs(pkcs8));
  if (key == ffi.nullptr) return null;
  arena.using(key, ssl.EVP_PKEY_free);
  final ctx = arena.using(
    ssl.EVP_PKEY_CTX_new(key, ffi.nullptr),
    ssl.EVP_PKEY_CTX_free,
  );
  if (ssl.EVP_PKEY_decrypt_init(ctx) != 1 ||
      ssl.EVP_PKEY_CTX_set_rsa_padding(ctx, ssl.RSA_PKCS1_OAEP_PADDING) != 1 ||
      ssl.EVP_PKEY_CTX_set_rsa_oaep_md(ctx, ssl.EVP_sha256()) != 1 ||
      ssl.EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, ssl.EVP_sha256()) != 1) {
    return null;
  }
  if (label.isNotEmpty) {
    final copy = arena.copyBytes<ffi.Uint8>(label);
    if (ssl.EVP_PKEY_CTX_set0_rsa_oaep_label(ctx, copy, label.length) != 1) {
      return null;
    }
    arena.move(copy); // `ctx` now owns the label.
  }
  final input = arena.copyBytes<ffi.Uint8>(ciphertext);
  final outLen = arena<ffi.Size>();
  if (ssl.EVP_PKEY_decrypt(
        ctx,
        ffi.nullptr,
        outLen,
        input,
        ciphertext.length,
      ) !=
      1) {
    return null;
  }
  final out = arena<ffi.Uint8>(outLen.value);
  if (ssl.EVP_PKEY_decrypt(ctx, out, outLen, input, ciphertext.length) != 1) {
    return null;
  }
  return Uint8List.fromList(out.asTypedList(outLen.value));
});

/// ECDH shared secret between the PEM-encoded private and public keys.
Uint8List? _ecdh(String privatePem, String publicPem) =>
    ssl.BoringArena.run((arena) {
      final private = _readPem(
        arena,
        privatePem,
        ssl.PEM_read_bio_PrivateKey,
        ssl.EVP_PKEY_free,
      );
      final public = _readPem(
        arena,
        publicPem,
        ssl.PEM_read_bio_PUBKEY,
        ssl.EVP_PKEY_free,
      );
      if (private == ffi.nullptr || public == ffi.nullptr) return null;
      final ctx = arena.using(
        ssl.EVP_PKEY_CTX_new(private, ffi.nullptr),
        ssl.EVP_PKEY_CTX_free,
      );
      final outLen = arena<ffi.Size>();
      if (ssl.EVP_PKEY_derive_init(ctx) != 1 ||
          ssl.EVP_PKEY_derive_set_peer(ctx, public) != 1 ||
          ssl.EVP_PKEY_derive(ctx, ffi.nullptr, outLen) != 1) {
        return null;
      }
      final out = arena<ffi.Uint8>(outLen.value);
      if (ssl.EVP_PKEY_derive(ctx, out, outLen) != 1) return null;
      return Uint8List.fromList(out.asTypedList(outLen.value));
    });

/// Parses the first PEM block in [pem] with [read], returning the result owned
/// by [arena] (released with [free]), or `nullptr` if it cannot be parsed.
ffi.Pointer<T> _readPem<T extends ffi.NativeType>(
  ssl.BoringArena arena,
  String pem,
  ffi.Pointer<T> Function(
    ffi.Pointer<ssl.BIO>,
    ffi.Pointer<ffi.Pointer<T>>,
    ffi.Pointer<ssl.pem_password_cb>,
    ffi.Pointer<ffi.Void>,
  )
  read,
  void Function(ffi.Pointer<T>) free,
) {
  final bytes = utf8.encode(pem);
  // BIO_new_mem_buf does not copy, and the arena releases the BIO first.
  final bio = arena.using(
    ssl.BIO_new_mem_buf(arena.copyBytes(bytes), bytes.length),
    ssl.BIO_free,
  );
  final result = read(bio, ffi.nullptr, ffi.nullptr, ffi.nullptr);
  return result == ffi.nullptr ? result : arena.using(result, free);
}
