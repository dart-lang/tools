// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main() async {
  // A StreamChannel<T>, is in simplest terms, a wrapper around a Stream<T> and
  // a StreamSink<T>. For example, you can create a channel that wraps standard
  // IO:
  var stdioChannel = StreamChannel(stdin, stdout);
  stdioChannel.sink.add('Hello!\n'.codeUnits);

  // Like a Stream<T> can be transformed with a StreamTransformer<T>, a
  // StreamChannel<T> can be transformed with a StreamChannelTransformer<T>.
  // For example, we can handle standard input as strings:
  var stringChannel = stdioChannel
      .transform(StreamChannelTransformer.fromCodec(utf8))
      .transformStream(LineSplitter());
  stringChannel.sink.add('world!\n');

  // You can implement StreamChannel<T> by extending StreamChannelMixin<T>, but
  // it's much easier to use a StreamChannelController<T>. A controller has two
  // StreamChannel<T> members: `local` and `foreign`. The creator of a
  // controller should work with the `local` channel, while the recipient should
  // work with the `foreign` channel, and usually will not have direct access to
  // the underlying controller.
  var ctrl = StreamChannelController<String>();
  ctrl.local.stream.listen((event) {
    // Do something useful here...
  });

  // You can also pipe events from one channel to another.
  ctrl
    ..foreign.pipe(stringChannel)
    ..local.sink.add('Piped!\n');
  await ctrl.local.sink.close();

  // The StreamChannel<T> interface provides several guarantees, which can be
  // found here:
  // https://pub.dev/documentation/stream_channel/latest/stream_channel/StreamChannel-class.html
  //
  // By calling `StreamChannel<T>.withGuarantees()`, you can create a
  // StreamChannel<T> that provides all guarantees.
  var dummyCtrl0 = StreamChannelController<String>();
  var guaranteedChannel = StreamChannel.withGuarantees(
      dummyCtrl0.foreign.stream, dummyCtrl0.foreign.sink);

  // To close a StreamChannel, use `sink.close()`.
  await guaranteedChannel.sink.close();

  // A MultiChannel<T> multiplexes multiple virtual channels across a single
  // underlying transport layer. For example, an application listening over
  // standard I/O can still support multiple clients if it has a mechanism to
  // separate events from different clients.
  //
  // A MultiChannel<T> splits events into numbered channels, which are
  // instances of VirtualChannel<T>.
  var dummyCtrl1 = StreamChannelController<String>();
  var multiChannel = MultiChannel<String>(dummyCtrl1.foreign);
  var channel1 = multiChannel.virtualChannel();
  await multiChannel.sink.close();

  // The client/peer should also create its own MultiChannel<T>, connected to
  // the underlying transport, use the corresponding ID's to handle events in
  // their respective channels. It is up to you how to communicate channel ID's
  // across different endpoints.
  var dummyCtrl2 = StreamChannelController<String>();
  var multiChannel2 = MultiChannel<String>(dummyCtrl2.foreign);
  var channel2 = multiChannel2.virtualChannel(channel1.id);
  await channel2.sink.close();
  await multiChannel2.sink.close();

  // Multiple instances of a Dart application can communicate easily across
  // `SendPort`/`ReceivePort` pairs by means of the `IsolateChannel<T>` class.
  // Typically, one endpoint will create a `ReceivePort`, and call the
  // `IsolateChannel.connectReceive` constructor. The other endpoint will be
  // given the corresponding `SendPort`, and then call
  // `IsolateChannel.connectSend`.
  var recv = ReceivePort();
  var recvChannel = IsolateChannel.connectReceive(recv);
  var sendChannel = IsolateChannel.connectSend(recv.sendPort);

  // You must manually close `IsolateChannel<T>` sinks, however.
  await recvChannel.sink.close();
  await sendChannel.sink.close();

  // You can use the `Disconnector` transformer to cause a channel to act as
  // though the remote end of its transport had disconnected.
  var disconnector = Disconnector<String>();
  var disconnectable = stringChannel.transform(disconnector);
  disconnectable.sink.add('Still connected!');
  await disconnector.disconnect();

  // Additionally:
  //   * The `DelegatingStreamController<T>` class can be extended to build a
  //     basis for wrapping other `StreamChannel<T>` objects.
  //   * The `jsonDocument` transformer converts events to/from JSON, using
  //     the `json` codec from `dart:convert`.
  //   * `package:json_rpc_2` directly builds on top of
  //     `package:stream_channel`, so any compatible transport can be used to
  //      create interactive client/server or peer-to-peer applications (i.e.
  //      language servers, microservices, etc.
}
