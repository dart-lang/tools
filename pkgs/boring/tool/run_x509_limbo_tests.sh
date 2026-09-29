#!/usr/bin/env bash
# Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

# Pinned so the checked-in expected-failures list stays meaningful. To update:
# bump LIMBO_REF and LIMBO_SHA256, delete build/x509-limbo, then re-run with
# X509_LIMBO_REGENERATE=1.
LIMBO_REF="${LIMBO_REF:-3f8cba420e90322223486086054401189b7b320e}"
LIMBO_SHA256="563805f46937ad25ac9d4e41341c414070aced32a22294821b5c5fe526e2c52d"
LIMBO_DIR="$DIR/build/x509-limbo"
LIMBO_JSON="$LIMBO_DIR/limbo.json"

if [ ! -f "$LIMBO_JSON" ]; then
  echo "==> Downloading x509-limbo ($LIMBO_REF) testcases into $LIMBO_JSON..."
  mkdir -p "$LIMBO_DIR"
  curl -fsSL \
    "https://raw.githubusercontent.com/C2SP/x509-limbo/$LIMBO_REF/limbo.json" \
    -o "$LIMBO_JSON.tmp"
  if [ "$LIMBO_REF" = "3f8cba420e90322223486086054401189b7b320e" ]; then
    echo "$LIMBO_SHA256  $LIMBO_JSON.tmp" | sha256sum --check --status
  fi
  mv "$LIMBO_JSON.tmp" "$LIMBO_JSON"
fi

echo "==> Running x509-limbo conformance tests with package:boring..."
dart test test/conformance/x509_limbo_test.dart
