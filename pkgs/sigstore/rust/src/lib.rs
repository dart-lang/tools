//! Rust FFI bridge for `package:sigstore`.
//!
//! # Overview for Dart Developers
//!
//! This crate wraps the official [`sigstore-rust`](https://github.com/sigstore/sigstore-rust)
//! crates (`sigstore-verify`, `sigstore-tuf`, `sigstore-trust-root`, `sigstore-types`) and exposes
//! a C-ABI interface to Dart using [Diplomat](https://rust-diplomat.github.io/diplomat/).
//!
//! ## Key Architectural Choices
//!
//! 1. **Zero bundled C/C++ crypto (`boring_provider`)**:
//!    Instead of compiling Amazon's `aws-lc-sys` C/C++/ASM library (~2.4 MB), we disable default
//!    features (`aws-lc-rs`) on `sigstore-rust` and implement `sigstore_crypto::CryptoProvider` in
//!    [`boring_provider`]. At startup, Dart resolves 25 BoringSSL function pointers from
//!    `package:boring` (`libbssl_dart`) and passes them to [`ffi::SigstoreVerifier::init_boring`],
//!    which registers [`boring_provider`] via `sigstore_crypto::install_default_provider`.
//!
//! 2. **Zero bundled HTTP stack (Sans-IO TUF state machine)**:
//!    `sigstore-tuf` is written in `async` Rust and expects an asynchronous `Repository` trait to
//!    fetch TUF metadata (`4.root.json`, `timestamp.json`, `snapshot.json`, `targets.json`) and
//!    target files (`trusted_root.json`). Rather than bundling `reqwest` + `tokio` (~1.5 MB) into
//!    this native library, we drive `sigstore-tuf`'s `Future` as a step-by-step state machine
//!    ([`ffi::SigstoreTufUpdater`]) so Dart can perform the actual HTTP `GET` requests using
//!    `dart:io`'s `HttpClient`.
//!
//! 3. **Diplomat Code Generation (`#[diplomat::bridge]`)**:
//!    Everything inside `pub mod ffi` is analyzed by `diplomat-tool` (via
//!    `dart run tool/generate_bindings.dart`) to generate `lib/src/bindings/*.g.dart`.
//!    - `#[diplomat::opaque]` structs live on the Rust heap (`Box<T>`) and are exposed to Dart as
//!      wrapper classes holding an opaque `ffi.Pointer` with an automatic `NativeFinalizer`.
//!    - `&DiplomatStr` is a borrowed UTF-8 byte slice (`&[u8]`) passed from a Dart `String`.
//!    - `&mut DiplomatWrite` is a growable buffer owned by Diplomat that Rust writes UTF-8 output
//!      into, which Diplomat then converts into a Dart `String` on return.

pub mod boring_provider;

use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};

/// Default Sigstore production TUF repository URL.
pub const DEFAULT_TUF_URL: &str = "https://tuf-repo-cdn.sigstore.dev";

/// Sigstore staging TUF repository URL.
pub const STAGING_TUF_URL: &str = "https://tuf-repo-cdn.sigstage.dev";

/// GitHub artifact attestation TUF repository URL.
pub const GITHUB_TUF_URL: &str = "https://tuf-repo.github.com";

/// Embedded initial `root.json` (trust anchor) for the production Sigstore TUF instance.
/// `include_bytes!` embeds the file contents into the binary at compile time (like a const Uint8List).
pub const PRODUCTION_TUF_ROOT: &[u8] = include_bytes!("../repository/tuf_root.json");

/// Embedded initial `root.json` (trust anchor) for the staging Sigstore TUF instance.
pub const STAGING_TUF_ROOT: &[u8] = include_bytes!("../repository/tuf_staging_root.json");

/// Embedded initial `root.json` (trust anchor) for GitHub's artifact attestation TUF instance.
pub const GITHUB_TUF_ROOT: &[u8] = include_bytes!("../repository/tuf_github_root.json");

