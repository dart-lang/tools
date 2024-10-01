// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';

// TODO(cbracken) make generic
/// Retries the specified function with the specified interval and returns
/// the result on successful completion.
Future<dynamic> retry(Future Function() f, Duration interval,
    {Duration? timeout}) async {
  var keepGoing = true;

  Future<dynamic> withTimeout(Future Function() f, {Duration? duration}) {
    if (duration == null) {
      return f();
    }

    return f().timeout(duration, onTimeout: () {
      keepGoing = false;
      final msg = duration.inSeconds == 0
          ? '${duration.inMilliseconds}ms'
          : '${duration.inSeconds}s';
      throw StateError('Failed to complete within $msg');
    });
  }

  return withTimeout(() async {
    while (keepGoing) {
      try {
        return await f();
      } catch (_) {
        if (keepGoing) {
          await Future<dynamic>.delayed(interval);
        }
      }
    }
  }, duration: timeout);
}

/// Scrapes and returns the Dart VM service URI from a string, or null if not
/// found.
///
/// Potentially useful as a means to extract it from log statements.
Uri? extractVMServiceUri(String str) {
  final listeningMessageRegExp = RegExp(
    r'(?:Observatory|The Dart VM service is) listening on ((http|//)[a-zA-Z0-9:/=_\-\.\[\]]+)',
  );
  final match = listeningMessageRegExp.firstMatch(str);
  if (match != null) {
    return Uri.parse(match[1]!);
  }
  return null;
}

