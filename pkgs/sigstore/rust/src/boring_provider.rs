//! [`sigstore_crypto::CryptoProvider`] implementation backed by `package:boring` (`libbssl_dart`).
//!
//! # Overview for Dart Developers
//!
//! Since `sigstore-rust` 0.15.0 ([`sigstore/sigstore-rust#326`](https://github.com/sigstore/sigstore-rust/pull/326)),
//! `sigstore-crypto` exposes a first-class [`CryptoProvider`] trait (`hash`, `verify_raw`,
//! `verify_prehashed`) and an optional `aws-lc-rs` Cargo feature.
//!
//! By disabling default features on `sigstore-crypto`, `sigstore-verify`, `sigstore-trust-root`,
//! and `sigstore-tuf` in `Cargo.toml`, `aws-lc-rs` (and `aws-lc-sys`) are completely omitted from
//! the dependency graph without needing `[patch.crates-io]`.
//!
//! At startup, Dart resolves 25 BoringSSL function pointers from `package:boring` (`libbssl_dart`)
//! in `lib/src/boring_init.dart` and passes them to `SigstoreVerifier.initBoring(...)`, which calls
//! [`init_boring_provider`] to populate [`BORING_SYMBOLS`] and register [`BORING_PROVIDER`] via
//! [`sigstore_crypto::install_default_provider`].

#![allow(non_camel_case_types, non_snake_case)]

use sigstore_crypto::{CryptoProvider, Error, HashContext, Result, SigningScheme};
use sigstore_types::HashAlgorithm;
use std::ffi::{c_int, c_uint, c_void};
use std::ptr;
use std::sync::OnceLock;

/// Opaque C struct types representing BoringSSL pointers (`EVP_MD*`, `EVP_PKEY*`, etc.).
/// Equivalent to `final class EVP_MD extends Opaque {}` in `dart:ffi`.
mod ffi_types {
    use std::ffi::c_void;

    #[repr(C)]
    pub struct EVP_MD(c_void);
    #[repr(C)]
    pub struct EVP_MD_CTX(c_void);
    #[repr(C)]
    pub struct EVP_PKEY(c_void);
    #[repr(C)]
    pub struct EVP_PKEY_CTX(c_void);
    #[repr(C)]
    pub struct EVP_PKEY_ALG(c_void);
}

use ffi_types::*;

// BoringSSL `<openssl/rsa.h>` padding constants.
const RSA_PKCS1_PADDING: c_int = 1;
const RSA_PKCS1_PSS_PADDING: c_int = 6;
const RSA_PSS_SALTLEN_DIGEST: c_int = -1;

// Pre-encoded ASN.1 DER `AlgorithmIdentifier` headers used by `wrap_spki` to wrap the
// `subjectPublicKey` bit-string bytes passed by `sigstore-crypto` into a full X.509
// `SubjectPublicKeyInfo` (SPKI) DER structure for `EVP_PKEY_from_subject_public_key_info`:
// - `id-ecPublicKey` (1.2.840.10045.2.1) + `prime256v1` (1.2.840.10045.3.1.7)
const ALG_ID_EC_P256: &[u8] = &[
    0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48,
    0xce, 0x3d, 0x03, 0x01, 0x07,
];
// - `id-ecPublicKey` (1.2.840.10045.2.1) + `secp384r1` (1.3.132.0.34)
const ALG_ID_EC_P384: &[u8] = &[
    0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04,
    0x00, 0x22,
];
// - `rsaEncryption` (1.2.840.113549.1.1.1) + NULL parameters
const ALG_ID_RSA_ENCRYPTION: &[u8] = &[
    0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
];

/// Exact number of BoringSSL C function pointers in [`BoringSymbols`].
/// Must stay in sync with `_boringSymbolAddresses()` in `lib/src/boring_init.dart`.
pub const BORING_SYMBOL_COUNT: usize = 25;

/// Function pointer table populated from `package:boring` at startup.
///
/// **Important:** The field order here MUST exactly match the list order in
/// `_boringSymbolAddresses()` in `lib/src/boring_init.dart`.
#[repr(C)]
#[derive(Copy, Clone)]
pub struct BoringSymbols {
    // Error queue cleanup (called after failed verifications so thread-local error state doesn't leak)
    pub ERR_clear_error: unsafe extern "C" fn(),

    // Hash algorithm descriptors (SHA-256, SHA-384, SHA-512)
    pub EVP_sha256: unsafe extern "C" fn() -> *const EVP_MD,
    pub EVP_sha384: unsafe extern "C" fn() -> *const EVP_MD,
    pub EVP_sha512: unsafe extern "C" fn() -> *const EVP_MD,

