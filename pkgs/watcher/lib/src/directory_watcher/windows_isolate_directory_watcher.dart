// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import '../resubscribable.dart';
import '../watch_event.dart';
import 'windows_manually_closed_directory_watcher.dart';

class WindowsIsolateDirectoryWatcher implements ManuallyClosedWatcher {
  @override
  final String path;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;

// TODO(davidmorgan): broadcast?
  final StreamController<WatchEvent> _eventsController = StreamController();
  final Completer<void> _readyCompleter = Completer();

  WindowsIsolateDirectoryWatcher(this.path) {
    _startIsolate(path, _receivePort.sendPort);
    _receivePort.listen((event) {
      if (_sendPort == null) {
        _sendPort = event as SendPort;
        return;
      } else if (event == 'ready') {
        _readyCompleter.complete();
        return;
      } else if (event is List) {
        for (var i = 0; i != event.length; i += 2) {
          final type = _parseChangeType(event[i] as int);
          final path = event[i + 1] as String;
          _eventsController.add(WatchEvent(type, path));
        }
      }
    });
  }

  @override
  void close() {
    _sendPort!.send('close');
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
    sendPort.send(receivePort.sendPort);

    watcher.events.listen((event) {
      sendPort.send([event.type.index, event.path]);
    });
    watcher.ready.then((_) {
      sendPort.send('ready');
    });

    receivePort.listen((event) {
      if (event == 'close') {
        watcher.close();
        _closeCompleter.complete();
      }
    });
  }
}

ChangeType _parseChangeType(int type) {
  switch (type) {
    case 0:
      return ChangeType.ADD;
    case 1:
      return ChangeType.MODIFY;
    case 2:
      return ChangeType.REMOVE;
    default:
      throw ArgumentError.value(type, 'type');
  }
}

extension ChangeTypeExtensions on ChangeType {
  int get index {
    switch (this) {
      case ChangeType.ADD:
        return 0;
      case ChangeType.MODIFY:
        return 1;
      case ChangeType.REMOVE:
        return 2;
      default:
        throw ArgumentError.value(this);
    }
  }
}