// ============================================================================
// TUF Coroutine Bridge (driving Rust `async`/`await` from Dart's `HttpClient`)
// ============================================================================
//
// In Rust, an `async { ... }` block compiles into a lazy state machine implementing the `Future`
// trait. Unlike Dart `Future`s (which schedule themselves on the Dart event loop immediately), a
// Rust `Future` does nothing until someone calls `.poll(...)` on it:
//
// - When the Rust `Future` reaches an `.await` on an HTTP request (`BridgeFetchFuture`), `.poll()`
//   writes the requested URL into `TufBridgeState::pending_url` and returns `Poll::Pending`, which
//   pauses the Rust state machine and returns control across FFI to Dart.
// - Dart reads the URL, performs the HTTP GET with `dart:io`'s `HttpClient`, passes the HTTP
//   status and body back via `SigstoreTufUpdater::provide_response`, and calls `poll()` again.
// - On the next `poll()`, `BridgeFetchFuture` takes `TufBridgeState::response` and returns
//   `Poll::Ready(...)`, resuming the Rust `async` block right where it paused.

/// Shared handoff slot between the paused Rust `sigstore-tuf` future and the Dart HTTP loop.
pub(crate) struct TufBridgeState {
    /// Set by Rust when `sigstore-tuf` needs Dart to fetch a URL; cleared once Dart provides a response.
    pub pending_url: Option<String>,
    /// Maximum response size in bytes permitted by the TUF specification for the current request
    /// (protects against "endless data" attacks).
    pub pending_max_length: u64,
    /// Set by Dart via `provide_response` / `provide_error` before calling `poll()` again.
    pub response: Option<sigstore_tuf::Result<Option<Vec<u8>>>>,
}

/// A single in-flight HTTP GET request awaited by `sigstore-tuf`.
struct BridgeFetchFuture {
    state: Arc<Mutex<TufBridgeState>>,
    url: String,
    max_length: u64,
    /// `false` on the first poll (when we register `pending_url` and yield to Dart),
    /// `true` on the subsequent poll (when we expect Dart to have populated `response`).
    registered: bool,
}

impl Future for BridgeFetchFuture {
    type Output = sigstore_tuf::Result<Option<Vec<u8>>>;

    fn poll(mut self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Self::Output> {
        let this = self.as_mut().get_mut();
        let mut st = this.state.lock().unwrap();

        // Step 1: First time `sigstore-tuf` awaits this HTTP request.
        // Publish the URL and byte limit to `TufBridgeState` and return `Poll::Pending` so
        // `SigstoreTufUpdater::poll` can return the URL to Dart.
        if !this.registered {
            st.pending_url = Some(this.url.clone());
            st.pending_max_length = this.max_length;
            this.registered = true;
            return Poll::Pending;
        }

        // Step 2: Dart has fetched the URL, called `provide_response` / `provide_error`, and
        // invoked `SigstoreTufUpdater::poll` again. Consume the response and resume `sigstore-tuf`.
        if let Some(res) = st.response.take() {
            if let Ok(Some(ref body)) = res {
                if body.len() as u64 > this.max_length {
                    return Poll::Ready(Err(sigstore_tuf::Error::transport(format!(
                        "{}: response exceeds max length {}",
                        this.url, this.max_length
                    ))));
                }
            }
            return Poll::Ready(res);
        }

        // If `poll()` was called again before Dart supplied a response, keep waiting.
        st.pending_url = Some(this.url.clone());
        st.pending_max_length = this.max_length;
        Poll::Pending
    }
}

/// Implementation of `sigstore_tuf::Repository` that delegates HTTP fetches to [`BridgeFetchFuture`].
struct BridgeRepository {
    base_url: String,
    state: Arc<Mutex<TufBridgeState>>,
}

impl sigstore_tuf::Repository for BridgeRepository {
    /// Called by `sigstore-tuf` to fetch metadata files (e.g. `2.root.json`, `timestamp.json`).
    fn fetch_metadata<'a>(
        &'a self,
        name: &'a str,
        max_length: u64,
    ) -> sigstore_tuf::transport::FetchFuture<'a> {
        let base = self.base_url.trim_end_matches('/');
        let rel = name.trim_start_matches('/');
        let url = format!("{base}/{rel}");
        Box::pin(BridgeFetchFuture {
            state: self.state.clone(),
            url,
            max_length,
            registered: false,
        })
    }

    /// Called by `sigstore-tuf` to fetch target files under `/targets/` (e.g. `trusted_root.json`).
    fn fetch_target<'a>(
        &'a self,
        path: &'a str,
        max_length: u64,
    ) -> sigstore_tuf::transport::FetchFuture<'a> {
        let base = self.base_url.trim_end_matches('/');
        let rel = path.trim_start_matches('/');
        let url = format!("{base}/targets/{rel}");
        Box::pin(BridgeFetchFuture {
            state: self.state.clone(),
            url,
            max_length,
            registered: false,
        })
    }
}

