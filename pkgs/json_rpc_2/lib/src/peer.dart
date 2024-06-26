// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import 'client.dart';
import 'parameters.dart';
import 'server.dart';
import 'utils.dart';

/// A JSON-RPC 2.0 client *and* server.
///
/// This supports bidirectional peer-to-peer communication with another JSON-RPC
/// 2.0 endpoint. It sends both requests and responses across the same
/// communication channel and expects to connect to a peer that does the same.
class Peer implements Client, Server {
  final StreamChannel<dynamic> _channel;

  /// The underlying client that handles request-sending and response-receiving
  /// logic.
  late final Client _client;

  /// The underlying server that handles request-receiving and response-sending
  /// logic.
  late final Server _server;

  /// A stream controller that forwards incoming messages to [_server] if
  /// they're requests.
  final _serverIncomingForwarder = StreamController<Object?>(sync: true);

  /// A stream controller that forwards incoming messages to [_client] if
  /// they're responses.
  final _clientIncomingForwarder = StreamController<Object?>(sync: true);

  @override
  late final Future done = Future.wait([_client.done, _server.done]);

  @override
  bool get isClosed => _client.isClosed || _server.isClosed;

  @override
  ErrorCallback? get onUnhandledError => _server.onUnhandledError;

  @override
  bool get strictProtocolChecks => _server.strictProtocolChecks;

  /// Creates a [Peer] that communicates over [channel].
  ///
  /// Note that the peer won't begin listening to [channel] until [Peer.listen]
  /// is called.
  ///
  /// Unhandled exceptions in callbacks will be forwarded to [onUnhandledError].
  /// If this is not provided, unhandled exceptions will be swallowed.
  ///
  /// If [strictProtocolChecks] is false, the underlying [Server] will accept
  /// some requests which are not conformant with the JSON-RPC 2.0
  /// specification. In particular, requests missing the `jsonrpc` parameter
  /// will be accepted.
  Peer(StreamChannel<String> channel,
      {ErrorCallback? onUnhandledError, bool strictProtocolChecks = true})
      : this.withoutJson(
            jsonDocument.bind(channel).transform(respondToFormatExceptions),
            onUnhandledError: onUnhandledError,
            strictProtocolChecks: strictProtocolChecks);

  /// Creates a [Peer] that communicates using decoded messages over [_channel].
  ///
  /// Unlike [Peer.new], this doesn't read or write JSON strings. Instead, it
  /// reads and writes decoded maps or lists.
  ///
  /// Note that the peer won't begin listening to [_channel] until
  /// [Peer.listen] is called.
  ///
  /// Unhandled exceptions in callbacks will be forwarded to [onUnhandledError].
  /// If this is not provided, unhandled exceptions will be swallowed.
  ///
  /// If [strictProtocolChecks] is false, the underlying [Server] will accept
  /// some requests which are not conformant with the JSON-RPC 2.0
  /// specification. In particular, requests missing the `jsonrpc` parameter
  /// will be accepted.
  Peer.withoutJson(this._channel,
      {ErrorCallback? onUnhandledError, bool strictProtocolChecks = true}) {
    _server = Server.withoutJson(
        StreamChannel(_serverIncomingForwarder.stream, _channel.sink),
        onUnhandledError: onUnhandledError,
        strictProtocolChecks: strictProtocolChecks);
    _client = Client.withoutJson(
        StreamChannel(_clientIncomingForwarder.stream, _channel.sink));
  }

  // Client methods.

  @override
  Future sendRequest(String method, [Object? parameters]) =>
      _client.sendRequest(method, parameters);

  @override
  void sendNotification(String method, [Object? parameters]) =>
      _client.sendNotification(method, parameters);

  @override
  void withBatch(void Function() callback) => _client.withBatch(callback);

  // Server methods.

  @override
  void registerMethod(String name, Function callback) =>
      _server.registerMethod(name, callback);

  @override
  void registerFallback(void Function(Parameters parameters) callback) =>
      _server.registerFallback(callback);

  // Shared methods.

  @override
  Future listen() {
    _client.listen();
    _server.listen();
    _channel.stream.listen((message) {
      if (message is Map) {
        if (message.containsKey('result') || message.containsKey('error')) {
          _clientIncomingForwarder.add(message);
        } else {
          _serverIncomingForwarder.add(message);
        }
      } else if (message is List &&
          message.isNotEmpty &&
          message.first is Map) {
        if (message.first.containsKey('result') ||
            message.first.containsKey('error')) {
          _clientIncomingForwarder.add(message);
        } else {
          _serverIncomingForwarder.add(message);
        }
      } else {
        // Non-Map and -List messages are ill-formed, so we pass them to the
        // server since it knows how to send error responses.
        _serverIncomingForwarder.add(message);
      }
    }, onError: (Object error, StackTrace stackTrace) {
      _serverIncomingForwarder.addError(error, stackTrace);
    }, onDone: close);
    return done;
  }

  @override
  Future close() {
    _client.close();
    _server.close();
    return done;
  }
}
