// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Raw `ffigen`-generated BoringSSL C bindings (`bssl_dart`),
/// [bssl.OPENSSL_cleanse]-backed [opensslAllocator], scoped [BoringArena], and
/// [NativeHandle] finalizer wrapper.
library;

import 'dart:convert';
import 'dart:ffi' as ffi;

import 'src/arena.dart' show BoringArena;
import 'src/bindings/boringssl.g.dart' as bssl;

export 'src/arena.dart';
export 'src/bindings/boringssl.g.dart';

/// An [ffi.Allocator] backed by BoringSSL's [bssl.OPENSSL_malloc] and
/// [bssl.OPENSSL_free].
///
/// BoringSSL's [bssl.OPENSSL_free] automatically scrubs every allocation with
/// [bssl.OPENSSL_cleanse] before returning memory to the OS heap.
const OpenSslAllocator opensslAllocator = OpenSslAllocator._();

/// Implementation of [ffi.Allocator] using [bssl.OPENSSL_malloc] and
/// [bssl.OPENSSL_free].
final class OpenSslAllocator implements ffi.Allocator {
  const OpenSslAllocator._();

  @override
  ffi.Pointer<T> allocate<T extends ffi.NativeType>(
    int byteCount, {
    int? alignment,
  }) {
    final ptr = bssl.OPENSSL_malloc(byteCount);
    if (ptr == ffi.nullptr) {
      bssl.ERR_clear_error();
      throw const OutOfMemoryError();
    }
    return ptr.cast<T>();
  }

  @override
  void free(ffi.Pointer<ffi.NativeType> pointer) {
    bssl.OPENSSL_free(pointer.cast());
  }

  /// Pointer to [bssl.OPENSSL_free] suitable for [ffi.NativeFinalizer] or
  /// `Pointer<Uint8>.asTypedList(len, finalizer: opensslAllocator.nativeFree)`.
  ffi.Pointer<ffi.NativeFinalizerFunction> get nativeFree =>
      bssl.addresses.OPENSSL_free;
}

/// A GC-managed wrapper around a BoringSSL `Pointer<T>` that attaches a shared
/// [ffi.NativeFinalizer] and supports deterministic [dispose].
///
/// Because [NativeHandle] implements [ffi.Finalizable], calling [use] ensures
/// that the Dart VM compiler inserts a reachability fence keeping `this` alive
/// until [use] returns, preventing premature finalization while a native call
/// is in progress.
final class NativeHandle<T extends ffi.NativeType> implements ffi.Finalizable {
  static final _finalizers = <int, ffi.NativeFinalizer>{};

  final ffi.Pointer<T> _ptr;
  final ffi.NativeFinalizer _finalizer;
  final void Function(ffi.Pointer<ffi.Void>) _rawFree;
  bool _disposed = false;

  /// Wraps [_ptr] and attaches a [ffi.NativeFinalizer] calling [freeFn] (for
  /// example, `addresses.EVP_PKEY_free` or `addresses.X509_free`).
  NativeHandle(
    this._ptr,
    ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<T>)>> freeFn, {
    int externalSize = 4096,
  }) : _rawFree = freeFn
           .cast<ffi.NativeFinalizerFunction>()
           .asFunction<void Function(ffi.Pointer<ffi.Void>)>(),
       _finalizer = _finalizers.putIfAbsent(
         freeFn.address,
         () => ffi.NativeFinalizer(freeFn.cast()),
       ) {
    if (_ptr == ffi.nullptr) {
      throw StateError('Cannot wrap nullptr in NativeHandle<$T>');
    }
    _finalizer.attach(
      this,
      _ptr.cast(),
      detach: this,
      externalSize: externalSize,
    );
  }

  /// Whether [dispose] has been called on this handle.
  bool get isDisposed => _disposed;

  /// Invokes [fn] with the underlying `Pointer<T>`, keeping `this` reachable
  /// until [fn] completes so the GC finalizer cannot run mid-call.
  R use<R>(R Function(ffi.Pointer<T> ptr) fn) {
    if (_disposed) {
      throw StateError('NativeHandle<$T> has already been disposed');
    }
    return fn(_ptr);
  }

  /// Deterministically frees the native resource and detaches the GC finalizer.
  ///
  /// Safe to call multiple times (subsequent calls are no-ops).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    _rawFree(_ptr.cast());
  }
}