/// Type alias for a heap-allocated, pinned Rust `Future` that produces the verified `trusted_root.json`.
/// (`Pin<Box<...>>` is required in Rust because self-referential `async` state machines cannot move in memory once polled.)
type TufRefreshFuture = Pin<Box<dyn Future<Output = Result<String, Error>>>>;

/// Backing fields for [`ffi::SigstoreTufUpdater`].
/// Wrapped in `Mutex`es because Diplomat's `&self` methods require interior mutability (`RefCell`/`Mutex`).
pub struct TufUpdaterInner {
    pub(crate) state: Arc<Mutex<TufBridgeState>>,
    pub(crate) fut: Mutex<TufRefreshFuture>,
    pub(crate) result: Mutex<Option<String>>,
}

// ============================================================================
// Diplomat FFI Bridge (auto-generates `lib/src/bindings/*.g.dart`)
// ============================================================================

#[diplomat::bridge]
// Prefix all exported C symbols with `sigstore_` so they cannot collide with symbols in other
// native asset libraries.
#[diplomat::abi_rename = "sigstore_{0}_mv1"]
pub mod ffi {
    use diplomat_runtime::{DiplomatStr, DiplomatWrite};
    use std::fmt::Write as _;
    use std::path::PathBuf;
    use std::sync::{Arc, Mutex};
    use std::task::{Context, Poll, Waker};

    /// Errors that can occur during Sigstore bundle parsing, verification, or root refresh.
    #[diplomat::enum_convert(crate::Error)]
    pub enum SigstoreError {
        /// The bundle is structurally invalid, cannot be parsed from JSON, or contains malformed verification material.
        InvalidBundle,
        /// Cryptographic verification failed.
        ///
        /// This can happen if the signature does not match, the certificate does not chain to the trusted root,
        /// the identity or issuer does not match policy expectations, or transparency log proofs fail.
        VerificationFailed,
        /// An internal error occurred during verification or cryptographic operations.
        InternalError,
    }

    /// A Sigstore bundle containing signature material, verification material (such as X.509 certificates
    /// or public key hints), and transparency log inclusion proofs.
    #[diplomat::opaque]
    pub struct SigstoreBundle(pub sigstore_types::Bundle);

    /// Internal FFI entry point for initializing BoringSSL symbols and verifying Sigstore bundles.
    #[diplomat::opaque]
    pub struct SigstoreVerifier;

    /// State machine driving the `sigstore-tuf` verification workflow over an external HTTP client.
    #[diplomat::opaque]
    pub struct SigstoreTufUpdater(pub crate::TufUpdaterInner);

    /// The result of verifying an artifact against a Sigstore bundle and verification policy.
    #[diplomat::opaque]
    pub struct SigstoreVerificationResult {
        pub is_valid: bool,
        pub identity: String,
        pub issuer: String,
    }

    /// Policy configuration specifying expected signing identity, issuer, trusted root, and network options for verification.
    #[diplomat::opaque]
    pub struct SigstoreVerificationPolicy {
        pub expected_identity: Option<String>,
        pub expected_issuer: Option<String>,
        pub offline: bool,
        pub is_staging: bool,
        pub custom_trusted_root: Option<String>,
        pub public_key_pem: Option<String>,
    }

    // Helper: Diplomat passes empty Dart strings (`""`) for optional string parameters;
    // convert non-empty UTF-8 slices to `Some(String)` and empty slices to `None`.
    fn opt_str(s: &DiplomatStr) -> Option<String> {
        std::str::from_utf8(s)
            .ok()
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
    }