    // Streaming message digest (`EVP_MD_CTX`) lifecycle and one-shot message verification
    pub EVP_MD_CTX_new: unsafe extern "C" fn() -> *mut EVP_MD_CTX,
    pub EVP_MD_CTX_free: unsafe extern "C" fn(*mut EVP_MD_CTX),
    pub EVP_DigestInit_ex:
        unsafe extern "C" fn(*mut EVP_MD_CTX, *const EVP_MD, *mut c_void) -> c_int,
    pub EVP_DigestUpdate: unsafe extern "C" fn(*mut EVP_MD_CTX, *const c_void, usize) -> c_int,
    pub EVP_DigestFinal_ex: unsafe extern "C" fn(*mut EVP_MD_CTX, *mut u8, *mut c_uint) -> c_int,
    pub EVP_DigestVerifyInit: unsafe extern "C" fn(
        *mut EVP_MD_CTX,
        *mut *mut EVP_PKEY_CTX,
        *const EVP_MD,
        *mut c_void,
        *mut EVP_PKEY,
    ) -> c_int,
    pub EVP_DigestVerify:
        unsafe extern "C" fn(*mut EVP_MD_CTX, *const u8, usize, *const u8, usize) -> c_int,

    // Public key (`EVP_PKEY`) lifecycle
    pub EVP_PKEY_free: unsafe extern "C" fn(*mut EVP_PKEY),

    // Pre-hashed digest signature verification (`EVP_PKEY_CTX`) and RSA padding configuration
    pub EVP_PKEY_CTX_new: unsafe extern "C" fn(*mut EVP_PKEY, *mut c_void) -> *mut EVP_PKEY_CTX,
    pub EVP_PKEY_CTX_free: unsafe extern "C" fn(*mut EVP_PKEY_CTX),
    pub EVP_PKEY_verify_init: unsafe extern "C" fn(*mut EVP_PKEY_CTX) -> c_int,
    pub EVP_PKEY_verify:
        unsafe extern "C" fn(*mut EVP_PKEY_CTX, *const u8, usize, *const u8, usize) -> c_int,
    pub EVP_PKEY_CTX_set_rsa_padding: unsafe extern "C" fn(*mut EVP_PKEY_CTX, c_int) -> c_int,
    pub EVP_PKEY_CTX_set_rsa_pss_saltlen: unsafe extern "C" fn(*mut EVP_PKEY_CTX, c_int) -> c_int,
    pub EVP_PKEY_CTX_set_signature_md:
        unsafe extern "C" fn(*mut EVP_PKEY_CTX, *const EVP_MD) -> c_int,

    // Modern BoringSSL key algorithm descriptors for parsing SPKI and raw public keys
    pub EVP_pkey_ec_p256: unsafe extern "C" fn() -> *const EVP_PKEY_ALG,
    pub EVP_pkey_ec_p384: unsafe extern "C" fn() -> *const EVP_PKEY_ALG,
    pub EVP_pkey_ed25519: unsafe extern "C" fn() -> *const EVP_PKEY_ALG,
    pub EVP_pkey_rsa: unsafe extern "C" fn() -> *const EVP_PKEY_ALG,

    // Public key parsers (Ed25519 raw 32-byte key and X.509 SubjectPublicKeyInfo DER)
    pub EVP_PKEY_from_raw_public_key:
        unsafe extern "C" fn(*const EVP_PKEY_ALG, *const u8, usize) -> *mut EVP_PKEY,
    pub EVP_PKEY_from_subject_public_key_info:
        unsafe extern "C" fn(*const u8, usize, *const *const EVP_PKEY_ALG, usize) -> *mut EVP_PKEY,
}

static BORING_SYMBOLS: OnceLock<BoringSymbols> = OnceLock::new();
static BORING_PROVIDER: BoringCryptoProvider = BoringCryptoProvider;

/// Initializes the BoringSSL function pointer table from `addrs` and installs
/// [`BORING_PROVIDER`] as `sigstore-crypto`'s global default [`CryptoProvider`].
///
/// # Safety
/// Every element in `addrs` must be a valid non-null function pointer matching the
/// exact layout and calling convention of [`BoringSymbols`].
pub unsafe fn init_boring_provider(addrs: &[usize]) -> std::result::Result<(), &'static str> {
    if addrs.len() != BORING_SYMBOL_COUNT {
        return Err("invalid BoringSSL symbol table length");
    }
    if addrs.contains(&0) {
        return Err("null function pointer in BoringSSL symbol table");
    }
    let ptrs: [usize; BORING_SYMBOL_COUNT] = addrs
        .try_into()
        .map_err(|_| "invalid BoringSSL symbol table length")?;
    let syms: BoringSymbols = unsafe { std::mem::transmute(ptrs) };
    let _ = BORING_SYMBOLS.set(syms);
    let _ = sigstore_crypto::install_default_provider(&BORING_PROVIDER);
    Ok(())
}

