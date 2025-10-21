// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import '../resubscribable.dart';
import '../watch_event.dart';
import 'windows_manually_closed_directory_watcher.dart';

/// Runs [WindowsManuallyClosedDirectoryWatcher] in an isolate to work around
/// a platform limitation.
///
/// On Windows, Directory.watch fails if too many events arrive without being
/// processed by the Dart VM. See `directory_watcher/windows_test.dart` for code
/// that reliably triggers the failure by doing file writes in a synchronous
/// block that prevents the Dart VM from processing the events caused.
///
/// Running the watcher in an isolate makes buffer exhaustion much less likely
/// as there is no unrelated work happening in the isolate that would block
/// processing of events.
class WindowsIsolateDirectoryWatcher implements ManuallyClosedWatcher {
  @override
  final String path;
  final ReceivePort _receivePort = ReceivePort();
  final Completer<SendPort> _sendPortCompleter = Completer();

  final StreamController<WatchEvent> _eventsController =
      StreamController.broadcast();
  final Completer<void> _readyCompleter = Completer();

  WindowsIsolateDirectoryWatcher(this.path) {
    _startIsolate(path, _receivePort.sendPort);
    _receivePort.listen((event) => _receiveFromIsolate(event as Event));
  }

  void _receiveFromIsolate(Event event) {
    switch (event.type) {
      case EventType.sendPort:
        _sendPortCompleter.complete(event.sendPort);
      case EventType.ready:
        _readyCompleter.complete();
      case EventType.watchEvent:
        _eventsController.add(event.watchEvent!);
      case EventType.close:
        _eventsController.close();
        _receivePort.close();
      case EventType.error:
        _eventsController.addError(event.error!, event.stackTrace);
    }
  }

  @override
  void close() {
    // The "close" event is the only event sent to the isolate, just send
    // `null`.
    _sendPortCompleter.future.then((sendPort) => sendPort.send(null));
  }

  @override
  Stream<WatchEvent> get events => _eventsController.stream;

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  Future<void> get ready => _readyCompleter.future;
}

/// Starts watching [path] in an isolate.
///
/// [sendPort] is the port from isolate to host, see `_WatcherIsolate`
/// constructor implementation for the events that will be sent.
void _startIsolate(String path, SendPort sendPort) async {
  unawaited(
      Isolate.run(() async => await _WatcherIsolate(path, sendPort).closed));
}

class _WatcherIsolate {
  final String path;
  final WindowsManuallyClosedDirectoryWatcher watcher;
  final SendPort sendPort;

  // The isolate stays open until this future completes.
  Future<void> get closed => _closeCompleter.future;
  final Completer<void> _closeCompleter = Completer();

  _WatcherIsolate(this.path, this.sendPort)
      : watcher = WindowsManuallyClosedDirectoryWatcher(path) {
    final receivePort = ReceivePort();

    // Six types of event are sent to the host.

    // The `SendPort` for host to isolate communication on startup.
    sendPort.send(Event.sendPort(receivePort.sendPort));

    // `Event.ready` when the watcher is ready.
    watcher.ready.then((_) {
      sendPort.send(Event.ready());
    });

    watcher.events.listen((event) {
      // The watcher events.
      sendPort.send(Event.watchEvent(event));
    }, onDone: () {
      // `Event.close` if the watcher event stream closes.
      sendPort.send(Event.close());
    }, onError: (Object e, StackTrace s) {
      // `Event.error` on error.
      sendPort.send(Event.error(e, s));
    });

    receivePort.listen((event) {
      // The only event sent from the host to the isolate is "close", no need
      // to check the value.
      watcher.close();
      _closeCompleter.complete();
      receivePort.close();
    });
  }
}

/// Event sent from the isolate to the host.
class Event {
  final EventType type;
  final SendPort? sendPort;
  final WatchEvent? watchEvent;
  final Object? error;
  final StackTrace? stackTrace;

  Event.sendPort(this.sendPort)
      : type = EventType.sendPort,
        watchEvent = null,
        error = null,
        stackTrace = null;

  Event.ready()
      : type = EventType.ready,
        sendPort = null,
        watchEvent = null,
        error = null,
        stackTrace = null;

  Event.watchEvent(this.watchEvent)
      : type = EventType.watchEvent,
        sendPort = null,
        error = null,
        stackTrace = null;

  Event.close()
      : type = EventType.close,
        sendPort = null,
        watchEvent = null,
        error = null,
        stackTrace = null;

  Event.error(this.error, this.stackTrace)
      : type = EventType.error,
        sendPort = null,
        watchEvent = null;
}

enum EventType {
  sendPort,
  ready,
  watchEvent,
  close,
  error;
}