    impl SigstoreVerificationPolicy {
        /// Creates a new verification policy.
        ///
        /// - `expected_identity`: Expected certificate subject (SAN email or URI). If empty, identity is not restricted.
        /// - `expected_issuer`: Expected OIDC issuer URL (e.g. `https://token.actions.githubusercontent.com`). If empty, issuer is not restricted.
        /// - `offline`: Whether to perform verification offline without network access.
        /// - `is_staging`: Whether to verify against Sigstore's staging environment instead of production.
        /// - `trusted_root_json`: Optional custom trusted root JSON string. If empty, the default Sigstore root is used.
        /// - `public_key_pem`: Optional PEM-encoded public key for verifying bundles created with pre-shared keys.
        pub fn create(
            expected_identity: &DiplomatStr,
            expected_issuer: &DiplomatStr,
            offline: bool,
            is_staging: bool,
            trusted_root_json: &DiplomatStr,
            public_key_pem: &DiplomatStr,
        ) -> Result<Box<SigstoreVerificationPolicy>, SigstoreError> {
            Ok(Box::new(SigstoreVerificationPolicy {
                expected_identity: opt_str(expected_identity),
                expected_issuer: opt_str(expected_issuer),
                offline,
                is_staging,
                custom_trusted_root: opt_str(trusted_root_json),
                public_key_pem: opt_str(public_key_pem),
            }))
        }
    }

    impl SigstoreBundle {
        // Extracts the leaf X.509 signing certificate from the bundle (handles both v0.1/v0.2
        // certificate chains and v0.3 single-certificate formats) and parses its Subject
        // Alternative Name (identity) and Fulcio OIDC issuer extension.
        fn cert_info(&self) -> Result<sigstore_verify::crypto::CertificateInfo, SigstoreError> {
            let cert_der = match &self.0.verification_material.content {
                sigstore_types::bundle::VerificationMaterialContent::X509CertificateChain {
                    certificates,
                } => certificates.first().map(|c| &c.raw_bytes),
                sigstore_types::bundle::VerificationMaterialContent::Certificate(cert) => {
                    Some(&cert.raw_bytes)
                }
                _ => None,
            };
            let der = cert_der.ok_or(SigstoreError::InvalidBundle)?;
            sigstore_verify::crypto::parse_certificate_info(der)
                .map_err(|_| SigstoreError::InvalidBundle)
        }

        /// Parses a Sigstore bundle from a JSON string.
        pub fn from_json(json: &DiplomatStr) -> Result<Box<SigstoreBundle>, SigstoreError> {
            let json_str = std::str::from_utf8(json).map_err(|_| SigstoreError::InvalidBundle)?;
            let bundle: sigstore_types::Bundle =
                serde_json::from_str(json_str).map_err(|_| SigstoreError::InvalidBundle)?;
            Ok(Box::new(SigstoreBundle(bundle)))
        }

        /// Serializes the Sigstore bundle to a JSON string.
        pub fn to_json(&self, write: &mut DiplomatWrite) -> Result<(), SigstoreError> {
            let json = serde_json::to_string(&self.0).map_err(|_| SigstoreError::InternalError)?;
            write!(write, "{}", json).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }

        /// Returns the certificate subject (subject alternative name email or URI) from the signing certificate.
        pub fn get_certificate_subject(
            &self,
            write: &mut DiplomatWrite,
        ) -> Result<(), SigstoreError> {
            let info = self.cert_info()?;
            let subject = info
                .identity
                .as_ref()
                .map(|s| s.as_str())
                .unwrap_or_default();
            write!(write, "{}", subject).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }

        /// Returns the OIDC issuer URL from the signing certificate extensions.
        pub fn get_certificate_issuer(
            &self,
            write: &mut DiplomatWrite,
        ) -> Result<(), SigstoreError> {
            let info = self.cert_info()?;
            let issuer = info.issuer.unwrap_or_default();
            write!(write, "{}", issuer).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }

        /// Returns the Rekor transparency log index if present, or `-1` if no log entry is present.
        pub fn get_rekor_log_index(&self) -> i64 {
            self.0
                .verification_material
                .tlog_entries
                .first()
                .map_or(-1, |e| u64::from(e.log_index) as i64)
        }
    }

