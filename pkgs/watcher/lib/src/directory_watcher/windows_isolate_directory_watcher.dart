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
  SendPort? _sendPort;

  final StreamController<WatchEvent> _eventsController =
      StreamController.broadcast();
  final Completer<void> _readyCompleter = Completer();

  WindowsIsolateDirectoryWatcher(this.path) {
    _startIsolate(path, _receivePort.sendPort);
    _receivePort
        .listen((event) => _receiveFromIsolate(_Event.fromObject(event)));
  }

  void _receiveFromIsolate(_Event event) {
    if (event.isSendPort()) {
      _sendPort = event.sendPort;
      return;
    }
    if (event.isReady()) {
      _readyCompleter.complete();
      return;
    }
    if (event.isWatchEvent()) {
      _eventsController.add(event.watchEvent);
      return;
    }
  }

  @override
  void close() {
    // The "close" event is the only event sent to the isolate, just send
    // `null`.
    _sendPort!.send(null);
  }

  @override
  Stream<WatchEvent> get events => _eventsController.stream;

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  Future<void> get ready => _readyCompleter.future;
}

void _startIsolate(String path, SendPort sendPort) async {
  unawaited(Isolate.run(() => _isolate(path, sendPort)));
}

Future<void> _isolate(String path, SendPort sendPort) async {
  await _WatcherIsolate(path, sendPort).closed;
}

class _WatcherIsolate {
  final String path;
  final WindowsManuallyClosedDirectoryWatcher watcher;
  final SendPort sendPort;
  final Completer<void> _closeCompleter = Completer();
  Future<void> get closed => _closeCompleter.future;
  _WatcherIsolate(this.path, this.sendPort)
      : watcher = WindowsManuallyClosedDirectoryWatcher(path) {
    final receivePort = ReceivePort();

    // Three types of event are sent to the host.

    // `_Event.sendPort` on startup.
    sendPort.send(_Event.sendPort(receivePort.sendPort));

    // `_Event.ready` when ready.
    watcher.ready.then((_) {
      sendPort.send(_Event.ready());
    });

    // `_Event.watchEvent` on any event.
    // TODO: what about errors?
    watcher.events.listen((event) {
      sendPort.send(_Event.watchEvent(event));
    });

    receivePort.listen((event) {
      // The only event sent from the host to the isolate is "close".
      watcher.close();
      _closeCompleter.complete();
    });
  }
}

/// Event sent from the isolate to the host.
extension type _Event._(Object? _object) {
  factory _Event.sendPort(SendPort sendPort) => _Event._(sendPort);
  factory _Event.ready() => _Event._(null);
  factory _Event.watchEvent(WatchEvent event) {
    final typeNumber = switch (event.type) {
      ChangeType.ADD => 0,
      ChangeType.MODIFY => 1,
      ChangeType.REMOVE => 2,
      _ => throw ArgumentError.value(event.type),
    };
    return _Event._([typeNumber, event.path]);
  }

  factory _Event.fromObject(Object? object) {
    if (object == null) return _Event.ready();
    if (object is List || object is SendPort) return _Event._(object);
    throw ArgumentError.value(object, 'object');
  }

  bool isSendPort() => _object is SendPort;
  bool isReady() => _object == null;
  bool isWatchEvent() => _object is List;

  SendPort get sendPort => _object as SendPort;

  WatchEvent get watchEvent {
    _object as List;
    final typeNumber = _object[0] as int;
    final type = switch (typeNumber) {
      0 => ChangeType.ADD,
      1 => ChangeType.MODIFY,
      2 => ChangeType.REMOVE,
      _ => throw ArgumentError.value(typeNumber, 'type'),
    };
    final path = _object[1] as String;
    return WatchEvent(type, path);
  }
}
