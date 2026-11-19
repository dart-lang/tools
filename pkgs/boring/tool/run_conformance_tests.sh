#!/usr/bin/env bash
# Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

CONFORMANCE_DIR="$DIR/build/wycheproof"
if [ ! -d "$CONFORMANCE_DIR/testvectors_v1" ]; then
  echo "==> Cloning Project Wycheproof test vectors into $CONFORMANCE_DIR..."
  mkdir -p "$DIR/build"
  git -c url.https://github.com/.insteadof=https://github.com/ clone --depth 1 https://github.com/google/wycheproof.git "$CONFORMANCE_DIR"
fi

echo "==> Running Wycheproof conformance tests with package:boring..."
dart test test/conformance/wycheproof_test.dart