    impl SigstoreVerifier {
        /// Initializes the BoringSSL function pointer table from `package:boring` (`libbssl_dart`).
        ///
        /// `symbol_addrs` must contain the exact 25 function pointers defined by `BoringSymbols`.
        pub fn init_boring(symbol_addrs: &[usize]) -> Result<(), SigstoreError> {
            // `symbol_addrs` comes from `Native.addressOf(...)` in `lib/src/boring_init.dart`.
            // Once registered, `sigstore-crypto` routes all cryptographic operations through
            // `boring_provider` using these BoringSSL C function pointers.
            unsafe {
                crate::boring_provider::init_boring_provider(symbol_addrs)
                    .map_err(|_| SigstoreError::InternalError)
            }
        }

        /// Verifies an artifact against a Sigstore bundle and verification policy.
        ///
        /// - `artifact_bytes`: Raw artifact bytes, or precomputed SHA-256 digest bytes if `is_digest` is true.
        /// - `is_digest`: Set to `true` if `artifact_bytes` contains the precomputed SHA-256 digest (32 bytes).
        /// - `bundle`: The parsed bundle containing signatures and verification material.
        /// - `policy`: The verification policy specifying expected identity, issuer, and trusted root.
        pub fn verify(
            artifact_bytes: &[u8],
            is_digest: bool,
            bundle: &SigstoreBundle,
            policy: &SigstoreVerificationPolicy,
        ) -> Result<Box<SigstoreVerificationResult>, SigstoreError> {
            // 1. Select the TrustedRoot (Fulcio CAs, Rekor log keys, CTFE keys, TSA CAs):
            //    either a custom JSON passed in the policy, or the embedded Sigstore staging /
            //    production root.
            let trusted_root = if let Some(ref custom_json) = policy.custom_trusted_root {
                sigstore_trust_root::TrustedRoot::from_json(custom_json)
                    .map_err(|_| SigstoreError::InvalidBundle)?
            } else if policy.is_staging {
                sigstore_trust_root::TrustedRoot::from_json(
                    sigstore_trust_root::SIGSTORE_STAGING_TRUSTED_ROOT,
                )
                .map_err(|_| SigstoreError::InternalError)?
            } else {
                sigstore_trust_root::TrustedRoot::from_json(
                    sigstore_trust_root::SIGSTORE_PRODUCTION_TRUSTED_ROOT,
                )
                .map_err(|_| SigstoreError::InternalError)?
            };

            // 2. Wrap the input bytes either as a pre-hashed 32-byte SHA-256 digest or raw bytes.
            let artifact = if is_digest {
                let hash = sigstore_types::Sha256Hash::try_from(artifact_bytes)
                    .map_err(|_| SigstoreError::VerificationFailed)?;
                sigstore_types::Artifact::from_digest(hash)
            } else {
                sigstore_types::Artifact::from_blob(artifact_bytes)
            };

            // 3. Perform full Sigstore verification:
            //    - If `public_key_pem` is provided, verify against that static key + Rekor/TSA proofs.
            //    - Otherwise, verify the Fulcio X.509 certificate chain, SCT, Rekor inclusion proof
            //      and checkpoint, RFC 3161 timestamps, OIDC identity/issuer, and artifact signature.
            let res = if let Some(ref key_pem) = policy.public_key_pem {
                let public_key = sigstore_types::DerPublicKey::from_pem(key_pem)
                    .map_err(|_| SigstoreError::VerificationFailed)?;
                let v_policy = sigstore_verify::PublicKeyVerificationPolicy::new(public_key);
                sigstore_verify::verify(artifact, &bundle.0, &v_policy, &trusted_root)
            } else {
                let mut v_policy = sigstore_verify::VerificationPolicy::any_identity();
                if let Some(ref id) = policy.expected_identity {
                    v_policy = v_policy.require_identity(id.clone());
                }
                if let Some(ref iss) = policy.expected_issuer {
                    v_policy = v_policy.require_issuer(iss.clone());
                }

                sigstore_verify::verify(artifact, &bundle.0, &v_policy, &trusted_root)
            }
            .map_err(|_| SigstoreError::VerificationFailed)?;

            Ok(Box::new(SigstoreVerificationResult {
                is_valid: true,
                identity: res
                    .identity()
                    .map(|s| s.as_str().to_string())
                    .unwrap_or_default(),
                issuer: res.issuer().unwrap_or_default().to_string(),
            }))
        }
    }

