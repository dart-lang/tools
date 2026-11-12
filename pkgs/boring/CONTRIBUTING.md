# Developing `package:boring`

## Prebuilt Libraries and Release Workflow

In the `fetch` and `checkout` build modes, `hook/build.dart` provides:

- A **dynamic library** with all of BoringSSL when linking is disabled (`dart
  run`, `dart test`, and Flutter debug builds).
- A **static library** when linking is enabled (`dart build`, and Flutter
  profile and release builds), which `hook/link.dart` links into a tree-shaken
  dynamic library containing only the functions recorded via `@RecordUse()`.

The package published on pub.dev contains both the dynamic and the static
library for each prebuilt target in
[`lib/src/hook_helpers/targets.dart`](lib/src/hook_helpers/targets.dart), in
`prebuilt/<target>/`, where the `fetch` build mode uses them. They are not
checked in: `.gitignore` ignores `prebuilt/`, but [`.pubignore`](.pubignore),
which pub reads instead, doesn't.

The [`package:boring binaries`](../../.github/workflows/boring_binaries.yaml)
workflow builds the prebuilt libraries (`tool/precompile_binaries.dart`) from
the vendored BoringSSL, adds them to `prebuilt/`, creates the package archive,
and builds the example against it on each desktop OS
([`test/prebuilt_test.dart`](test/prebuilt_test.dart)). It does so for pull
requests that change the native build, the hooks, or the workflow, and when a
change to the native sources (`src/`, `third_party/boringssl/`, or
`tool/REVISION`) lands on `main`.

To release, push a `boring-v<version>` tag, for example by creating a GitHub
release with it. The workflow then builds the libraries from the tagged commit,
attests their provenance
(`gh attestation verify <file> --repo dart-lang/tools`), and publishes the
tested archive to pub.dev. [`publish.yaml`](../../.github/workflows/publish.yaml),
which publishes the other packages of this repository, skips these tags. As the
libraries are built from the tagged commit, the `fetch` and `checkout` build
modes produce the same BoringSSL.

`dart run tool/precompile_binaries.dart` writes the libraries for the current
OS to `prebuilt/`, so that a path dependency on a checkout can use the `fetch`
build mode. To run `test/prebuilt_test.dart` locally, download the
`package-archive` artifact of a workflow run, extract the `package.tar.gz` in
it, and set `BORING_PACKAGE_DIR` to the extracted directory.

## Updating BoringSSL and Regenerating Bindings

Run `./tool/bump-boringssl-revision.sh [revision]` to update the vendored
BoringSSL under `third_party/boringssl/`, record the commit in `tool/REVISION`,
and regenerate the FFI bindings (`tool/ffigen.dart`). The `generated` job in
[`boring.yaml`](../../.github/workflows/boring.yaml) runs on `ubuntu-24.04` and
verifies that all generated files are up to date.

The `refresh` job in the same workflow runs the script weekly against the
latest BoringSSL revision and opens a pull request with the result.

### X.509 conformance

[`test/conformance/x509_limbo_test.dart`](test/conformance/x509_limbo_test.dart)
runs the [x509-limbo](https://x509-limbo.com) path validation suite against the
vendored BoringSSL, and
[`x509_limbo_expected_failures.txt`](test/conformance/x509_limbo_expected_failures.txt)
records the testcases BoringSSL is known to disagree with. The `x509-limbo` job
fails on a divergence that the list does not record, and on a listed testcase
that started agreeing, so the list cannot go stale.

BoringSSL's X.509 behavior changes between revisions. After updating it, run

```sh
X509_LIMBO_REGENERATE=1 ./tool/run_x509_limbo_tests.sh
```

to regenerate the list, and read the diff to see the change in behavior. The
`refresh` job does this for its pull requests, so a change to the list there is
part of what to review.
