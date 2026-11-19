#!/usr/bin/env bash
# Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Checks that the prebuilt libraries pinned in lib/src/hook_helpers/hashes.dart
# were built from the current native sources (src/, third_party/boringssl/, and
# tool/REVISION).
#
# Warns if the package version in pubspec.yaml is a -wip version, and fails
# otherwise, so a release of package:boring can't ship stale prebuilt libraries.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

source_commit="$(sed -n "s/^const sourceCommit = '\([0-9a-f]*\)';$/\1/p" lib/src/hook_helpers/hashes.dart)"
stale=false
if [ -z "$source_commit" ]; then
  stale=true
  message="The prebuilt libraries pinned in lib/src/hook_helpers/hashes.dart weren't built from this repository."
else
  git fetch --quiet --depth=1 origin "$source_commit"
  if ! git diff --quiet "$source_commit" HEAD -- src third_party/boringssl tool/REVISION; then
    stale=true
    message="src/, third_party/boringssl/ or tool/REVISION changed since the prebuilt libraries pinned in lib/src/hook_helpers/hashes.dart were built at $source_commit."
  fi
fi

if [ "$stale" = true ]; then
  message="$message The 'package:boring binaries' workflow builds and pins new ones when such a change lands on main; merge its pull request before releasing."
  if grep -Eq '^version: .*-wip$' pubspec.yaml; then
    echo "::warning::$message"
  else
    echo "::error::$message"
    exit 1
  fi
else
  echo "The prebuilt libraries were built from the current native sources ($source_commit)."
fi
