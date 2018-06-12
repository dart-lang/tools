A library that implements the [JSON-RPC 2.0 spec][spec].

[spec]: http://www.jsonrpc.org/specification

## Server

A JSON-RPC 2.0 server exposes a set of methods that can be called by clients.
These methods can be registered using `Server.registerMethod`:

```dart
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:stream_channel/stream_channel.dart";
import "package:web_socket_channel/io.dart";

main() async {
  var socket = IOWebSocketChannel.connect('ws://localhost:4321');

  // The socket is a StreamChannel<dynamic> because it might emit binary
  // List<int>s, but JSON RPC 2 only works with Strings so we assert it only
  // emits those by casting it.
  var server = new json_rpc.Server(socket.cast<String>());

  // Any string may be used as a method name. JSON-RPC 2.0 methods are
  // case-sensitive.
  var i = 0;
  server.registerMethod("count", () {
    // Just return the value to be sent as a response to the client. This can
    // be anything JSON-serializable, or a Future that completes to something
    // JSON-serializable.
    return i++;
  });

  // Methods can take parameters. They're presented as a [Parameters] object
  // which makes it easy to validate that the expected parameters exist.
  server.registerMethod("echo", (params) {
    // If the request doesn't have a "message" parameter, this will
    // automatically send a response notifying the client that the request
    // was invalid.
    return params.getNamed("message");
  });

  // [Parameters] has methods for verifying argument types.
  server.registerMethod("subtract", (params) {
    // If "minuend" or "subtrahend" aren't numbers, this will reject the
    // request.
    return params.getNum("minuend") - params.getNum("subtrahend");
  });

  // [Parameters] also supports optional arguments.
  server.registerMethod("sort", (params) {
    var list = params.getList("list");
    list.sort();
    if (params.getBool("descending", orElse: () => false)) {
      return params.list.reversed;
    } else {
      return params.list;
    }
  });

  // A method can send an error response by throwing a
  // `json_rpc.RpcException`. Any positive number may be used as an
  // application- defined error code.
  const DIVIDE_BY_ZERO = 1;
  server.registerMethod("divide", (params) {
    var divisor = params.getNum("divisor");
    if (divisor == 0) {
      throw new json_rpc.RpcException(
          DIVIDE_BY_ZERO, "Cannot divide by zero.");
    }

    return params.getNum("dividend") / divisor;
  });

  // To give you time to register all your methods, the server won't actually
  // start listening for requests until you call `listen`.
  server.listen();
}
```

## Client

A JSON-RPC 2.0 client calls methods on a server and handles the server's
responses to those method calls. These methods can be called using
`Client.sendRequest`:

```dart
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:stream_channel/stream_channel.dart";
import "package:web_socket_channel/html.dart";

main() async {
  var socket = HtmlWebSocketChannel.connect('ws://localhost:4321');
  var client = new json_rpc.Client(socket);

  // This calls the "count" method on the server. A Future is returned that
  // will complete to the value contained in the server's response.
  client.sendRequest("count").then((result) => print("Count is $result."));

  // Parameters are passed as a simple Map or, for positional parameters, an
  // Iterable. Make sure they're JSON-serializable!
  client.sendRequest("echo", {"message": "hello"})
      .then((echo) => print('Echo says "$echo"!'));

  // A notification is a way to call a method that tells the server that no
  // result is expected. Its return type is `void`; even if it causes an
  // error, you won't hear back.
  client.sendNotification("count");

  // If the server sends an error response, the returned Future will complete
  // with an RpcException. You can catch this error and inspect its error
  // code, message, and any data that the server sent along with it.
  client.sendRequest("divide", {"dividend": 2, "divisor": 0})
      .catchError((error) {
    print("RPC error ${error.code}: ${error.message}");
  });

  // The client won't subscribe to the input stream until you call `listen`.
  client.listen();
}
```

## Peer

Although JSON-RPC 2.0 only explicitly describes clients and servers, it also
mentions that two-way communication can be supported by making each endpoint
both a client and a server. This package supports this directly using the `Peer`
class, which implements both `Client` and `Server`. It supports the same methods
as those classes, and automatically makes sure that every message from the other
endpoint is routed and handled correctly.
