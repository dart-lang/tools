[![Build Status](https://github.com/dart-lang/tools/actions/workflows/sse.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/sse.yaml)
[![pub package](https://img.shields.io/pub/v/sse.svg)](https://pub.dev/packages/sse)
[![package publisher](https://img.shields.io/pub/publisher/sse.svg)](https://pub.dev/packages/sse/publisher)

This package provides support for bi-directional communication through Server
Sent Events and corresponding POST requests.

This package is not intended to be a general purpose SSE package, but instead is
a bidirectional protocol for use when Websockets are unavailable. That is, both
the client and the server expose a `sink` and `stream` on which to send and
receive messages respectively.

Both the server and client have implicit assumptions on each other and therefore
a client from this package must be paired with a server from this package.

## Cross-origin configuration

`SseHandler` validates incoming `Origin` and `Sec-Fetch-Site` headers before
establishing SSE streams or accepting `POST` messages:

- Same-origin requests and HTTP(S) loopback origins (`localhost`, `127.0.0.1`,
  `::1`) targeting a loopback server are allowed by default.
- Non-loopback cross-origin callers (including servers behind TLS-terminating
  or `Host`-rewriting reverse proxies, separate frontend origins, and browser
  extensions) must be explicitly permitted via `allowedOrigins` or
  `originCheck`:

```dart
final handler = SseHandler(
  Uri.parse('/sseHandler'),
  allowedOrigins: {'https://app.example.com'},
  originCheck: (origin) => origin.startsWith('chrome-extension://'),
);
```

`Origin` validation protects against cross-origin browser requests; protecting
local loopback servers against DNS rebinding still requires `Host`-header
validation middleware on the embedding HTTP server.