/// Convenience extension to invoke a 1-argument C function taking `Pointer<P>`
/// with a [NativeHandle].
///
/// ```dart
/// final pkey = NativeHandle(EVP_PKEY_new(), addresses.EVP_PKEY_free);
/// final keyId = EVP_PKEY_id.invoke(pkey);
/// ```
extension NativeHandleInvoke1<R, P extends ffi.NativeType>
    on R Function(ffi.Pointer<P>) {
  /// Invokes `this` with the unwrapped pointer from [handle].
  R invoke(NativeHandle<P> handle) => handle.use(this);
}

/// Convenience extension to invoke a 2-argument C function
/// `(Pointer<EVP_PKEY>, A1)` with a [NativeHandle] (for example,
/// `EVP_PKEY_CTX_new.invoke(pkey, nullptr)`).
extension EvpPKeyInvoke2First<R, A1>
    on R Function(ffi.Pointer<bssl.EVP_PKEY>, A1) {
  /// Invokes `this` with the unwrapped pointer from [handle] and [arg1].
  R invoke(NativeHandle<bssl.EVP_PKEY> handle, A1 arg1) =>
      handle.use((ptr) => this(ptr, arg1));
}

/// Convenience extension to invoke a 2-argument C function
/// `(A1, Pointer<EVP_PKEY>)` with a [NativeHandle] (for example,
/// `EVP_marshal_public_key.invoke(cbb, pkey)`).
extension EvpPKeyInvoke2Last<R, A1>
    on R Function(A1, ffi.Pointer<bssl.EVP_PKEY>) {
  /// Invokes `this` with [arg1] and the unwrapped pointer from [handle].
  R invoke(A1 arg1, NativeHandle<bssl.EVP_PKEY> handle) =>
      handle.use((ptr) => this(arg1, ptr));
}

/// Convenience extension to invoke a 5-argument C function
/// `(A1, A2, A3, A4, Pointer<P>)` with a [NativeHandle] (for example,
/// `EVP_DigestVerifyInit.invoke(ctx, pctx, md, nullptr, pkey)`).
extension NativeHandleInvoke5Last<R, A1, A2, A3, A4, P extends ffi.NativeType>
    on R Function(A1, A2, A3, A4, ffi.Pointer<P>) {
  /// Invokes `this` with [arg1]..[arg4] and the unwrapped pointer from
  /// [handle].
  R invoke(A1 arg1, A2 arg2, A3 arg3, A4 arg4, NativeHandle<P> handle) =>
      handle.use((ptr) => this(arg1, arg2, arg3, arg4, ptr));
}

/// Formats the least recent (and most specific) error on the current thread's
/// BoringSSL error queue, and clears the queue before returning.
///
/// Returns `null` if the error queue is empty.
///
/// The error queue is thread-local, and an isolate may resume on a different
/// OS thread after an `await`. Call this right after the failing BoringSSL
/// call, with no `await` in between, rather than from a `finally` that may run
/// after one (such as the release of an `async` [BoringArena.run]).
///
/// Use [bssl.ERR_clear_error] to discard errors you ignore, for example when a
/// failed signature verification just means `false`. The queue is shared by
/// every package using `package:boring` on that thread, so leftover errors
/// would be reported for the next, unrelated failure.
String? extractBoringSslError() {
  try {
    final err = bssl.ERR_get_error();
    if (err == 0) {
      return null;
    }
    const maxLen = 4096;
    final out = opensslAllocator<ffi.Char>(maxLen);
    try {
      bssl.ERR_error_string_n(err, out, maxLen);
      final data = out.cast<ffi.Uint8>().asTypedList(maxLen);
      var len = 0;
      while (len < maxLen && data[len] != 0) {
        len++;
      }
      return utf8.decode(data.sublist(0, len), allowMalformed: true);
    } finally {
      opensslAllocator.free(out);
    }
  } finally {
    bssl.ERR_clear_error();
  }
}

/// Returns the library code (`ERR_LIB_*`) for a packed BoringSSL error code.
// ignore: non_constant_identifier_names
int ERR_GET_LIB(int packedError) => (packedError >> 24) & 0xff;

/// Returns the library-specific reason code (`*_R_*`) for a packed BoringSSL
/// error code.
// ignore: non_constant_identifier_names
int ERR_GET_REASON(int packedError) => packedError & 0xfff;
