# Sigstore Dart Client (`package:sigstore`)

A Dart client library for [Sigstore](https://www.sigstore.dev/) focused on **cryptographic bundle inspection and artifact verification**. It wraps the official [`sigstore-rust`](https://github.com/sigstore/sigstore-rust) verification crates (`sigstore-verify`, `sigstore-trust-root`, `sigstore-tuf`, `sigstore-types`, `sigstore-crypto`) using **[Diplomat](https://github.com/rust-diplomat/diplomat)** for FFI code generation, Dart **Native Assets** (`hook/build.dart`), and **[`package:boring`](https://pub.dev/packages/boring)** for all underlying BoringSSL cryptography.

> [!NOTE]
> **Scope**: This package is **verification-only**. It verifies artifacts and software supply chain signatures against Sigstore bundles (including Fulcio X.509 certificates, Rekor transparency logs, RFC 3161 timestamps, and custom/production/staging trusted roots). Keyless signing (which requires interactive OIDC authorization and CA submission) is not part of this package.

## Features

- **100% Upstream Verification Conformance**: Passes all 140 applicable bundle verification test suites from [`sigstore-conformance`](https://github.com/sigstore/sigstore-conformance).
- **Powered by `package:boring` (Zero AWS-LC)**: Implements `sigstore-rust`'s `sigstore_crypto::CryptoProvider` on top of `package:boring` (`libbssl_dart`), so all cryptographic operations (SHA-256/384/512, ECDSA P-256/P-384, Ed25519, RSA PKCS#1 v1.5 & PSS) run in BoringSSL. This eliminates `aws-lc-sys` and shrinks the native library by ~60% (3.99 MB → 1.51 MB for Linux x64). ML-DSA (post-quantum) signatures are not supported by this backend yet.
- **TUF Trusted Root Refresh via Dart HTTP**: Uses `sigstore-tuf`'s TUF verification state machine driven by Dart's `HttpClient` (`await client.refreshTrustedRoot(...)`) with zero embedded Rust HTTP/TLS stack (`tokio`/`reqwest`/`hyper`/`rustls`).
- **Flexible Trusted Roots**: Supports verification with the Sigstore Public Good Instance (Production), Sigstore Staging, live TUF-refreshed roots, or custom `trusted_root.json` files.
- **Identity & Issuer Policy Verification**: Validates signer Subject Alternative Name (SAN) identities and OIDC issuers.
- **Pre-computed Digest & Raw Byte Verification**: Verifies both raw artifact files and SHA-256 pre-computed digests (`sha256:...`).
- **Flexible Native Asset Modes** (following `package:icu4x` conventions):
  - `fetch` (default for package consumers): Automatically downloads precompiled native binaries from GitHub releases and verifies their SHA-256 hashes against `lib/src/hook_helpers/hashes.dart`. Precompiled binaries exist for Linux x64/arm64, macOS x64/arm64, and Windows x64 (the platforms `package:boring` ships prebuilt BoringSSL for); other targets must use `checkout`.
  - `checkout`: Builds fresh native binaries directly from the embedded Rust crate using `cargo`.
  - `local`: Links against an existing binary specified via `localPath`.

## Usage

```dart
import 'dart:io';
import 'package:sigstore/sigstore.dart';

void main() async {
  // 1. Create client instance
  final client = SigstoreClient.create();

  // 2. (Optional) Refresh trusted_root.json from Sigstore's TUF repository
  final trustedRootJson = await client.refreshTrustedRoot(
    'https://tuf-repo-cdn.sigstore.dev',
    '${Directory.systemTemp.path}/sigstore_tuf_cache',
  );

  // 3. Load bundle and artifact
  final bundleJson = await File('bundle.sigstore.json').readAsString();
  final artifactBytes = await File('artifact.tar.gz').readAsBytes();
  final bundle = SigstoreBundle.fromJson(bundleJson);

  // 4. Define verification policy
  final policy = SigstoreVerificationPolicy.create(
    'https://github.com/owner/repo/.github/workflows/release.yml@refs/heads/main', // expected identity
    'https://token.actions.githubusercontent.com',                                  // expected issuer
    true,            // offline verification
    false,           // isStaging (false = production root)
    trustedRootJson, // optional custom/TUF-refreshed trusted_root.json (or '' for embedded root)
    '',              // optional standalone public key PEM
  );

  // 5. Verify artifact
  final result = client.verify(artifactBytes, false, bundle, policy);

  if (result.isValid()) {
    print('Verified signer identity: ${result.verifiedIdentity()}');
    print('Verified OIDC issuer: ${result.verifiedIssuer()}');
  }
}
```

## Package attestations (`package:sigstore/provenance.dart`)

`package:sigstore/provenance.dart` is a pure-Dart library (no native bindings, usable on every platform) with the pieces that `pub` and `pub.dev` share to bind a verified Sigstore bundle to the package it is served for:

- `GitHubRepository` and `GitHubWorkflowIdentity` parse the repository URLs found in `pubspec.yaml` and in SLSA provenance, and the `job_workflow_ref` identities that `verifiedIdentity()` reports for bundles signed from GitHub Actions.
- `BuildProvenance.parseBundle` reads the SLSA v1 build provenance statement from the DSSE envelope of a bundle: the repository, ref and commit the build ran at, its subjects, the self-reported builder, and GitHub's immutable repository ids.
- `TransparencyLogEntry.tryParseBundle` reads the Rekor log index and integration time.
- `checkProvenancePolicy` checks a *verified* attestation against the policy: who signed (a trusted reusable workflow), what was signed (the archive digest) and where it was built (the `repository:` of the package).

Parsing never validates signatures. Verify the bundle with `SigstoreClient.verify` first, and parse the very same JSON string:

```dart
import 'package:sigstore/provenance.dart';
import 'package:sigstore/sigstore.dart';

List<String> verifyPackageAttestation({
  required String packageName,
  required String packageVersion,
  required List<int> archiveSha256, // 32 bytes
  required String bundleJson,
  required String? pubspecRepository, // `repository:` inside the archive
}) {
  final client = SigstoreClient.create();
  final policy = SigstoreVerificationPolicy.create(
    '', // any identity: the signer is checked by the provenance policy below
    githubActionsOidcIssuer,
    true,
    false,
    '',
    '',
  );
  // Throws a `SigstoreError` if the bundle does not verify over the digest.
  final result = client.verify(
    archiveSha256,
    true,
    SigstoreBundle.fromJson(bundleJson),
    policy,
  );

  final signer = GitHubWorkflowIdentity.tryParse(result.verifiedIdentity());
  if (signer == null) return ['Not signed from GitHub Actions.'];
  return checkProvenancePolicy(
    packageName: packageName,
    packageVersion: packageVersion,
    archiveSha256: archiveSha256.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    provenance: BuildProvenance.parseBundle(bundleJson),
    signer: signer,
    trustedSignerWorkflows: {'dart-lang/setup-dart/.github/workflows/publish.yml'},
    oidcIssuer: result.verifiedIssuer(),
    expectedRepository: pubspecRepository,
  );
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

> [!IMPORTANT]
> Steps 2 and 3 are not optional. Consumers use `fetch` mode by default, so a version published while `lib/src/hook_helpers/hashes.dart` still points at the previous `binaries-v*` release ships binaries that do not match its Dart bindings and fails at runtime with `Failed to lookup symbol ...`. The `Fetch Mode Tests` CI jobs run the test suite from a consumer package against the pinned binaries, so they stay red on `main` until step 3 is merged.

### 1. Update Code & Regenerate Bindings (if Rust changed)
If modifying Rust code in `rust/src/`:
```bash
dart run tool/generate_bindings.dart
dart test
./tool/run_conformance_tests.sh
```

### 2. Bump Version & Build Precompiled Binaries
1. Update `version` in `pubspec.yaml` and `rust/Cargo.toml` and document changes in `CHANGELOG.md` (e.g., `0.2.1`), then merge that into `main`.
2. Trigger the GitHub Actions binary build for `binaries-v<version>` from the merged commit:
   ```bash
   git tag binaries-v0.2.1 && git push origin binaries-v0.2.1
   ```
   *(Or trigger manually in GitHub under **Actions &rarr; Release Binaries &rarr; Run workflow** with the tag as input)*
3. Wait for the workflow to finish building across Linux, macOS, and Windows runners and attaching assets to the `binaries-v0.2.1` GitHub Release. The build fails if any of the targets in `lib/src/hook_helpers/builder.dart` is missing.

### 3. Regenerate Hashes & Open PR
1. Run the hash generator to download the newly built binaries and populate `lib/src/hook_helpers/hashes.dart` (it refuses to write a partial table):
   ```bash
   dart run tool/regenerate_hashes.dart binaries-v0.2.1
   ```
2. Commit your changes to a feature branch and open a PR:
   ```bash
   git checkout -b release-v0.2.1
   git add lib/src/hook_helpers/hashes.dart
   git commit -m "chore: prepare for 0.2.1 release"
   git push -u origin release-v0.2.1
   gh pr create --title "Release v0.2.1" --body "Prepare release 0.2.1"
   ```
3. CI will verify the checks, including downloading and testing the precompiled binaries across Linux, macOS, and Windows. The `dart-lang/ecosystem` publish bot will validate the package and comment that it is `ready to publish`.

### 4. Merge & Publish to pub.dev
1. Merge the PR into `main`.
2. Tag the release commit and push the tag:
   ```bash
   git checkout main && git pull origin main
   git tag v0.2.1
   git push origin v0.2.1
   ```
3. The `.github/workflows/publish.yaml` workflow will automatically authenticate with `pub.dev` via OIDC and publish the package.
