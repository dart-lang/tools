# Developing `package:boring`

## Prebuilt Libraries and Release Workflow

In the `fetch` and `checkout` build modes, `hook/build.dart` provides:

- A **dynamic library** with all of BoringSSL when linking is disabled (`dart
  run`, `dart test`, and Flutter debug builds).
- A **static library** when linking is enabled (`dart build`, and Flutter
  profile and release builds), which `hook/link.dart` links into a tree-shaken
  dynamic library containing only the functions recorded via `@RecordUse()`.

Every GitHub Release contains both the dynamic and the static library for each
prebuilt target in [`lib/src/hook_helpers/targets.dart`](lib/src/hook_helpers/targets.dart).

The [`package:boring binaries`](../../.github/workflows/boring_binaries.yaml)
workflow builds the prebuilt libraries (`tool/precompile_binaries.dart`) from
the vendored BoringSSL whenever a change to the native sources (`src/`,
`third_party/boringssl/`, or `tool/REVISION`) lands on `main`, attaches them to
a `boring-binaries-<date>-<commit>` pre-release with a provenance attestation
(`gh attestation verify <file> --repo dart-lang/tools`), and opens a pull
request (`tool/regenerate_hashes.dart`) that pins their SHA-256 hashes in
[`lib/src/hook_helpers/hashes.dart`](lib/src/hook_helpers/hashes.dart).

CI (`tool/check_prebuilt_binaries.sh`) checks that a release of this package
pins libraries built from the sources it vendors, so `fetch` and `checkout`
produce the same BoringSSL.

## Updating BoringSSL and Regenerating Bindings

Run `./tool/bump-boringssl-revision.sh [revision]` to update the vendored
BoringSSL under `third_party/boringssl/`, record the commit in `tool/REVISION`,
and regenerate the FFI bindings (`tool/ffigen.dart`). The `generated` job in
[`boring.yaml`](../../.github/workflows/boring.yaml) runs on `ubuntu-24.04` and
verifies that all generated files and [`hashes.dart`](lib/src/hook_helpers/hashes.dart)
are up to date.