    impl SigstoreTufUpdater {
        /// Creates a new TUF refresh state machine for `tuf_mirror_url` and `cache_dir`.
        pub fn create(
            tuf_mirror_url: &DiplomatStr,
            cache_dir: &DiplomatStr,
        ) -> Result<Box<SigstoreTufUpdater>, SigstoreError> {
            let mirror_str =
                std::str::from_utf8(tuf_mirror_url).map_err(|_| SigstoreError::InternalError)?;
            let cache_str =
                std::str::from_utf8(cache_dir).map_err(|_| SigstoreError::InternalError)?;

            let base_url = if mirror_str.is_empty() {
                crate::DEFAULT_TUF_URL.to_string()
            } else {
                mirror_str.to_string()
            };
            let normalized_url = base_url.trim_end_matches('/');

            if !normalized_url.starts_with("http://") && !normalized_url.starts_with("https://") {
                return Err(SigstoreError::VerificationFailed);
            }

            // Choose the initial TUF `root.json` trust anchor to bootstrap root rotation:
            // known Sigstore mirrors use their embedded `1.root.json`, while custom mirrors
            // check `cache_dir/root.json` first and fall back to the production root.
            let root_bytes: Vec<u8> = if normalized_url == crate::DEFAULT_TUF_URL {
                crate::PRODUCTION_TUF_ROOT.to_vec()
            } else if normalized_url == crate::STAGING_TUF_URL {
                crate::STAGING_TUF_ROOT.to_vec()
            } else if normalized_url == crate::GITHUB_TUF_URL {
                crate::GITHUB_TUF_ROOT.to_vec()
            } else if !cache_str.is_empty() {
                let cached_root = PathBuf::from(cache_str).join("root.json");
                std::fs::read(&cached_root).unwrap_or_else(|_| crate::PRODUCTION_TUF_ROOT.to_vec())
            } else {
                crate::PRODUCTION_TUF_ROOT.to_vec()
            };

            let state = Arc::new(Mutex::new(crate::TufBridgeState {
                pending_url: None,
                pending_max_length: 0,
                response: None,
            }));

            let repo = crate::BridgeRepository {
                base_url,
                state: state.clone(),
            };

            let mut updater = sigstore_tuf::Updater::new(repo, &root_bytes)
                .map_err(|_| SigstoreError::VerificationFailed)?;

            // If a local cache directory was provided, persist verified TUF metadata and targets
            // on disk via `sigstore_tuf::FileStore`.
            if !cache_str.is_empty() {
                let cache_path = PathBuf::from(cache_str);
                std::fs::create_dir_all(&cache_path)
                    .map_err(|_| SigstoreError::VerificationFailed)?;
                updater = updater.with_store(sigstore_tuf::FileStore::new(cache_path));
            }

            // Construct the lazy `async` state machine that will be stepped by `poll()`.
            // Nothing inside this `async move { ... }` block executes until `poll()` is called.
            let fut = Box::pin(async move {
                let now = jiff::Timestamp::now();
                // 1. Perform the standard TUF metadata update workflow:
                //    root rotation (`N.root.json` -> `N+1.root.json` until 404),
                //    `timestamp.json`, `snapshot.json`, and `targets.json`.
                updater
                    .refresh(now)
                    .await
                    .map_err(|_| crate::Error::VerificationFailed)?;
                // 2. Fetch and verify the SHA-256/SHA-512 hash and length of `trusted_root.json`
                //    against the verified `targets.json` metadata.
                let target_bytes = updater
                    .get_target("trusted_root.json", now)
                    .await
                    .map_err(|_| crate::Error::VerificationFailed)?;
                let target_str = std::str::from_utf8(&target_bytes)
                    .map_err(|_| crate::Error::VerificationFailed)?;
                // 3. Validate that the downloaded target parses as a well-formed Sigstore TrustedRoot.
                let trusted_root = sigstore_trust_root::TrustedRoot::from_json(target_str)
                    .map_err(|_| crate::Error::VerificationFailed)?;
                serde_json::to_string(&trusted_root).map_err(|_| crate::Error::InternalError)
            });

            Ok(Box::new(SigstoreTufUpdater(crate::TufUpdaterInner {
                state,
                fut: Mutex::new(fut),
                result: Mutex::new(None),
            })))
        }

