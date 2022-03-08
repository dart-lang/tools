#!/bin/bash

# Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Gather coverage
if [[ $(dart --version 2>&1 ) =~ '(dev)' ]]; then
  OBS_PORT=9292
  echo "Collecting coverage on port $OBS_PORT..."

  # Start tests in one VM.
  dart --disable-service-auth-codes \
    --enable-vm-service=$OBS_PORT \
    --pause-isolates-on-exit \
    test/test_all.dart &

  # Run the coverage collector to generate the JSON coverage report.
  dart bin/collect_coverage.dart \
    --port=$OBS_PORT \
    --out=var/coverage.json \
    --wait-paused \
    --resume-isolates

  echo "Generating LCOV report..."
  dart bin/format_coverage.dart \
    --lcov \
    --in=var/coverage.json \
    --out=var/lcov.info \
    --packages=.dart_tool/package_config.json \
    --report-on=lib \
    --check-ignore
fi
