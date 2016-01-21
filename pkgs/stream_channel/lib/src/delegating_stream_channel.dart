// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A simple delegating wrapper around [StreamChannel].
///
/// Subclasses can override individual methods, or use this to expose only
/// [StreamChannel] methods.
class StreamChannelView<T> extends StreamChannelMixin<T> {
  /// The inner channel to which methods are forwarded.
  final StreamChannel<T> _inner;

  Stream<T> get stream => _inner.stream;
  StreamSink<T> get sink => _inner.sink;

  StreamChannelView(this._inner);
}
