// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'src/stream_channel_transformer.dart';

export 'src/delegating_stream_channel.dart';
export 'src/isolate_channel.dart';
export 'src/multi_channel.dart';
export 'src/stream_channel_completer.dart';
export 'src/stream_channel_transformer.dart';

/// An abstract class representing a two-way communication channel.
///
/// Users should consider the [stream] emitting a "done" event to be the
/// canonical indicator that the channel has closed. If they wish to close the
/// channel, they should close the [sink]—canceling the stream subscription is
/// not sufficient. Protocol errors may be emitted through the stream or through
/// [Sink.done], depending on their underlying cause. Note that the sink may
/// silently drop events if the channel closes before [Sink.close] is called.
///
/// Implementations are strongly encouraged to mix in or extend
/// [StreamChannelMixin] to get default implementations of the various instance
/// methods. Adding new methods to this interface will not be considered a
/// breaking change if implementations are also added to [StreamChannelMixin].
///
/// Implementations must provide the following guarantees:
///
/// * The stream is single-subscription, and must follow all the guarantees of
///   single-subscription streams.
///
/// * Closing the sink causes the stream to close before it emits any more
///   events.
///
/// * After the stream closes, the sink is automatically closed. If this
///   happens, sink methods should silently drop their arguments until
///   [Sink.close] is called.
///
/// * If the stream closes before it has a listener, the sink should silently
///   drop events if possible.
///
/// * Canceling the stream's subscription has no effect on the sink. The channel
///   must still be able to respond to the other endpoint closing the channel
///   even after the subscription has been canceled.
///
/// * The sink *either* forwards errors to the other endpoint *or* closes as
///   soon as an error is added and forwards that error to the [Sink.done]
///   future.
///
/// These guarantees allow users to interact uniformly with all implementations,
/// and ensure that either endpoint closing the stream produces consistent
/// behavior.
abstract class StreamChannel<T> {
  /// The single-subscription stream that emits values from the other endpoint.
  Stream<T> get stream;

  /// The sink for sending values to the other endpoint.
  StreamSink<T> get sink;

  /// Creates a new [StreamChannel] that communicates over [stream] and [sink].
  ///
  /// Note that this stream/sink pair must provide the guarantees listed in the
  /// [StreamChannel] documentation.
  factory StreamChannel(Stream<T> stream, StreamSink<T> sink) =>
      new _StreamChannel<T>(stream, sink);

  /// Connects [this] to [other], so that any values emitted by either are sent
  /// directly to the other.
  void pipe(StreamChannel<T> other);

  /// Transforms [this] using [transformer].
  ///
  /// This is identical to calling `transformer.bind(channel)`.
  StreamChannel transform(StreamChannelTransformer<dynamic, T> transformer);
}

/// An implementation of [StreamChannel] that simply takes a stream and a sink
/// as parameters.
///
/// This is distinct from [StreamChannel] so that it can use
/// [StreamChannelMixin].
class _StreamChannel<T> extends StreamChannelMixin<T> {
  final Stream<T> stream;
  final StreamSink<T> sink;

  _StreamChannel(this.stream, this.sink);
}

/// A mixin that implements the instance methods of [StreamChannel] in terms of
/// [stream] and [sink].
abstract class StreamChannelMixin<T> implements StreamChannel<T> {
  void pipe(StreamChannel<T> other) {
    stream.pipe(other.sink);
    other.stream.pipe(sink);
  }

  StreamChannel transform(StreamChannelTransformer<dynamic, T> transformer) =>
      transformer.bind(this);
}
