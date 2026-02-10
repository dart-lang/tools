// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'event.dart';
import 'paths.dart';
import 'testing.dart';

/// Buffers [FileSystemEvent] streams into batches of events.
///
/// Two batching strategies are available: "nearby microtask" and "buffered by
/// path".
extension BatchEvents on Stream<FileSystemEvent> {
  /// Batches all events that are sent at the same time.
  ///
  /// When multiple events are synchronously added to a stream controller, the
  /// [StreamController] implementation uses [scheduleMicrotask] to schedule the
  /// asynchronous firing of each event. In order to recreate the synchronous
  /// batches, this collates all the events that are received in "nearby"
  /// microtasks.
  ///
  /// Converts to [Event] using [Event.checkAndConvert], discarding events for
  /// which it returns `null`.
  Stream<List<Event>> batchNearbyMicrotasksAndConvertEvents() {
    var batch = <Event>[];
    return StreamTransformer<FileSystemEvent, List<Event>>.fromHandlers(
      handleData: (event, sink) {
        var convertedEvent = Event.checkAndConvert(event);
        if (convertedEvent == null) return;
        batch.add(convertedEvent);

        // [Timer.run] schedules an event that runs after any microtasks that
        // have been scheduled.
        Timer.run(() {
          if (batch.isEmpty) return;
          sink.add(batch.toList());
          batch.clear();
        });
      },
      handleDone: (sink) {
        if (batch.isNotEmpty) {
          sink.add(batch.toList());
          batch.clear();
        }
        sink.close();
      },
    ).bind(this);
  }

  /// Batches events by path.
  ///
  /// For each path, events are emitted when they are at least [duration] old.
  /// Rather than emitting split by path, all pending events are periodically
  /// checked and all old-enough events are emitted in one batch.
  Stream<List<Event>> batchBufferedByPathAndConvertEvents({
    required Duration duration,
  }) {
    final batcher = _PathBufferedBatcher(duration);
    return StreamTransformer<FileSystemEvent, List<Event>>.fromHandlers(
      handleData: batcher.handleData,
      handleDone: batcher.handleDone,
    ).bind(this);
  }
}

class _PathBufferedBatcher {
  final bufferedEvents = <AbsolutePath, _BufferedEvents>{};
  final Duration duration;
  bool checkAndEmitIsPending = false;

  _PathBufferedBatcher(this.duration);

  /// Adds events to [bufferedEvents].
  ///
  /// Calls [maybeScheduleCheckAndEmit] to schedule a [checkAndEmit] if none is
  /// already pending.
  void handleData(FileSystemEvent event, Sink<List<Event>> sink) {
    final convertedEvent = Event.checkAndConvert(event);
    if (convertedEvent == null) return;
    for (final splitEvent in convertedEvent.splitIfMove()) {
      bufferedEvents
          .putIfAbsent(splitEvent.absolutePath, _BufferedEvents.new)
          .add(splitEvent);
    }
    maybeScheduleCheckAndEmit(sink);
  }

  /// If there is no timer running and there are events buffered, starts a timer
  /// with delay [duration] that will call [checkAndEmit] on [sink].
  void maybeScheduleCheckAndEmit(Sink<List<Event>> sink) {
    if (checkAndEmitIsPending) return;
    if (bufferedEvents.isEmpty) return;
    checkAndEmitIsPending = true;
    Timer(duration, () => checkAndEmit(sink));
  }

  /// Emits events older than [duration] to [sink].
  ///
  /// If any events remain, calls [maybeScheduleCheckAndEmit] to schedule
  /// another check.
  void checkAndEmit(Sink<List<Event>> sink) {
    checkAndEmitIsPending = false;

    final events = <Event>[];
    final sendEventsBefore = overridableDateTimeNow().subtract(duration);
    for (var entry in bufferedEvents.entries.toList()) {
      if (entry.value.lastUpdated.isBefore(sendEventsBefore)) {
        events.addAll(entry.value.events);
        bufferedEvents.remove(entry.key);
      }
    }
    if (events.isNotEmpty) {
      sink.add(events);
    }
    maybeScheduleCheckAndEmit(sink);
  }

  /// Flushes buffered events and closes the [sink].
  void handleDone(Sink<List<Event>> sink) {
    if (bufferedEvents.isNotEmpty) {
      sink.add(bufferedEvents.values.expand((x) => x.events).toList());
      bufferedEvents.clear();
    }
    sink.close();
  }
}

class _BufferedEvents {
  final List<Event> events = [];
  DateTime _lastUpdated;

  _BufferedEvents() : _lastUpdated = overridableDateTimeNow();

  void add(Event event) {
    events.add(event);
    _lastUpdated = overridableDateTimeNow();
  }

  DateTime get lastUpdated => _lastUpdated;
}