/// Returns an open port by creating a temporary Socket
Future<int> getOpenPort() async {
  ServerSocket socket;

  try {
    socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  } catch (_) {
    // try again v/ V6 only. Slight possibility that V4 is disabled
    socket =
        await ServerSocket.bind(InternetAddress.loopbackIPv6, 0, v6Only: true);
  }

  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

final muliLineIgnoreStart = RegExp(r'//\s*coverage:ignore-start[\w\d\s]*$');
final muliLineIgnoreEnd = RegExp(r'//\s*coverage:ignore-end[\w\d\s]*$');
final singleLineIgnore = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');
final ignoreFile = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');

/// Return list containing inclusive range of lines to be ignored by coverage.
/// If there is a error in balancing the statements it will throw a
/// [FormatException],
/// unless `coverage:ignore-file` is found.
/// Return [0, lines.length] if the whole file is ignored.
///
/// ```
/// 1.  final str = ''; // coverage:ignore-line
/// 2.  final str = '';
/// 3.  final str = ''; // coverage:ignore-start
/// 4.  final str = '';
/// 5.  final str = ''; // coverage:ignore-end
/// ```
///
/// Returns
/// ```
/// [
///   [1,1],
///   [3,5],
/// ]
/// ```
///
List<List<int>> getIgnoredLines(String filePath, List<String>? lines) {
  final ignoredLines = <List<int>>[];
  if (lines == null) return ignoredLines;

  final allLines = [
    [0, lines.length]
  ];

  FormatException? err;
  var i = 0;
  while (i < lines.length) {
    if (lines[i].contains(ignoreFile)) return allLines;

    if (lines[i].contains(muliLineIgnoreEnd)) {
      err ??= FormatException(
        'unmatched coverage:ignore-end found at $filePath:${i + 1}',
      );
    }

    if (lines[i].contains(singleLineIgnore)) ignoredLines.add([i + 1, i + 1]);

    if (lines[i].contains(muliLineIgnoreStart)) {
      final start = i;
      var isUnmatched = true;
      ++i;
      while (i < lines.length) {
        if (lines[i].contains(ignoreFile)) return allLines;
        if (lines[i].contains(muliLineIgnoreStart)) {
          err ??= FormatException(
            'coverage:ignore-start found at $filePath:${i + 1}'
            ' before previous coverage:ignore-start ended',
          );
          break;
        }

        if (lines[i].contains(muliLineIgnoreEnd)) {
          ignoredLines.add([start + 1, i + 1]);
          isUnmatched = false;
          break;
        }
        ++i;
      }

      if (isUnmatched) {
        err ??= FormatException(
          'coverage:ignore-start found at $filePath:${start + 1}'
          ' has no matching coverage:ignore-end',
        );
      }
    }
    ++i;
  }

  if (err == null) {
    return ignoredLines;
  }

  throw err;
}

extension StandardOutExtension on Stream<List<int>> {
  Stream<String> lines() =>
      transform(const SystemEncoding().decoder).transform(const LineSplitter());
}

Future<Uri> serviceUriFromProcess(Stream<String> procStdout) {
  // Capture the VM service URI.
  final serviceUriCompleter = Completer<Uri>();
  procStdout.listen((line) {
    if (!serviceUriCompleter.isCompleted) {
      final serviceUri = extractVMServiceUri(line);
      if (serviceUri != null) {
        serviceUriCompleter.complete(serviceUri);
      }
    }
  });
  return serviceUriCompleter.future;
}

Future<List<IsolateRef>> getAllIsolates(VmService service) async =>
    (await service.getVM()).isolates!;

/// Buffers VM service isolate [Event]s until [flush] is called.
///
/// [flush] passes each buffered event to the handler function. After that, any
/// further events are immediately passed to the handler. [flush] returns a
/// future that completes when all the events in the queue have been handled (as
/// well as any events that arrive while flush is in progress).
class IsolateEventBuffer {
  final Future<void> Function(Event event) _handler;
  final _buffer = Queue<Event>();
  var _flushed = true;

  IsolateEventBuffer(this._handler);

  Future<void> add(Event event) async {
    if (_flushed) {
      await _handler(event);
    } else {
      _buffer.add(event);
    }
  }

  Future<void> flush() async {
    while (_buffer.isNotEmpty) {
      final event = _buffer.removeFirst();
      await _handler(event);
    }
    _flushed = true;
  }
}

/// Keeps track of isolates in an isolate group.
///
/// Isolates are expected to go through either [start] -> [pause] -> [exit] or
/// simply [start] -> [exit]. [start] and [pause] return false if that sequence
/// is violated.
class IsolateGroupState {
  // IDs of the isolates running in this group.
  final _running = <String>{};

  // IDs of the isolates paused just before exiting in this group.
  final _paused = <String>{};

  // IDs of the isolates that have exited in this group.
  final _exited = <String>{};

  bool get noRunningIsolates => _running.isEmpty;
  bool get noIsolates => _running.isEmpty && _paused.isEmpty;

  bool start(String id) {
    if (_paused.contains(id) || _exited.contains(id)) return false;
    _running.add(id);
    return true;
  }

  bool pause(String id) {
    if (_exited.contains(id)) return false;
    _running.remove(id);
    _paused.add(id);
    return true;
  }

  void exit(String id) {
    _paused.remove(id);
    _running.remove(id);
    _exited.add(id);
  }
}

/// Calls onIsolatePaused whenever an isolate reaches the pause-on-exit state,
/// and passes a flag stating whether that isolate is the last one in the group.
class IsolatePausedListener {
  final VmService _service;
  final Future<void> Function(IsolateRef isolate, bool isLastIsolateInGroup)
        _onIsolatePaused;
  final _allExitedCompleter = Completer<void>();
  final _isolateGroups = <String, IsolateGroupState>{};
  bool _started = false;
  int _numAwaitedPauseCallbacks = 0;
  IsolateRef? _mainIsolate;


  IsolatePausedListener(this._service, this._onIsolatePaused);

  /// Starts listening and returns a future that completes when all isolates
  /// have exited.
  Future<void> listenUntilAllExited() async {
    // NOTE: Why is this class so complicated?
    //  - We only receive start/pause/exit events that arrive after we've
    //    subscribed (using _service.streamListen below).
    //  - So after we subscribe, we have to backfill any isolates that are
    //    already started/paused by looking at the current isolates.
    //  - But since that backfill is an async process, we may get isolate events
    //    arriving during that process.
    //  - So we buffer all the received events until the backfill is complete.
    //  - That means we can receive duplicate add/pause events: one from the
    //    backfill, and one from a real event that arrived during the backfill.
    //  - So the _onStart/_onPause/_onExit methods need to be robust to
    //    duplicate events (and out-of-order events to some extent, as the
    //    backfill's [add, pause] events and the real [add, pause, exit] events
    //    can be interleaved).
    //  - Finally, we resume each isolate after the its pause callback is done.
    //    But we need to delay resuming the main isolate until everything else
    //    is finished, because the VM shuts down once the main isolate exits.
    final eventBuffer = IsolateEventBuffer((Event event) async {
      switch(event.kind) {
        case EventKind.kIsolateStart:
          return _onStart(event.isolate!);
        case EventKind.kPauseExit:
          return _onPause(event.isolate!);
        case EventKind.kIsolateExit:
          return _onExit(event.isolate!);
      }
    });

    // Listen for isolate open/close events.
    _service.onIsolateEvent.listen(eventBuffer.add);
    await _service.streamListen(EventStreams.kIsolate);

    // Listen for isolate paused events.
    _service.onDebugEvent.listen(eventBuffer.add);
    await _service.streamListen(EventStreams.kDebug);

    // Backfill. Add/pause isolates that existed before we subscribed.
    final isolates = await getAllIsolates(_service);
    for (final isolateRef in isolates) {
      _onStart(isolateRef);
      final isolate = await _service.getIsolate(isolateRef.id!);
      if (isolate.pauseEvent!.kind == EventKind.kPauseExit) {
        await _onPause(isolateRef);
      }
    }

    // Flush the buffered stream events, and the start processing them as they
    // arrive.
    await eventBuffer.flush();

    await _allExitedCompleter.future;

    // Resume the main isolate.
    if (_mainIsolate != null) {
      print("      Resuming main isolate");
      await _service.resume(_mainIsolate!.id!);
    }
  }

  void _onStart(IsolateRef isolateRef) {
    print("Start event for ${isolateRef.name}");
    print("                ${isolateRef.id}");
    print("                ${isolateRef.number}");
    print("                ${isolateRef.isSystemIsolate}");
    print("                ${isolateRef.isolateGroupId}");
    final groupId = isolateRef.isolateGroupId!;
    final group = (_isolateGroups[groupId] ??= IsolateGroupState());
    group.start(isolateRef.id!);
    _started = true;
  }

  Future<void> _onPause(IsolateRef isolateRef) async {
    if (_allExitedCompleter.isCompleted) return;
    print("Pause event for ${isolateRef.name}");
    final String groupId = isolateRef.isolateGroupId!;
    final group = _isolateGroups[groupId];
    if (group == null) {
      // See NOTE in listenUntilAllExited.
      return;
    }

    if (group.pause(isolateRef.id!)) {
      ++_numAwaitedPauseCallbacks;
      try {
        await _onIsolatePaused(isolateRef, group.noRunningIsolates);
      } finally {
        print("    DONE Pause finally for ${isolateRef.name}");
        await _maybeResumeIsolate(isolateRef);
        --_numAwaitedPauseCallbacks;
        _maybeFinish();
      }
    }
    print("  DONE Pause event for ${isolateRef.name}");
  }

  static bool _isMainIsolate(IsolateRef isolateRef) {
    return isolateRef.name == 'main';
  }

  Future<void> _maybeResumeIsolate(IsolateRef isolateRef) async {
    if (_mainIsolate == null && _isMainIsolate(isolateRef)) {
      print("      Deferring main isolate resumption");
      _mainIsolate = isolateRef;
      // Pretend the main isolate has exited.
      _onExit(isolateRef);
    } else {
      print("      Resuming isolate: ${isolateRef.name}");
      await _service.resume(isolateRef.id!);
    }
  }

  void _onExit(IsolateRef isolateRef) {
    print("Exit event for ${isolateRef.name}");
    final String groupId = isolateRef.isolateGroupId!;
    final group = _isolateGroups[groupId];
    if (group == null) {
      // See NOTE in listenUntilAllExited.
      return;
    }
    group.exit(isolateRef.id!);
    if (group.noIsolates) {
      _isolateGroups.remove(groupId);
    }
    _maybeFinish();
  }

  void _maybeFinish() {
    print("MAYBE FINISH: ${_allExitedCompleter.isCompleted} ${_isolateGroups.isEmpty} ${_numAwaitedPauseCallbacks}");
    if (_allExitedCompleter.isCompleted) return;
    if (_started && _numAwaitedPauseCallbacks == 0 && _isolateGroups.isEmpty) {
      print("  >>> FINISH <<<");
      _allExitedCompleter.complete();
    }
  }
}
