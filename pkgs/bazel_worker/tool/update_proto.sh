#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Expected exactly one argument which is the protoc_plugin version to use"
else
    echo "Using protoc_plugin version $1"
    pub global activate protoc_plugin "$1"
fi

BAZEL_REPO=.dart_tool/bazel_worker/bazel.git/
# Bash away old versions if they exist
rm -rf "$BAZEL_REPO"
git clone https://github.com/bazelbuild/bazel.git "$BAZEL_REPO"

protoc --proto_path="${BAZEL_REPO}/src/main/protobuf" --dart_out=lib/src worker_protocol.proto
dartfmt -w lib/src/worker_protocol.pb.dart

# We only care about the *.pb.dart file, not the extra files
rm lib/src/worker_protocol.pbenum.dart
rm lib/src/worker_protocol.pbjson.dart
rm lib/src/worker_protocol.pbserver.dart

rm -rf "$BAZEL_REPO"