#[inline]
fn bssl() -> &'static BoringSymbols {
    BORING_SYMBOLS.get().expect(
        "package:boring symbols not initialized! Call SigstoreClient.create() or ensureBoringInitialized() before using sigstore.",
    )
}

#[inline]
fn clear_error() {
    if let Some(s) = BORING_SYMBOLS.get() {
        unsafe { (s.ERR_clear_error)() };
    }
}

/// RAII wrapper around a BoringSSL `*mut EVP_PKEY` that calls `EVP_PKEY_free` on drop.
struct EvpPkey(*mut EVP_PKEY);

impl EvpPkey {
    #[inline]
    fn from_ptr(ptr: *mut EVP_PKEY, scheme: SigningScheme) -> Result<Self> {
        if ptr.is_null() {
            clear_error();
            Err(Error::Verification(format!(
                "{} public key rejected by BoringSSL",
                scheme.name()
            )))
        } else {
            Ok(Self(ptr))
        }
    }

    #[inline]
    fn as_ptr(&self) -> *mut EVP_PKEY {
        self.0
    }
}

impl Drop for EvpPkey {
    fn drop(&mut self) {
        if !self.0.is_null() {
            let s = bssl();
            unsafe { (s.EVP_PKEY_free)(self.0) };
        }
    }
}

/// Streaming hash context wrapping a BoringSSL `*mut EVP_MD_CTX`.
struct BoringHashContext {
    ctx: *mut EVP_MD_CTX,
    output_len: usize,
}

unsafe impl Send for BoringHashContext {}

impl BoringHashContext {
    fn new(algorithm: HashAlgorithm) -> Result<Self> {
        let s = bssl();
        let (md, output_len) = unsafe {
            match algorithm {
                HashAlgorithm::Sha2256 => ((s.EVP_sha256)(), 32),
                HashAlgorithm::Sha2384 => ((s.EVP_sha384)(), 48),
                HashAlgorithm::Sha2512 => ((s.EVP_sha512)(), 64),
                _ => {
                    return Err(Error::UnsupportedAlgorithm(format!(
                        "cannot compute {algorithm} digests"
                    )))
                }
            }
        };
        unsafe {
            let ctx = (s.EVP_MD_CTX_new)();
            assert!(!ctx.is_null(), "EVP_MD_CTX_new failed");
            let rc = (s.EVP_DigestInit_ex)(ctx, md, ptr::null_mut());
            assert_eq!(rc, 1, "EVP_DigestInit_ex failed");
            Ok(Self { ctx, output_len })
        }
    }
}

impl HashContext for BoringHashContext {
    fn update(&mut self, data: &[u8]) {
        if data.is_empty() {
            return;
        }
        let s = bssl();
        unsafe {
            let rc = (s.EVP_DigestUpdate)(self.ctx, data.as_ptr() as *const c_void, data.len());
            assert_eq!(rc, 1, "EVP_DigestUpdate failed");
        }
    }

    fn finalize(self: Box<Self>) -> Vec<u8> {
        let s = bssl();
        let mut out = vec![0u8; self.output_len];
        let mut out_len: c_uint = 0;
        unsafe {
            let rc = (s.EVP_DigestFinal_ex)(self.ctx, out.as_mut_ptr(), &mut out_len);
            assert_eq!(rc, 1, "EVP_DigestFinal_ex failed");
            assert_eq!(out_len as usize, self.output_len);
        }
        out
    }
}

impl Drop for BoringHashContext {
    fn drop(&mut self) {
        if !self.ctx.is_null() {
            let s = bssl();
            unsafe { (s.EVP_MD_CTX_free)(self.ctx) };
        }
    }
}

