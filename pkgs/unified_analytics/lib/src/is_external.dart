// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Indicates whether the analytics package is running in an external build.
///
/// When `true` (default), consent messages are displayed on first run and
/// telemetry status is read from the configuration file.
///
/// When `false`, the first run check is bypassed, no consent message is shown,
/// telemetry is always enabled, and the configuration file is not read.
const bool isExternal = true;
