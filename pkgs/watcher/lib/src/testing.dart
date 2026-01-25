// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Set to override for async testing.
DateTime Function() overridableDateTimeNow = DateTime.now;

/// Set to log watcher internals for testing.
void Function(String)? logForTesting;

/// Set to log watcher internals for testing when watcher runs on a different
/// isolate.
void Function(LogEntry)? logSeparateIsolateForTesting;

/// Log entry with timestamp.
///
/// Used when the entry is generated on a different isolate, so the log entries
/// can be correctly ordered.
class LogEntry implements Comparable<LogEntry> {
  final DateTime timestamp;
  final String message;

  LogEntry._(this.timestamp, this.message);

  LogEntry(this.message) : timestamp = DateTime.now();

  LogEntry withMessage(String message) => LogEntry._(timestamp, message);

  @override
  int compareTo(LogEntry other) => timestamp.compareTo(other.timestamp);

  @override
  String toString() => message;
}