/// Wraps an ASN.1 `AlgorithmIdentifier` DER slice and raw public key bytes into a DER
/// `SubjectPublicKeyInfo` (`SEQUENCE { AlgorithmIdentifier, BIT STRING }`).
fn wrap_spki(alg_id_der: &[u8], pub_key_bytes: &[u8]) -> Vec<u8> {
    let bit_string_content_len = 1 + pub_key_bytes.len();
    let mut bit_string = Vec::with_capacity(4 + bit_string_content_len);
    bit_string.push(0x03); // ASN.1 tag: BIT STRING
    encode_der_length(&mut bit_string, bit_string_content_len);
    bit_string.push(0x00); // 0 unused bits in final byte
    bit_string.extend_from_slice(pub_key_bytes);

    let seq_len = alg_id_der.len() + bit_string.len();
    let mut spki = Vec::with_capacity(4 + seq_len);
    spki.push(0x30); // ASN.1 tag: SEQUENCE
    encode_der_length(&mut spki, seq_len);
    spki.extend_from_slice(alg_id_der);
    spki.extend_from_slice(&bit_string);
    spki
}

fn encode_der_length(out: &mut Vec<u8>, len: usize) {
    if len < 0x80 {
        out.push(len as u8);
    } else if len <= 0xff {
        out.push(0x81);
        out.push(len as u8);
    } else {
        out.push(0x82);
        out.push((len >> 8) as u8);
        out.push((len & 0xff) as u8);
    }
}

/// Parses `spki_pubkey_bytes` (the raw `subjectPublicKey` bit-string content validated by
/// `sigstore_crypto::validate_raw_public_key`) into a BoringSSL [`EvpPkey`].
fn parse_public_key(scheme: SigningScheme, spki_pubkey_bytes: &[u8]) -> Result<EvpPkey> {
    let s = bssl();
    match scheme {
        SigningScheme::EcdsaP256Sha256 | SigningScheme::EcdsaP256Sha384 => {
            let spki = wrap_spki(ALG_ID_EC_P256, spki_pubkey_bytes);
            let algs = unsafe { [(s.EVP_pkey_ec_p256)()] };
            let ptr = unsafe {
                (s.EVP_PKEY_from_subject_public_key_info)(
                    spki.as_ptr(),
                    spki.len(),
                    algs.as_ptr(),
                    algs.len(),
                )
            };
            EvpPkey::from_ptr(ptr, scheme)
        }
        SigningScheme::EcdsaP384Sha256 | SigningScheme::EcdsaP384Sha384 => {
            let spki = wrap_spki(ALG_ID_EC_P384, spki_pubkey_bytes);
            let algs = unsafe { [(s.EVP_pkey_ec_p384)()] };
            let ptr = unsafe {
                (s.EVP_PKEY_from_subject_public_key_info)(
                    spki.as_ptr(),
                    spki.len(),
                    algs.as_ptr(),
                    algs.len(),
                )
            };
            EvpPkey::from_ptr(ptr, scheme)
        }
        SigningScheme::Ed25519 => {
            let alg = unsafe { (s.EVP_pkey_ed25519)() };
            let ptr = unsafe {
                (s.EVP_PKEY_from_raw_public_key)(
                    alg,
                    spki_pubkey_bytes.as_ptr(),
                    spki_pubkey_bytes.len(),
                )
            };
            EvpPkey::from_ptr(ptr, scheme)
        }
        SigningScheme::RsaPkcs1Sha256
        | SigningScheme::RsaPkcs1Sha384
        | SigningScheme::RsaPkcs1Sha512
        | SigningScheme::RsaPssSha256
        | SigningScheme::RsaPssSha384
        | SigningScheme::RsaPssSha512 => {
            let spki = wrap_spki(ALG_ID_RSA_ENCRYPTION, spki_pubkey_bytes);
            let algs = unsafe { [(s.EVP_pkey_rsa)()] };
            let ptr = unsafe {
                (s.EVP_PKEY_from_subject_public_key_info)(
                    spki.as_ptr(),
                    spki.len(),
                    algs.as_ptr(),
                    algs.len(),
                )
            };
            EvpPkey::from_ptr(ptr, scheme)
        }
        other => Err(Error::UnsupportedAlgorithm(format!(
            "unsupported verification scheme: {other:?}"
        ))),
    }
}

/// Returns the BoringSSL `const EVP_MD*` pointer for `scheme`'s hash algorithm, or `ptr::null()`
/// for PureEdDSA (`Ed25519`).
fn scheme_evp_md(scheme: SigningScheme) -> Result<*const EVP_MD> {
    let s = bssl();
    unsafe {
        match scheme {
            SigningScheme::Ed25519 => Ok(ptr::null()),
            SigningScheme::EcdsaP256Sha256
            | SigningScheme::EcdsaP384Sha256
            | SigningScheme::RsaPkcs1Sha256
            | SigningScheme::RsaPssSha256 => Ok((s.EVP_sha256)()),
            SigningScheme::EcdsaP256Sha384
            | SigningScheme::EcdsaP384Sha384
            | SigningScheme::RsaPkcs1Sha384
            | SigningScheme::RsaPssSha384 => Ok((s.EVP_sha384)()),
            SigningScheme::RsaPkcs1Sha512 | SigningScheme::RsaPssSha512 => Ok((s.EVP_sha512)()),
            other => Err(Error::UnsupportedAlgorithm(format!(
                "unsupported verification scheme: {other:?}"
            ))),
        }
    }
}

