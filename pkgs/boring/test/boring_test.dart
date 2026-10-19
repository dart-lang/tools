// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:boring/bindings.dart';
import 'package:boring/bindings.dart' as ssl;
import 'package:ffi/ffi.dart' show using;
import 'package:test/test.dart';

void main() {
  group('package:boring/bindings.dart', () {
    test('BORINGSSL_self_test passes', () {
      expect(ssl.BORINGSSL_self_test(), equals(1));
    });

    test('opensslAllocator allocates, frees, and exposes nativeFree', () {
      using((arena) {
        final buf = arena<ffi.Uint8>(32);
        expect(ssl.RAND_bytes(buf, 32), equals(1));
        final bytes = Uint8List.fromList(buf.asTypedList(32));
        expect(bytes.any((b) => b != 0), isTrue);
      }, opensslAllocator);

      final raw = opensslAllocator<ffi.Uint8>(16);
      expect(ssl.RAND_bytes(raw, 16), equals(1));
      final view = raw.asTypedList(16, finalizer: opensslAllocator.nativeFree);
      expect(view.length, equals(16));
    });

    test(
      'NativeHandle wraps BoringSSL pointers with finalizer and dispose',
      () {
        final pkey = NativeHandle(
          ssl.EVP_PKEY_new(),
          ssl.addresses.EVP_PKEY_free,
        );
        expect(pkey.isDisposed, isFalse);
        expect(ssl.EVP_PKEY_id.invoke(pkey), equals(ssl.EVP_PKEY_NONE));

        pkey.dispose();
        expect(pkey.isDisposed, isTrue);
        // Idempotent second dispose does not double-free:
        pkey.dispose();
        expect(() => ssl.EVP_PKEY_id.invoke(pkey), throwsStateError);
      },
    );

    test('EVP_sha256 computes expected digest', () {
      final digest = using((arena) {
        final input = utf8.encode('abc');
        final inPtr = arena<ffi.Uint8>(input.length);
        inPtr.asTypedList(input.length).setAll(0, input);

        final md = ssl.EVP_sha256();
        final outPtr = arena<ffi.Uint8>(ssl.EVP_MD_size(md));
        final outLen = arena<ffi.UnsignedInt>();

        final ctx = ssl.EVP_MD_CTX_new();
        try {
          expect(ssl.EVP_DigestInit(ctx, md), equals(1));
          expect(
            ssl.EVP_DigestUpdate(ctx, inPtr.cast(), input.length),
            equals(1),
          );
          expect(ssl.EVP_DigestFinal(ctx, outPtr, outLen), equals(1));
        } finally {
          ssl.EVP_MD_CTX_free(ctx);
        }

        return Uint8List.fromList(outPtr.asTypedList(outLen.value));
      }, opensslAllocator);

      final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
    });

    test('CBB and CBS are concrete ffi.Structs usable with Allocator', () {
      expect(ffi.sizeOf<CBB>(), greaterThan(0));
      expect(ffi.sizeOf<CBS>(), greaterThan(0));

      using((arena) {
        final cbb = arena<CBB>();
        ssl.CBB_zero(cbb);
        expect(ssl.CBB_init(cbb, 64), equals(1));
        try {
          expect(ssl.CBB_add_u8(cbb, 0x2a), equals(1));
          expect(ssl.CBB_flush(cbb), equals(1));
          expect(ssl.CBB_len(cbb), equals(1));

          final cbs = arena<CBS>()
            ..ref.data = ssl.CBB_data(cbb)
            ..ref.len = ssl.CBB_len(cbb);
          final out = arena<ffi.Uint8>();
          expect(ssl.CBS_get_u8(cbs, out), equals(1));
          expect(out.value, equals(0x2a));
        } finally {
          ssl.CBB_cleanup(cbb);
        }
      }, opensslAllocator);
    });

    test('extractBoringSslError and error macro helpers work', () {
      ssl.ERR_clear_error();
      expect(extractBoringSslError(), isNull);

      expect(EC_PKEY_NO_PUBKEY, isNonZero);
      expect(HKDF_R_OUTPUT_TOO_LARGE, isNonZero);
      expect(ERR_LIB_HKDF, isNonZero);
      expect(
        point_conversion_form_t.POINT_CONVERSION_UNCOMPRESSED,
        equals(4),
      );
      final packed = (ERR_LIB_HKDF << 24) | HKDF_R_OUTPUT_TOO_LARGE;
      expect(ERR_GET_LIB(packed), equals(ERR_LIB_HKDF));
      expect(ERR_GET_REASON(packed), equals(HKDF_R_OUTPUT_TOO_LARGE));
    });
  });

  group('BoringArena', () {
    test('using releases registrations in reverse order', () {
      final log = <String>[];
      final result = BoringArena.using((arena) {
        arena.register('a', log.add);
        arena.onReleaseAll(() => log.add('b'));
        arena.register('c', log.add);
        expect(log, isEmpty);
        return 42;
      });
      expect(result, equals(42));
      expect(log, equals(['c', 'b', 'a']));
    });

    test('using releases after the returned Future completes', () async {
      var released = false;
      final future = BoringArena.using((arena) async {
        arena.onReleaseAll(() => released = true);
        await Future<void>.delayed(Duration.zero);
        expect(released, isFalse);
        return 'done';
      });
      expect(released, isFalse);
      expect(await future, equals('done'));
      expect(released, isTrue);
    });

    test('using releases when the computation throws', () async {
      var released = 0;
      expect(
        () => BoringArena.using<void>((arena) {
          arena.onReleaseAll(() => released++);
          throw StateError('sync failure');
        }),
        throwsStateError,
      );
      await expectLater(
        BoringArena.using((arena) async {
          arena.onReleaseAll(() => released++);
          throw StateError('async failure');
        }),
        throwsStateError,
      );
      expect(released, equals(2));
    });

    test('using rejects Stream results', () {
      var released = false;
      expect(
        () => BoringArena.using((arena) {
          arena.onReleaseAll(() => released = true);
          return Stream.value(1);
        }),
        throwsArgumentError,
      );
      expect(released, isTrue);
    });

    test('stream releases when done and when cancelled', () async {
      var released = 0;
      Stream<int> numbers() => BoringArena.stream((arena) async* {
        arena.onReleaseAll(() => released++);
        yield 1;
        yield 2;
        yield 3;
      });

      expect(await numbers().toList(), equals([1, 2, 3]));
      expect(released, equals(1));
      expect(await numbers().first, equals(1));
      expect(released, equals(2));
    });

    test('move transfers ownership out of the arena', () {
      final log = <String>[];
      BoringArena.using((arena) {
        arena.register('kept', log.add);
        final moved = arena.register('moved', log.add);
        expect(arena.move(moved), equals('moved'));
        expect(() => arena.move('unknown'), throwsArgumentError);
      });
      expect(log, equals(['kept']));

      // Memory moved out of the arena is owned (and freed) by the caller.
      final pointer = BoringArena.using(
        (arena) => arena.move(arena.copyBytes<ffi.Uint8>([1, 2, 3])),
      );
      expect(pointer.asTypedList(3), equals([1, 2, 3]));
      opensslAllocator.free(pointer);
    });

    test('cannot be used after release', () {
      final arena = BoringArena()..releaseAll();
      expect(() => arena.allocate<ffi.Uint8>(1), throwsStateError);
      expect(() => arena.register(1, (_) {}), throwsStateError);
      expect(() => arena.onReleaseAll(() {}), throwsStateError);
      arena.releaseAll(); // Releasing again is a no-op.
    });

    test('releaseAll releases everything even if a callback throws', () {
      final log = <String>[];
      final arena = BoringArena()
        ..register('a', log.add)
        ..onReleaseAll(() => throw StateError('released second'))
        ..onReleaseAll(() => throw ArgumentError('released first'))
        ..register('d', log.add);
      expect(arena.releaseAll, throwsArgumentError);
      expect(log, equals(['d', 'a']));
    });

    test('copyBytes, cbs, cbb, and toBytes round-trip bytes', () {
      BoringArena.using((arena) {
        final cbs = arena.cbs([0x2a, 0x01, 0x02]);
        final u8 = arena<ffi.Uint8>();
        expect(ssl.CBS_get_u8(cbs, u8), equals(1));
        expect(u8.value, equals(0x2a));
        expect(cbs.ref.len, equals(2));

        final cbb = arena.cbb();
        expect(
          ssl.CBB_add_bytes(cbb, arena.copyBytes([1, 2, 3]), 3),
          equals(1),
        );
        expect(ssl.CBB_add_u8(cbb, 4), equals(1));
        expect(cbb.toBytes(), equals([1, 2, 3, 4]));
        expect(arena.cbb().toBytes(), isEmpty);
      });
    });

    test('cbb marshals and cbs parses an SPKI public key', () {
      final spki = BoringArena.using((arena) {
        final ec = arena.register(
          ssl.EC_KEY_new_by_curve_name(ssl.NID_X9_62_prime256v1),
          ssl.EC_KEY_free,
        );
        expect(ssl.EC_KEY_generate_key(ec), equals(1));
        final pkey = arena.register(ssl.EVP_PKEY_new(), ssl.EVP_PKEY_free);
        expect(ssl.EVP_PKEY_set1_EC_KEY(pkey, ec), equals(1));

        final cbb = arena.cbb();
        expect(ssl.EVP_marshal_public_key(cbb, pkey), equals(1));
        return cbb.toBytes();
      });
      expect(spki, isNotEmpty);

      BoringArena.using((arena) {
        final cbs = arena.cbs(spki);
        final pkey = arena.register(
          ssl.EVP_parse_public_key(cbs),
          ssl.EVP_PKEY_free,
        );
        expect(pkey, isNot(equals(ffi.nullptr)));
        expect(cbs.ref.len, equals(0), reason: 'no trailing bytes');
        expect(ssl.EVP_PKEY_id(pkey), equals(ssl.EVP_PKEY_EC));
      });
    });
  });
}
