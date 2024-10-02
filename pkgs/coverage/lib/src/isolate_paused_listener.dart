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
    await listenToIsolateLifecycleEvents(_service, _onStart, _onPause, _onExit);

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
    group.pause(isolateRef.id!);
    try {
      await _onIsolatePaused(isolateRef, group.noRunningIsolates);
    } finally {
      await _maybeResumeIsolate(isolateRef);
    }
  }

  Future<void> _maybeResumeIsolate(IsolateRef isolateRef) async {
    if (_mainIsolate == null && _isMainIsolate(isolateRef)) {
      _mainIsolate = isolateRef;
      // Pretend this isolate has exited so _allExitedCompleter can complete.
      _onExit(isolateRef);
    } else {
      await _service.resume(isolateRef.id!);
    }
  }

  void _onExit(IsolateRef isolateRef) {
    if (_allExitedCompleter.isCompleted) return;
    _getGroup(isolateRef).exit(isolateRef.id!);
    if (isolateGroups.values.every((group) => group.noLiveIsolates)) {
      _allExitedCompleter.complete();
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
}

/// Listens to isolate start and pause events, and backfills events for isolates
/// that existed before listening started.
///
/// Ensures that:
///  - Every [onIsolatePaused] and [onIsolateExited] call will be preceeded by
///    an [onIsolateStarted] call for the same isolate.
///  - Not every [onIsolateExited] call will be preceeded by a [onIsolatePaused]
///    call, but a [onIsolatePaused] will never follow a [onIsolateExited].
///  - Each callback will only be called once per isolate.
Future<void> listenToIsolateLifecycleEvents(
    VmService service,
    void Function(IsolateRef isolate) onIsolateStarted,
    Future<void> Function(IsolateRef isolate) onIsolatePaused,
    void Function(IsolateRef isolate) onIsolateExited) async {
  final started = <String>{};
  void onStart(IsolateRef isolateRef) {
    if (started.add(isolateRef.id!)) onIsolateStarted(isolateRef);
  }

  final paused = <String>{};
  Future<void> onPause(IsolateRef isolateRef) async {
    onStart(isolateRef);
    if (paused.add(isolateRef.id!)) await onIsolatePaused(isolateRef);
  }

  final exited = <String>{};
  void onExit(IsolateRef isolateRef) {
    onStart(isolateRef);
    paused.add(isolateRef.id!);
    if (exited.add(isolateRef.id!)) onIsolateExited(isolateRef);
  }

  final eventBuffer = IsolateEventBuffer((Event event) async {
    switch (event.kind) {
      case EventKind.kIsolateStart:
        return onStart(event.isolate!);
      case EventKind.kPauseExit:
        return await onPause(event.isolate!);
      case EventKind.kIsolateExit:
        return onExit(event.isolate!);
    }
  });

  // Listen for isolate start/exit events.
  service.onIsolateEvent.listen(eventBuffer.add);
  await service.streamListen(EventStreams.kIsolate);

  // Listen for isolate paused events.
  service.onDebugEvent.listen(eventBuffer.add);
  await service.streamListen(EventStreams.kDebug);

  // Backfill. Add/pause isolates that existed before we subscribed.
  for (final isolateRef in await getAllIsolates(service)) {
    onStart(isolateRef);
    final isolate = await service.getIsolate(isolateRef.id!);
    if (isolate.pauseEvent!.kind == EventKind.kPauseExit) {
      await onPause(isolateRef);
    }
  }

  // Flush the buffered stream events, and the start processing them as they
  // arrive.
  await eventBuffer.flush();
}

/// Keeps track of isolates in an isolate group.
class IsolateGroupState {
  // IDs of the isolates running in this group.
  @visibleForTesting
  final running = <String>{};

  // IDs of the isolates paused just before exiting in this group.
  @visibleForTesting
  final paused = <String>{};

  bool get noRunningIsolates => running.isEmpty;
  bool get noLiveIsolates => running.isEmpty && paused.isEmpty;

  void start(String id) {
    paused.remove(id);
    running.add(id);
  }

  void pause(String id) {
    running.remove(id);
    paused.add(id);
  }

  void exit(String id) {
    running.remove(id);
    paused.remove(id);
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