        /// Advances the TUF state machine until it either completes (writing an empty string)
        /// or requests an HTTP GET (writing the pending URL to `write`).
        pub fn poll(&self, write: &mut DiplomatWrite) -> Result<(), SigstoreError> {
            // We use `Waker::noop()` because Dart drives the polling loop explicitly:
            // whenever `poll` returns a non-empty URL, Dart performs the HTTP GET and then
            // calls `provide_response` + `poll` again.
            let waker = Waker::noop();
            let mut cx = Context::from_waker(waker);
            let mut fut = self.0.fut.lock().unwrap();
            match fut.as_mut().poll(&mut cx) {
                Poll::Ready(Ok(trusted_root_json)) => {
                    // The TUF workflow finished! Store the verified JSON so Dart can retrieve it
                    // via `take_result()`, and leave `write` empty (`""`) to signal completion.
                    *self.0.result.lock().unwrap() = Some(trusted_root_json);
                    Ok(())
                }
                Poll::Ready(Err(e)) => Err(e.into()),
                Poll::Pending => {
                    // The future paused on `BridgeFetchFuture`: write the URL it needs Dart to
                    // fetch into `write`.
                    let st = self.0.state.lock().unwrap();
                    let url = st
                        .pending_url
                        .as_deref()
                        .ok_or(SigstoreError::InternalError)?;
                    write!(write, "{}", url).map_err(|_| SigstoreError::InternalError)?;
                    Ok(())
                }
            }
        }

        /// Returns the maximum allowed response size in bytes for the currently pending HTTP GET.
        pub fn max_response_bytes(&self) -> usize {
            self.0.state.lock().unwrap().pending_max_length as usize
        }

        /// Supplies the HTTP status code and response body for the currently pending HTTP GET.
        pub fn provide_response(&self, status_code: u16, body: &[u8]) {
            let mut st = self.0.state.lock().unwrap();
            st.pending_url = None;
            // In the TUF specification, HTTP 403/404 during root rotation (`N+1.root.json`) is the
            // normal signal that we have reached the latest root version (`Ok(None)`).
            st.response = Some(match status_code {
                200..=299 => Ok(Some(body.to_vec())),
                403 | 404 => Ok(None),
                _ => Err(sigstore_tuf::Error::transport(format!(
                    "HTTP status {status_code}"
                ))),
            });
        }

        /// Supplies a transport error for the currently pending HTTP GET.
        pub fn provide_error(&self, message: &DiplomatStr) {
            let msg = std::str::from_utf8(message).unwrap_or("HTTP transport error");
            let mut st = self.0.state.lock().unwrap();
            st.pending_url = None;
            st.response = Some(Err(sigstore_tuf::Error::transport(msg.to_string())));
        }

        /// Writes the verified `trusted_root.json` string after `poll` returns `true`.
        pub fn take_result(&self, write: &mut DiplomatWrite) -> Result<(), SigstoreError> {
            let res_guard = self.0.result.lock().unwrap();
            let res = res_guard.as_deref().ok_or(SigstoreError::InternalError)?;
            write!(write, "{}", res).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }
    }

    impl SigstoreVerificationResult {
        /// Returns `true` if the artifact signature and verification materials are valid.
        pub fn is_valid(&self) -> bool {
            self.is_valid
        }

        /// Returns the verified signing identity (subject alternative name email or URI) from the certificate.
        pub fn verified_identity(&self, write: &mut DiplomatWrite) -> Result<(), SigstoreError> {
            write!(write, "{}", self.identity).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }

        /// Returns the verified OIDC issuer URL from the signing certificate extensions.
        pub fn verified_issuer(&self, write: &mut DiplomatWrite) -> Result<(), SigstoreError> {
            write!(write, "{}", self.issuer).map_err(|_| SigstoreError::InternalError)?;
            Ok(())
        }
    }
}

/// Internal Rust error type converted to [`ffi::SigstoreError`] across the Diplomat FFI boundary
/// via `#[diplomat::enum_convert(crate::Error)]`.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("Invalid bundle")]
    InvalidBundle,
    #[error("Verification failed")]
    VerificationFailed,
    #[error("Internal error")]
    InternalError,
}
