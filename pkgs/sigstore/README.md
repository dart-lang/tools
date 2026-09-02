# Sigstore Dart Client (`package:sigstore`)

A Dart client library for [Sigstore](https://www.sigstore.dev/) focused on **cryptographic bundle inspection and artifact verification**. It wraps the official [`sigstore-rust`](https://github.com/sigstore/sigstore-rust) verification crates (`sigstore-verify`, `sigstore-trust-root`, `sigstore-types`) using **[Diplomat](https://github.com/rust-diplomat/diplomat)** for FFI code generation and Dart **Native Assets** (`hook/build.dart`).

> [!NOTE]
> **Scope**: This package is **verification-only**. It verifies artifacts and software supply chain signatures against Sigstore bundles (including Fulcio X.509 certificates, Rekor transparency logs, RFC 3161 timestamps, and custom/production/staging trusted roots). Keyless signing (which requires interactive OIDC authorization and CA submission) is not part of this package.

## Features

- **100% Upstream Verification Conformance**: Passes all 140 applicable bundle verification test suites from [`sigstore-conformance`](https://github.com/sigstore/sigstore-conformance).
- **Flexible Trusted Roots**: Supports verification with the Sigstore Public Good Instance (Production), Sigstore Staging, or custom `trusted_root.json` files.
- **Identity & Issuer Policy Verification**: Validates signer Subject Alternative Name (SAN) identities and OIDC issuers.
- **Pre-computed Digest & Raw Byte Verification**: Verifies both raw artifact files and SHA-256 pre-computed digests (`sha256:...`).
- **Flexible Native Asset Modes** (following `package:icu4x` conventions):
  - `fetch` (default for package consumers): Automatically downloads precompiled native binaries from GitHub releases and verifies their SHA-256 hashes against `lib/src/hook_helpers/hashes.dart`.
  - `checkout`: Builds fresh native binaries directly from the embedded Rust crate using `cargo`.
  - `local`: Links against an existing binary specified via `localPath`.

## Usage

```dart
import 'dart:io';
import 'package:sigstore/sigstore.dart';

void main() async {
  // 1. Create client instance
  final client = SigstoreClient.create();

  // 2. Load bundle and artifact
  final bundleJson = await File('bundle.sigstore.json').readAsString();
  final artifactBytes = await File('artifact.tar.gz').readAsBytes();
  final bundle = SigstoreBundle.fromJson(bundleJson);

  // 3. Define verification policy
  final policy = SigstoreVerificationPolicy.create(
    'https://github.com/owner/repo/.github/workflows/release.yml@refs/heads/main', // expected identity
    'https://token.actions.githubusercontent.com',                                  // expected issuer
    true,   // offline verification
    false,  // isStaging (false = production root)
    '',     // optional custom trusted_root.json
    '',     // optional standalone public key PEM
  );

  // 4. Verify artifact
  final result = client.verify(artifactBytes, false, bundle, policy);

  if (result.isValid()) {
    print('Verified signer identity: ${result.verifiedIdentity()}');
    print('Verified OIDC issuer: ${result.verifiedIssuer()}');
  }
}
```

## Development & Tooling

### Generating Dart Bindings
Regenerates Diplomat C-ABI and Dart FFI wrappers from `rust/src/lib.rs`:
```bash
dart run tool/generate_bindings.dart
```

### Running Unit Tests
```bash
dart test
```

### Running Upstream Sigstore Conformance Tests
Compiles the standalone conformance CLI executable and runs the upstream `sigstore-conformance` pytest suite:
```bash
./tool/run_conformance_tests.sh
```

### Precompiling Release Binaries & Hashes
```bash
dart run tool/precompile_binaries.dart
dart run tool/regenerate_hashes.dart <github-release-tag>
```

## Releasing & Updating the Library

Because this package ships precompiled native binaries for multiple platforms in `fetch` mode, releases follow a simple 4-step workflow to ensure binary hashes are calculated and committed before publishing to `pub.dev`.

### 1. Update Code & Regenerate Bindings (if Rust changed)
If modifying Rust code in `rust/src/`:
```bash
dart run tool/generate_bindings.dart
dart test
./tool/run_conformance_tests.sh
```

### 2. Bump Version & Build Precompiled Binaries
1. Update `version` in `pubspec.yaml` and document changes in `CHANGELOG.md` (e.g., `0.2.0`).
2. Trigger the GitHub Actions binary build for `binaries-v<version>`:
   ```bash
   gh workflow run release-binaries.yml -f tag=binaries-v0.2.0
   ```
   *(Or trigger manually in GitHub under **Actions &rarr; Release Binaries &rarr; Run workflow**)*
3. Wait for the workflow to finish building across Linux, macOS, and Windows runners and attaching assets to the `binaries-v0.2.0` GitHub Release.

### 3. Regenerate Hashes & Open PR
1. Run the hash generator to download the newly built binaries and populate `lib/src/hook_helpers/hashes.dart`:
   ```bash
   dart run tool/regenerate_hashes.dart binaries-v0.2.0
   ```
2. Commit your changes to a feature branch and open a PR:
   ```bash
   git checkout -b release-v0.2.0
   git add pubspec.yaml CHANGELOG.md lib/src/hook_helpers/hashes.dart
   git commit -m "chore: prepare for 0.2.0 release"
   git push -u origin release-v0.2.0
   gh pr create --title "Release v0.2.0" --body "Prepare release 0.2.0"
   ```
3. CI will verify the checks, including downloading and testing the precompiled binaries across Linux, macOS, and Windows. The `dart-lang/ecosystem` publish bot will validate the package and comment that it is `ready to publish`.

### 4. Merge & Publish to pub.dev
1. Merge the PR into `main`.
2. Tag the release commit and push the tag:
   ```bash
   git checkout main && git pull origin main
   git tag v0.2.0
   git push origin v0.2.0
   ```
3. The `.github/workflows/publish.yaml` workflow will automatically authenticate with `pub.dev` via OIDC and publish the package.
