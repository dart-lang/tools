// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Whether the current operating system is Windows.
/// 
/// Used to provide OS-tailored error messages for package configuration issues.
/// This acts as a platform-agnostic fallback when `dart:io` is unavailable.
bool get isWindows => false;