/// Configures RSA padding (PKCS#1 v1.5 or PSS with digest-length salt) on `pctx` when `scheme` is
/// an RSA scheme; no-op for ECDSA and Ed25519.
unsafe fn configure_rsa_padding(scheme: SigningScheme, pctx: *mut EVP_PKEY_CTX) -> bool {
    let s = bssl();
    match scheme {
        SigningScheme::RsaPkcs1Sha256
        | SigningScheme::RsaPkcs1Sha384
        | SigningScheme::RsaPkcs1Sha512 => unsafe {
            (s.EVP_PKEY_CTX_set_rsa_padding)(pctx, RSA_PKCS1_PADDING) == 1
        },
        SigningScheme::RsaPssSha256 | SigningScheme::RsaPssSha384 | SigningScheme::RsaPssSha512 => unsafe {
            (s.EVP_PKEY_CTX_set_rsa_padding)(pctx, RSA_PKCS1_PSS_PADDING) == 1
                && (s.EVP_PKEY_CTX_set_rsa_pss_saltlen)(pctx, RSA_PSS_SALTLEN_DIGEST) == 1
        },
        _ => true,
    }
}

#[derive(Debug)]
struct BoringCryptoProvider;

impl CryptoProvider for BoringCryptoProvider {
    fn hash(&self, algorithm: HashAlgorithm) -> Result<Box<dyn HashContext>> {
        Ok(Box::new(BoringHashContext::new(algorithm)?))
    }

    fn verify_raw(
        &self,
        scheme: SigningScheme,
        spki_pubkey_bytes: &[u8],
        data: &[u8],
        signature: &[u8],
    ) -> Result<()> {
        let pkey = parse_public_key(scheme, spki_pubkey_bytes)?;
        let md = scheme_evp_md(scheme)?;
        let s = bssl();
        unsafe {
            let mctx = (s.EVP_MD_CTX_new)();
            if mctx.is_null() {
                clear_error();
                return Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )));
            }
            let mut pctx: *mut EVP_PKEY_CTX = ptr::null_mut();
            let init_rc =
                (s.EVP_DigestVerifyInit)(mctx, &mut pctx, md, ptr::null_mut(), pkey.as_ptr());
            if init_rc != 1 || !configure_rsa_padding(scheme, pctx) {
                (s.EVP_MD_CTX_free)(mctx);
                clear_error();
                return Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )));
            }
            let rc = (s.EVP_DigestVerify)(
                mctx,
                signature.as_ptr(),
                signature.len(),
                data.as_ptr(),
                data.len(),
            );
            (s.EVP_MD_CTX_free)(mctx);
            if rc == 1 {
                Ok(())
            } else {
                clear_error();
                Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )))
            }
        }
    }

    fn verify_prehashed(
        &self,
        scheme: SigningScheme,
        spki_pubkey_bytes: &[u8],
        digest: &[u8],
        signature: &[u8],
    ) -> Result<()> {
        if !scheme.supports_prehashed() {
            return Err(Error::UnsupportedAlgorithm(format!(
                "Scheme {scheme:?} does not support prehashed mode"
            )));
        }
        let pkey = parse_public_key(scheme, spki_pubkey_bytes)?;
        let md = scheme_evp_md(scheme)?;
        let s = bssl();
        unsafe {
            let pctx = (s.EVP_PKEY_CTX_new)(pkey.as_ptr(), ptr::null_mut());
            if pctx.is_null() {
                clear_error();
                return Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )));
            }
            if (s.EVP_PKEY_verify_init)(pctx) != 1
                || (s.EVP_PKEY_CTX_set_signature_md)(pctx, md) != 1
                || !configure_rsa_padding(scheme, pctx)
            {
                (s.EVP_PKEY_CTX_free)(pctx);
                clear_error();
                return Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )));
            }
            let rc = (s.EVP_PKEY_verify)(
                pctx,
                signature.as_ptr(),
                signature.len(),
                digest.as_ptr(),
                digest.len(),
            );
            (s.EVP_PKEY_CTX_free)(pctx);
            if rc == 1 {
                Ok(())
            } else {
                clear_error();
                Err(Error::Verification(format!(
                    "{} signature invalid",
                    scheme.name()
                )))
            }
        }
    }
}
