// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import '../bindings.dart' show extractBoringSslError, opensslAllocator;
import 'bindings/boringssl.g.dart' as bssl;

/// A scoped [ffi.Allocator] and resource tracker for calling BoringSSL.
///
/// All memory is allocated with [opensslAllocator] ([bssl.OPENSSL_malloc]), so
/// it is scrubbed with [bssl.OPENSSL_cleanse] when released, and it may be
/// handed to BoringSSL functions that take ownership and later call
/// [bssl.OPENSSL_free].
///
/// Allocations, resources registered with [using], and callbacks registered
/// with [onReleaseAll] are released in reverse order by [releaseAll]. Prefer
/// [BoringArena.run] and [BoringArena.stream], which call [releaseAll] once the
/// computation has completed.
///
/// BoringSSL functions with `set0` semantics (for example [bssl.RSA_set0_key]
/// or [bssl.EVP_PKEY_CTX_set0_rsa_oaep_label]) take ownership of their
/// arguments on success. Call [move] after such a call, so the arena does not
/// free the resource a second time:
///
/// ```dart
/// BoringArena.run((arena) {
///   final ctx = arena.using(
///     EVP_PKEY_CTX_new(pkey, nullptr),
///     EVP_PKEY_CTX_free,
///   );
///   final label = arena.copyBytes<Uint8>(labelBytes);
///   final len = labelBytes.length;
///   if (EVP_PKEY_CTX_set0_rsa_oaep_label(ctx, label, len) == 1) {
///     arena.move(label); // `ctx` now owns `label`.
///   }
/// });
/// ```
final class BoringArena implements ffi.Allocator {
  final List<_Registration> _registrations = [];
  bool _released = false;

  /// Runs [computation] with a new [BoringArena] and releases it afterwards.
  ///
  /// If [computation] returns a [Future], the arena is released when that
  /// future completes, so `async` computations can keep using the arena across
  /// `await`s. Returning a [Stream] is rejected, because the arena would be
  /// released before the stream is listened to; use [BoringArena.stream]
  /// instead.
  static R run<R>(R Function(BoringArena arena) computation) {
    final arena = BoringArena();
    var releaseLater = false;
    try {
      final result = computation(arena);
      if (result is Future) {
        releaseLater = true;
        return result.whenComplete(arena.releaseAll) as R;
      }
      if (result is Stream) {
        throw ArgumentError.value(
          result,
          'computation',
          'must not return a Stream, use BoringArena.stream instead',
        );
      }
      return result;
    } finally {
      if (!releaseLater) {
        arena.releaseAll();
      }
    }
  }

  /// Returns a stream of the events from the stream returned by [computation],
  /// which is called with a new [BoringArena] when the stream is listened to.
  ///
  /// The arena is released when the stream is done, or when the subscription
  /// is cancelled.
  static Stream<T> stream<T>(
    Stream<T> Function(BoringArena arena) computation,
  ) async* {
    final arena = BoringArena();
    try {
      yield* computation(arena);
    } finally {
      arena.releaseAll();
    }
  }

  /// Allocates [byteCount] bytes with [opensslAllocator], freed by
  /// [releaseAll].
  @override
  ffi.Pointer<T> allocate<T extends ffi.NativeType>(
    int byteCount, {
    int? alignment,
  }) {
    _ensureInUse();
    final pointer = opensslAllocator.allocate<T>(
      byteCount,
      alignment: alignment,
    );
    _registrations.add(
      _Registration(pointer, () => opensslAllocator.free(pointer)),
    );
    return pointer;
  }

  /// Does nothing, memory is freed by [releaseAll].
  @override
  void free(ffi.Pointer<ffi.NativeType> pointer) {}

  /// Registers [release] to be called with [resource] by [releaseAll], and
  /// returns [resource].
  ///
  /// This is typically used with BoringSSL's `X_new` / `X_free` pairs:
  /// `arena.using(EC_KEY_new(), EC_KEY_free)`.
  T using<T extends Object>(T resource, void Function(T resource) release) {
    _ensureInUse();
    _registrations.add(_Registration(resource, () => release(resource)));
    return resource;
  }

