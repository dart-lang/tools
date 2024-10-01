// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import 'util.dart';

/// Calls onIsolatePaused whenever an isolate reaches the pause-on-exit state,
/// and passes a flag stating whether that isolate is the last one in the group.
class IsolatePausedListener {
  IsolatePausedListener(this._service, this._onIsolatePaused);

  final VmService _service;
  final Future<void> Function(IsolateRef isolate, bool isLastIsolateInGroup)
      _onIsolatePaused;
  final _allExitedCompleter = Completer<void>();
  IsolateRef? _mainIsolate;

  @visibleForTesting
  final isolateGroups = <String, IsolateGroupState>{};

  /// Starts listening and returns a future that completes when all isolates
  /// have exited.
  Future<void> waitUntilAllExited() async {
    // NOTE: Why is this class so complicated?
    //  - We only receive start/pause events that arrive after we've subscribed,
    //    using _service.streamListen below.
    //  - So after we subscribe, we have to backfill any isolates that are
    //    already started/paused by looking at the current isolates.
    //  - But since that backfill is an async process, we may get isolate events
    //    arriving during that process. Eg, a lone pause event received before
    //    the backfill would complete the _allExitedCompleter before any other
    //    isolate groups have been seen.
    //  - The simplest and most robust way of solving this issue is to buffer
    //    all the received events until the backfill is complete.
    //  - That means we can receive duplicate add/pause events: one from the
    //    backfill, and one from a real event that arrived during the backfill.
    //  - So the _onStart/_onPause methods need to be robust to duplicate events
    //    (and out-of-order events to some extent, as the backfill's events and
    //    the real] events can be interleaved).
    //  - Finally, we resume each isolate after the its pause callback is done.
    //    But we need to delay resuming the main isolate until everything else
    //    is finished, because the VM shuts down once the main isolate exits.
    final eventBuffer = IsolateEventBuffer((Event event) async {
      switch (event.kind) {
        case EventKind.kIsolateStart:
          return _onStart(event.isolate!);
        case EventKind.kPauseExit:
          return _onPause(event.isolate!);
      }
    });

    // Listen for isolate open/close events.
    _service.onIsolateEvent.listen(eventBuffer.add);
    await _service.streamListen(EventStreams.kIsolate);

    // Listen for isolate paused events.
    _service.onDebugEvent.listen(eventBuffer.add);
    await _service.streamListen(EventStreams.kDebug);

    // Backfill. Add/pause isolates that existed before we subscribed.
    for (final isolateRef in await getAllIsolates(_service)) {
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
      await _service.resume(_mainIsolate!.id!);
    }
  }

  IsolateGroupState _getGroup(IsolateRef isolateRef) =>
      isolateGroups[isolateRef.isolateGroupId!] ??= IsolateGroupState();

  void _onStart(IsolateRef isolateRef) {
    if (_allExitedCompleter.isCompleted) return;
    _getGroup(isolateRef).start(isolateRef.id!);
  }

  Future<void> _onPause(IsolateRef isolateRef) async {
    if (_allExitedCompleter.isCompleted) return;
    final group = _getGroup(isolateRef);
    if (group.pause(isolateRef.id!)) {
      try {
        await _onIsolatePaused(isolateRef, group.noRunningIsolates);
      } finally {
        await _maybeResumeIsolate(isolateRef);
        group.exit(isolateRef.id!);
        _maybeFinish();
      }
    }
  }

  static bool _isMainIsolate(IsolateRef isolateRef) {
    // HACK: This should pretty reliably detect the main isolate, but it's not
    // foolproof and relies on unstable features. The Dart standalone embedder
    // and Flutter both call the main isolate "main", and they both also list
    // this isolate first when querying isolates from the VM service. So
    // selecting the first isolate named "main" combines these conditions and
    // should be reliable enough for now, while we wait for a better test.
    // TODO(https://github.com/dart-lang/sdk/issues/56732): Switch to more
    // reliable test when it's available.
    return isolateRef.name == 'main';
  }

  Future<void> _maybeResumeIsolate(IsolateRef isolateRef) async {
    if (_mainIsolate == null && _isMainIsolate(isolateRef)) {
      _mainIsolate = isolateRef;
    } else {
      await _service.resume(isolateRef.id!);
    }
  }

  void _maybeFinish() {
    if (_allExitedCompleter.isCompleted) return;
    if (isolateGroups.values.every((group) => group.noIsolates)) {
      _allExitedCompleter.complete();
    }
  }
}

/// Keeps track of isolates in an isolate group.
///
/// Isolates are expected to go through either [start] -> [pause] -> [exit] or
/// simply [start] -> [exit]. [start] and [pause] return false if that sequence
/// is violated.
class IsolateGroupState {
  // IDs of the isolates running in this group.
  @visibleForTesting
  final running = <String>{};

  // IDs of the isolates paused just before exiting in this group.
  @visibleForTesting
  final paused = <String>{};

  // IDs of the isolates that have exited in this group.
  @visibleForTesting
  final exited = <String>{};

  bool get noRunningIsolates => running.isEmpty;
  bool get noIsolates => running.isEmpty && paused.isEmpty;

  bool start(String id) {
    if (paused.contains(id) || exited.contains(id)) return false;
    running.add(id);
    return true;
  }

  bool pause(String id) {
    if (exited.contains(id)) return false;
    running.remove(id);
    paused.add(id);
    return true;
  }

  void exit(String id) {
    paused.remove(id);
    running.remove(id);
    exited.add(id);
  }
}

/// Buffers VM service isolate [Event]s until [flush] is called.
///
/// [flush] passes each buffered event to the handler function. After that, any
/// further events are immediately passed to the handler. [flush] returns a
/// future that completes when all the events in the queue have been handled (as
/// well as any events that arrive while flush is in progress).
class IsolateEventBuffer {
  IsolateEventBuffer(this._handler);

  final Future<void> Function(Event event) _handler;
  final _buffer = Queue<Event>();
  var _flushed = true;

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