  /// Registers [callback] to be called by [releaseAll].
  void onReleaseAll(void Function() callback) {
    _ensureInUse();
    _registrations.add(_Registration(null, callback));
  }

  /// Transfers ownership of [resource] out of this arena, and returns it.
  ///
  /// Removes every allocation or [using] registration for [resource], so
  /// [releaseAll] no longer frees it. Call this after passing [resource] to a
  /// BoringSSL function that takes ownership of it.
  ///
  /// Throws an [ArgumentError] if [resource] is not owned by this arena.
  T move<T extends Object>(T resource) {
    _ensureInUse();
    final count = _registrations.length;
    _registrations.removeWhere((r) => r.resource == resource);
    if (_registrations.length == count) {
      throw ArgumentError.value(
        resource,
        'resource',
        'is not owned by this BoringArena',
      );
    }
    return resource;
  }

  /// Allocates a [bssl.CBS] reading a copy of [data] owned by this arena.
  ffi.Pointer<bssl.CBS> cbs(List<int> data) {
    final result = this<bssl.CBS>();
    result.ref
      ..data = copyBytes<ffi.Uint8>(data)
      ..len = data.length;
    return result;
  }

  /// Allocates a growable [bssl.CBB] with [initialCapacity], which is cleaned
  /// up with [bssl.CBB_cleanup] by [releaseAll].
  ///
  /// Use [CbbToBytes.toBytes] to copy the contents into a [Uint8List].
  ffi.Pointer<bssl.CBB> cbb([int initialCapacity = 4096]) {
    final result = this<bssl.CBB>();
    // CBB_zero makes CBB_cleanup safe, even if CBB_init fails.
    bssl.CBB_zero(result);
    using(result, bssl.CBB_cleanup);
    if (bssl.CBB_init(result, initialCapacity) != 1) {
      bssl.ERR_clear_error();
      throw const OutOfMemoryError();
    }
    return result;
  }

  /// Releases all allocations and resources in reverse registration order.
  ///
  /// If a release callback throws, the remaining resources are still
  /// released, and the first error is rethrown afterwards. The arena cannot be
  /// used after this has been called.
  void releaseAll() {
    _released = true;
    Object? error;
    StackTrace? stackTrace;
    while (_registrations.isNotEmpty) {
      try {
        _registrations.removeLast().release();
      } catch (e, st) {
        error ??= e;
        stackTrace ??= st;
      }
    }
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace!);
    }
  }

  void _ensureInUse() {
    if (_released) {
      throw StateError('BoringArena has already been released');
    }
  }
}

final class _Registration {
  final Object? resource;
  final void Function() release;

  _Registration(this.resource, this.release);
}

/// Copies Dart bytes into native memory.
extension AllocatorCopyBytes on ffi.Allocator {
  /// Allocates `data.length` bytes and copies [data] into them.
  ///
  /// Use a [BoringArena] (or [opensslAllocator]) for inputs that may be
  /// secret, so the copy is scrubbed when it is freed.
  ffi.Pointer<T> copyBytes<T extends ffi.NativeType>(List<int> data) {
    final pointer = this<ffi.Uint8>(data.length);
    if (data.isNotEmpty) {
      pointer.asTypedList(data.length).setAll(0, data);
    }
    return pointer.cast<T>();
  }
}

/// Reads the contents of a [bssl.CBB].
extension CbbToBytes on ffi.Pointer<bssl.CBB> {
  /// Flushes this [bssl.CBB] and returns a Dart-owned copy of its contents.
  ///
  /// Throws a [StateError] if [bssl.CBB_flush] fails.
  Uint8List toBytes() {
    if (bssl.CBB_flush(this) != 1) {
      final error = extractBoringSslError();
      throw StateError('CBB_flush failed${error == null ? '' : ': $error'}');
    }
    final length = bssl.CBB_len(this);
    if (length == 0) {
      return Uint8List(0);
    }
    return Uint8List.fromList(bssl.CBB_data(this).asTypedList(length));
  }
}
