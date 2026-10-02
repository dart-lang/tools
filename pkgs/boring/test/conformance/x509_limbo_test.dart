// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Runs the [x509-limbo](https://x509-limbo.com) path validation suite against
/// BoringSSL's `X509_verify_cert`, through the raw bindings.
///
/// x509-limbo is a corpus of ~9800 X.509 chain building and validation
/// testcases maintained by C2SP. Fetch it and run this suite with
/// `./tool/run_x509_limbo_tests.sh`.
///
/// `X509_verify_cert` applies no signature algorithm or key strength policy,
/// and leaves both to its caller. [_verify] applies them the way a careful
/// caller would, see [_checkChainPolicy].
///
/// No implementation passes every testcase: the suite deliberately includes
/// behaviour that RFC 5280, the CA/Browser Forum baseline requirements and
/// individual libraries disagree on. Testcases where BoringSSL is known to
/// diverge are listed in `x509_limbo_expected_failures.txt`. This suite fails
/// if a testcase diverges that is not on that list, and also if a listed
/// testcase starts agreeing, so the list cannot silently go stale.
///
/// Set `X509_LIMBO_REGENERATE=1` to rewrite the list instead of asserting
/// against it.
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:boring/bindings.dart' as ssl;
import 'package:ffi/ffi.dart' show StringUtf8Pointer, Utf8, Utf8Pointer;
import 'package:test/test.dart';

/// Namespaces that cannot run against the current API at all.
const _skippedNamespaces = {
  // Fetches live certificate chains over the network.
  'online',
};

/// Testcase features that [_verify] does not implement.
const _skippedFeatures = {
  // Requires supplying CRLs and performing revocation checking.
  'has-crl',
};

File? _findLimboJson() {
  final env = Platform.environment['X509_LIMBO_JSON'];
  if (env != null && File(env).existsSync()) return File(env);

  const candidates = [
    'build/x509-limbo/limbo.json',
    '../build/x509-limbo/limbo.json',
    '/tmp/limbo.json',
  ];
  for (final candidate in candidates) {
    final f = File(candidate);
    if (f.existsSync()) return f;
  }
  return null;
}

File _expectedFailuresFile() {
  for (final candidate in [
    'test/conformance/x509_limbo_expected_failures.txt',
    'conformance/x509_limbo_expected_failures.txt',
    'x509_limbo_expected_failures.txt',
  ]) {
    final f = File(candidate);
    if (f.existsSync()) return f;
  }
  return File('test/conformance/x509_limbo_expected_failures.txt');
}

Set<String> _readExpectedFailures(File file) => file.existsSync()
    ? file
          .readAsLinesSync()
          .map((l) => l.split('#').first.trim())
          .where((l) => l.isNotEmpty)
          .toSet()
    : <String>{};

/// The kind of name a peer certificate is expected to assert.
enum _PeerNameKind { dns, ip, email }

/// A name the peer certificate is expected to assert.
typedef _PeerName = ({_PeerNameKind kind, String value});

/// A single x509-limbo testcase, decoded from `limbo.json`.
final class _Testcase {
  final Map<String, dynamic> json;

  _Testcase(this.json);

  String get id => json['id'] as String;

  String get namespace => id.split('::').first;

  bool get expectSuccess => json['expected_result'] == 'SUCCESS';

  List<String> get _features =>
      ((json['features'] as List?) ?? const []).cast<String>();

  bool get isSkipped =>
      _skippedNamespaces.contains(namespace) ||
      _features.any(_skippedFeatures.contains) ||
      // An X509_VERIFY_PARAM holds at most one expected email address and one
      // expected IP address, so these cannot be expressed.
      peerNames.where((n) => n.kind == _PeerNameKind.email).length > 1 ||
      peerNames.where((n) => n.kind == _PeerNameKind.ip).length > 1;

  List<String> _pems(String key) =>
      ((json[key] as List?) ?? const []).cast<String>();

  List<String> get trustedCerts => _pems('trusted_certs');

  List<String> get untrustedIntermediates => _pems('untrusted_intermediates');

  String get peerCertificate => json['peer_certificate'] as String;

  DateTime? get validationTime {
    final raw = json['validation_time'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  int? get maxChainDepth => json['max_chain_depth'] as int?;

  /// The `X509_PURPOSE_*` to validate the peer certificate for.
  int get purpose => json['validation_kind'] == 'CLIENT'
      ? ssl.X509_PURPOSE_SSL_CLIENT
      : ssl.X509_PURPOSE_SSL_SERVER;

  List<_PeerName> get peerNames => [
    for (final raw in [
      if (json['expected_peer_name'] != null) json['expected_peer_name'],
      ...(json['expected_peer_names'] as List?) ?? const [],
    ])
      _peerName((raw as Map).cast<String, dynamic>()),
  ];

  static _PeerName _peerName(Map<String, dynamic> raw) => (
    kind: switch (raw['kind']) {
      'DNS' => _PeerNameKind.dns,
      'IP' => _PeerNameKind.ip,
      'RFC822' => _PeerNameKind.email,
      final kind => throw UnsupportedError('Unknown peer name kind: $kind'),
    },
    value: raw['value'] as String,
  );
}

/// The reason recorded for a chain that verified when the suite expected it to
/// be rejected.
const _accepted = '<accepted>';

/// Runs [testcase], returning whether the chain validated and, when it did
/// not, the reason BoringSSL gave.
///
/// A testcase whose inputs cannot even be parsed counts as a validation
/// failure, which is what limbo expects for malformed-certificate cases.
(bool valid, String reason) _runTestcase(_Testcase testcase) {
  try {
    final failure = _verify(testcase);
    return (failure == null, _canonicalReason(failure ?? _accepted));
  } on Exception catch (e) {
    return (false, 'the input could not be parsed: $e');
  } finally {
    // Failed calls leave errors on BoringSSL's thread-local error queue.
    ssl.ERR_clear_error();
  }
}

/// A BoringSSL call that failed before the chain could be validated.
final class _SetupException implements Exception {
  final String message;

  _SetupException(String operation)
    : message =
          '$operation failed: '
          '${ssl.extractBoringSslError() ?? 'no error reported'}';

  @override
  String toString() => message;
}

/// Validates the chain in [testcase] with `X509_verify_cert`, then applies
/// [_checkChainPolicy] to the chain it built.
///
/// Returns null if the chain is valid, or why it is not. Throws a
/// [_SetupException] if an input cannot be parsed or a verification parameter
/// cannot be set.
String? _verify(_Testcase testcase) => ssl.BoringArena.run((arena) {
  final store = arena.using(ssl.X509_STORE_new(), ssl.X509_STORE_free);
  for (final pem in testcase.trustedCerts) {
    // Duplicates are silently ignored.
    if (ssl.X509_STORE_add_cert(store, _parseCertificate(arena, pem)) != 1) {
      throw _SetupException('X509_STORE_add_cert');
    }
  }

  final leaf = _parseCertificate(arena, testcase.peerCertificate);
  ffi.Pointer<ssl.stack_st_X509> untrusted = ffi.nullptr;
  if (testcase.untrustedIntermediates.isNotEmpty) {
    final stack = arena.using(ssl.OPENSSL_sk_new_null(), ssl.OPENSSL_sk_free);
    for (final pem in testcase.untrustedIntermediates) {
      if (ssl.OPENSSL_sk_push(stack, _parseCertificate(arena, pem).cast()) ==
          0) {
        throw _SetupException('OPENSSL_sk_push');
      }
    }
    untrusted = stack.cast();
  }

  // Registered last, so it is freed before everything it references.
  final ctx = arena.using(ssl.X509_STORE_CTX_new(), ssl.X509_STORE_CTX_free);
  if (ssl.X509_STORE_CTX_init(ctx, store, leaf, untrusted) != 1) {
    throw _SetupException('X509_STORE_CTX_init');
  }
  if (testcase.validationTime case final time?) {
    // Truncated to whole seconds.
    final seconds = time.millisecondsSinceEpoch ~/ 1000;
    ssl.X509_STORE_CTX_set_time_posix(ctx, 0, seconds);
  }

  final param = ssl.X509_STORE_CTX_get0_param(ctx);
  // Enables the key usage and extended key usage checks for the purpose.
  if (ssl.X509_VERIFY_PARAM_set_purpose(param, testcase.purpose) != 1) {
    throw _SetupException('X509_VERIFY_PARAM_set_purpose');
  }
  if (testcase.maxChainDepth case final depth?) {
    // The number of intermediates, excluding the leaf and the trust anchor.
    ssl.X509_VERIFY_PARAM_set_depth(param, depth);
  }
  final peerNames = testcase.peerNames;
  if (peerNames.isNotEmpty) {
    // Never fall back to the subject common name, as the CA/Browser Forum
    // baseline requirements and every modern TLS stack require.
    ssl.X509_VERIFY_PARAM_set_hostflags(
      param,
      ssl.X509_CHECK_FLAG_NEVER_CHECK_SUBJECT,
    );
    _setPeerNames(arena, param, peerNames);
  }

  if (ssl.X509_verify_cert(ctx) != 1) {
    final error = ssl.X509_STORE_CTX_get_error(ctx);
    // A static string, which must not be freed.
    final message = ssl.X509_verify_cert_error_string(error);
    return message == ffi.nullptr
        ? 'Unknown X.509 verification error ($error)'
        : message.cast<Utf8>().toDartString();
  }
  return _checkChainPolicy(arena, ssl.X509_STORE_CTX_get0_chain(ctx));
});

/// Parses the PEM certificate [pem], owned by [arena].
ffi.Pointer<ssl.X509> _parseCertificate(ssl.BoringArena arena, String pem) {
  final bytes = utf8.encode(pem);
  // BIO_new_mem_buf does not copy, and the arena releases the BIO first.
  final bio = arena.using(
    ssl.BIO_new_mem_buf(arena.copyBytes(bytes), bytes.length),
    ssl.BIO_free,
  );
  final cert = ssl.PEM_read_bio_X509(
    bio,
    ffi.nullptr,
    ffi.nullptr,
    ffi.nullptr,
  );
  if (cert == ffi.nullptr) throw _SetupException('PEM_read_bio_X509');
  return arena.using(cert, ssl.X509_free);
}

/// Configures the names the leaf certificate must assert on [param].
///
/// DNS names are matched with OR semantics: the leaf need only assert one of
/// them. Names of different kinds are matched with AND semantics.
void _setPeerNames(
  ssl.BoringArena arena,
  ffi.Pointer<ssl.X509_VERIFY_PARAM> param,
  List<_PeerName> peerNames,
) {
  var haveDnsName = false;
  for (final (:kind, :value) in peerNames) {
    final utf8Name = value.toNativeUtf8(allocator: arena);
    final name = utf8Name.cast<ffi.Char>();
    final ok = switch (kind) {
      // The first DNS name replaces any previous configuration, and later ones
      // are added to it.
      _PeerNameKind.dns when haveDnsName => ssl.X509_VERIFY_PARAM_add1_host(
        param,
        name,
        utf8Name.length,
      ),
      _PeerNameKind.dns => ssl.X509_VERIFY_PARAM_set1_host(
        param,
        name,
        utf8Name.length,
      ),
      _PeerNameKind.ip => ssl.X509_VERIFY_PARAM_set1_ip_asc(param, name),
      _PeerNameKind.email => ssl.X509_VERIFY_PARAM_set1_email(
        param,
        name,
        utf8Name.length,
      ),
    };
    haveDnsName |= kind == _PeerNameKind.dns;
    if (ok != 1) {
      throw _SetupException('configuring expected peer name $value');
    }
  }
}

/// Signature digests with practical collision attacks, which
/// `X509_verify_cert` accepts.
const _weakSignatureDigests = {
  ssl.NID_md4,
  ssl.NID_md5,
  ssl.NID_md5_sha1,
  ssl.NID_sha1,
};

/// EC curves offering at least a 128-bit security level.
///
/// This is the same set that `IsAcceptableCurveForEcdsa` allows in BoringSSL's
/// own newer `pki/` verifier. P-192 and explicitly parameterised curves are not
/// implemented by BoringSSL at all, so their keys fail to decode.
const _strongEcCurves = {
  ssl.NID_X9_62_prime256v1,
  ssl.NID_secp384r1,
  ssl.NID_secp521r1,
};

/// The smallest RSA modulus to accept, as required by the CA/Browser Forum
/// baseline requirements.
const _minimumRsaKeyBits = 2048;

/// Applies the policy checks that `X509_verify_cert` leaves to its caller to
/// the [chain] it built, which runs from the leaf to the trust anchor.
///
/// BoringSSL's `X509_verify_cert` has neither OpenSSL's
/// `X509_VERIFY_PARAM_set_auth_level` nor its `set1_sigalgs`, and the
/// `X509_VERIFY_PARAM_set_purpose` documentation says these security checks are
/// the caller's responsibility. So this rejects chains signed with a weak
/// digest, and certificates with a weak public key.
String? _checkChainPolicy(
  ssl.BoringArena arena,
  ffi.Pointer<ssl.stack_st_X509> chain,
) {
  final stack = chain.cast<ssl.OPENSSL_STACK>();
  final digestNid = arena<ffi.Int>();
  final length = ssl.OPENSSL_sk_num(stack);
  for (var depth = 0; depth < length; depth++) {
    final cert = ssl.OPENSSL_sk_value(stack, depth).cast<ssl.X509>();
    // The trust anchor's own signature is never verified, since it is trusted
    // by virtue of being in the store, so its digest is irrelevant. Its key is
    // not: that key verifies the certificate below it.
    final isTrustAnchor = depth == length - 1;
    if (!isTrustAnchor) {
      final signatureNid = ssl.X509_get_signature_nid(cert);
      // Signature algorithms without a separate digest, such as Ed25519, have
      // no entry. Those are never weak.
      if (ssl.OBJ_find_sigid_algs(signatureNid, digestNid, ffi.nullptr) == 1 &&
          _weakSignatureDigests.contains(digestNid.value)) {
        return 'certificate signed with the weak algorithm '
            '${_nidName(signatureNid)}';
      }
    }
    final weakKey = _checkKeyStrength(cert);
    if (weakKey != null) return weakKey;
  }
  return null;
}

/// Why the public key of [cert] is too weak to be trusted, or null if it is
/// not.
String? _checkKeyStrength(ffi.Pointer<ssl.X509> cert) {
  // Null means the key is of a type BoringSSL does not implement, or is
  // malformed. Nothing in chain building ever decodes the leaf's own key, so
  // without this the leaf could carry an entirely unexamined key.
  final key = ssl.X509_get0_pubkey(cert);
  if (key == ffi.nullptr) {
    return 'certificate has an unsupported or malformed public key';
  }
  final algorithm = ssl.EVP_PKEY_id(key);
  switch (algorithm) {
    // DSA is obsolete, forbidden by the CA/Browser Forum baseline
    // requirements, and absent from BoringSSL's `pki/` verifier.
    case ssl.EVP_PKEY_DSA:
      return 'certificate has a ${_nidName(algorithm)} key, which is not '
          'accepted';
    case ssl.EVP_PKEY_RSA || ssl.EVP_PKEY_RSA_PSS:
      final bits = ssl.EVP_PKEY_bits(key);
      if (bits < _minimumRsaKeyBits) {
        return 'certificate has a $bits-bit ${_nidName(algorithm)} key, below '
            'the $_minimumRsaKeyBits-bit minimum';
      }
    case ssl.EVP_PKEY_EC:
      final curve = ssl.EVP_PKEY_get_ec_curve_nid(key);
      if (!_strongEcCurves.contains(curve)) {
        return 'certificate has an EC key on ${_nidName(curve)}, which is '
            'below a 128-bit security level';
      }
  }
  // Anything else, such as Ed25519 or ML-DSA, is left alone. The point is to
  // catch keys that are demonstrably weak, not to enforce a web PKI profile.
  return null;
}

/// The short name for [nid], for use in messages.
String _nidName(int nid) {
  final name = ssl.OBJ_nid2sn(nid);
  return name == ffi.nullptr ? 'NID $nid' : name.cast<Utf8>().toDartString();
}

/// The grouping key for [_checkChainPolicy]'s weak signature digest rejection.
const _weakDigestReason = 'signed with a weak signature digest';

/// Collapses a reason into the key used to group and explain it.
///
/// The weak digest rejection names the offending algorithm, which would
/// otherwise split one explanation across a group per algorithm.
String _canonicalReason(String reason) =>
    reason.startsWith('certificate signed with the weak algorithm')
    ? _weakDigestReason
    : reason;

/// Why BoringSSL diverges from the suite, keyed by the reason it reports.
///
/// These are written by hand, from reading BoringSSL's sources and the
/// testcases themselves, and are emitted into the generated expected-failures
/// list so it explains itself. Add an entry here when a new reason appears.
const _divergenceNotes = <String, String>{
  'unsupported name constraint type':
      "BoringSSL's NAME_CONSTRAINTS_check (crypto/x509/v3_ncons.cc) handles "
      'only directoryName, dNSName, rfc822Name and uniformResourceIdentifier '
      'constraints, and returns X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE for '
      'every other GeneralName type. The BetterTLS name constraints suite is '
      'built almost entirely on iPAddress constraints, so it trips this on '
      'both the permitted and the excluded path. Supporting these would mean '
      'reimplementing name constraint checking on top of BoringSSL, which is '
      'out of scope for raw bindings.',
  _accepted:
      'BoringSSL accepted a chain the suite expects to be rejected. Most of '
      'these encode CA/Browser Forum baseline requirements, or deliberately '
      'pedantic readings of RFC 5280, that BoringSSL does not enforce: it is '
      'an RFC 5280 path validator and leaves CABF profile checks to the '
      'caller. Examples: requiring the subject common name to be a '
      'character-for-character copy of a SAN entry, forbidding '
      'anyExtendedKeyUsage, forbidding a critical extKeyUsage, requiring an '
      'authorityKeyIdentifier on every certificate, and rejecting key usage '
      'bits that a given key type cannot honour. The two RSA-2052 cases are '
      'a deliberate omission rather than a gap: CABF requires the modulus '
      'size to be divisible by 8, but RSA-2052 is stronger than the RSA-2048 '
      "the same profile permits, so this harness's key strength check, which "
      'is about strength rather than profile conformance, does not enforce '
      'it.',
  'unable to get local issuer certificate': _noBacktrackingNote,
  'unable to get issuer certificate': _noBacktrackingNote,
  'invalid CA certificate': _noBacktrackingNote,
  'permitted subtree violation': _noBacktrackingNote,
  'excluded subtree violation': _noBacktrackingNote,
  _weakDigestReason: _noBacktrackingNote,
  'unsupported certificate purpose':
      "The leaf's key usage or extended key usage does not satisfy the "
      'requested purpose. This harness maps the testcase validation_kind onto '
      'X509_PURPOSE_SSL_SERVER or X509_PURPOSE_SSL_CLIENT, so BoringSSL '
      'applies the TLS key usage check to the leaf. Two of these put a CA '
      'certificate in the leaf position, which RFC 5280 permits but which '
      'then asserts keyCertSign rather than a TLS key usage. The two '
      'bettertls::pathbuilding cases are instead the chain building '
      'limitation described in another group: the purpose check fails on a '
      'branch a backtracking validator would not have chosen.',
  'certificate has expired':
      'BoringSSL treats notAfter as exclusive. X509_cmp_time_posix '
      '(crypto/x509/x509_vfy.cc) reports expiry when the certificate time '
      'minus the comparison time is <= 0, so validating at exactly notAfter '
      'fails. RFC 5280 4.1.2.5 defines notAfter as inclusive. The second case '
      'validates five milliseconds past notAfter, which this harness '
      'truncates to whole seconds, producing the same comparison.',
};

/// Shared explanation for the whole family of chain building divergences.
const _noBacktrackingNote =
    'BoringSSL does not backtrack when a subject has more than one candidate '
    'issuer certificate. It commits to the first candidate it finds and '
    'reports whatever goes wrong down that branch, instead of retrying the '
    'alternative. bettertls::pathbuilding::tc52 is the clearest example: the '
    'intermediate "B" appears twice, once issued by "C" with CA:TRUE and once '
    'issued by "A" with CA:FALSE. BoringSSL picks the CA:FALSE certificate '
    'and stops, even though the other branch chains to the trust root. The '
    'same limitation produces the cross-signed cycle failure in '
    'cve::cve-2024-0567, the name constraint violations here are reported '
    'against a branch the suite does not expect a validator to choose, and '
    'the weak signature digest rejections here are on branches where an '
    'ecdsa-with-SHA1 cross-signature exists alongside an ecdsa-with-SHA256 '
    'one.';

/// Fallback used if a new reason appears before someone documents it.
const _undocumentedNote =
    'No explanation has been written for this reason yet. Investigate before '
    'accepting these entries: add a note to _divergenceNotes in '
    'test/conformance/x509_limbo_test.dart.';

const _expectedFailuresHeader = '''
# Testcases from https://x509-limbo.com where BoringSSL's X509_verify_cert,
# followed by the policy checks in x509_limbo_test.dart, disagrees with the
# suite's expected result.
#
# Every entry is a difference in scope between BoringSSL and the suite, not a
# known bug in this package. Entries are grouped below by explanation, since
# one underlying limitation can surface as several different errors. Each
# group lists the errors BoringSSL reported and why they are expected.
#
# The suite fails both on a divergence that is not listed here and on a listed
# testcase that starts agreeing, so this list cannot silently go stale.
#
# Generated. Regenerate with:
#   X509_LIMBO_REGENERATE=1 ./tool/run_x509_limbo_tests.sh
''';

/// Greedily wraps [text] to [width] columns.
List<String> _wrap(String text, int width) {
  final lines = <String>[];
  var line = StringBuffer();
  for (final word in text.split(' ')) {
    if (line.isNotEmpty && line.length + 1 + word.length > width) {
      lines.add(line.toString());
      line = StringBuffer();
    }
    if (line.isNotEmpty) line.write(' ');
    line.write(word);
  }
  if (line.isNotEmpty) lines.add(line.toString());
  return lines;
}

/// Condenses a limbo description into a one-line trailing comment.
///
/// Returns null when the description carries no information, which is the case
/// for the BetterTLS testcases: they are all "Testcase `N` from the BetterTLS
/// `<suite>` suite."
String? _summarize(String description) {
  var text = description
      // Descriptions embed a fenced ASCII diagram of the chain.
      .replaceAll(RegExp('```.*?```', dotAll: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      // '#' would start a comment, and descriptions use it for headings.
      .replaceAll('#', '')
      .trim()
      // Every description opens by introducing the diagram removed above.
      .replaceFirst(RegExp(r'^Produces the following [^:]*:\s*'), '');
  if (text.startsWith('Testcase ')) return null;
  final end = text.indexOf(RegExp(r'\.(\s|$)'));
  if (end > 0) text = text.substring(0, end + 1);
  if (text.length > 100) text = '${text.substring(0, 97)}...';
  return text.isEmpty ? null : text;
}

/// Renders the expected-failures list, grouped and annotated.
///
/// Grouping is by explanation rather than by BoringSSL's error string: one
/// underlying limitation can surface as several different errors, and the
/// explanation is worth reading once rather than five times.
String _renderExpectedFailures(
  List<(String id, String reason)> diverged,
  Map<String, String> descriptions,
) {
  final byNote = <String, List<(String id, String reason)>>{};
  for (final entry in diverged) {
    byNote
        .putIfAbsent(_divergenceNotes[entry.$2] ?? _undocumentedNote, () => [])
        .add(entry);
  }
  // Largest groups first, so the dominant cause is the first thing read.
  final notes = byNote.keys.toList()
    ..sort((a, b) {
      final byCount = byNote[b]!.length.compareTo(byNote[a]!.length);
      return byCount != 0 ? byCount : a.compareTo(b);
    });

  final out = StringBuffer(_expectedFailuresHeader);
  for (final note in notes) {
    final entries = byNote[note]!..sort((a, b) => a.$1.compareTo(b.$1));
    final counts = <String, int>{};
    for (final (_, reason) in entries) {
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    final reasons = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    out
      ..writeln()
      ..writeln('# ${'=' * 75}')
      ..writeln('# ${entries.length} testcase(s):');
    for (final reason in reasons) {
      final what = reason == _accepted
          ? 'accepted, but the suite expects rejection'
          : 'rejected with "$reason"';
      out.writeln('#   ${counts[reason]} x $what');
    }
    out.writeln('# ${'-' * 75}');
    for (final line in _wrap(note, 74)) {
      out.writeln('# $line');
    }
    out.writeln();

    // Only worth tagging each entry when the group spans several errors.
    final tagReason = reasons.length > 1;
    for (final (id, reason) in entries) {
      final parts = <String>[
        if (tagReason && reason != _accepted) reason,
        ?_summarize(descriptions[id] ?? ''),
      ];
      out.writeln(parts.isEmpty ? id : '$id  # ${parts.join('; ')}');
    }
  }
  return out.toString();
}

void main() {
  final limboJson = _findLimboJson();

  group('x509-limbo Conformance', () {
    if (limboJson == null) {
      test(
        'x509-limbo testcases available',
        () {},
        skip:
            'limbo.json not found. '
            'Run ./tool/run_x509_limbo_tests.sh to fetch and run the suite.',
      );
      return;
    }

    final limbo = jsonDecode(limboJson.readAsStringSync()) as Map;
    final testcases = [
      for (final raw in limbo['testcases'] as List)
        _Testcase((raw as Map).cast<String, dynamic>()),
    ];
    final byNamespace = <String, List<_Testcase>>{};
    for (final testcase in testcases) {
      byNamespace.putIfAbsent(testcase.namespace, () => []).add(testcase);
    }

    final expectedFailuresFile = _expectedFailuresFile();
    final expectedFailures = _readExpectedFailures(expectedFailuresFile);
    final regenerate = Platform.environment['X509_LIMBO_REGENERATE'] == '1';
    final diverged = <(String id, String reason)>[];
    var ran = 0;

    for (final namespace in byNamespace.keys.toList()..sort()) {
      final namespaceCases = byNamespace[namespace]!;
      test('$namespace (${namespaceCases.length} testcases)', () {
        final unexpected = <String>[];
        final unexpectedlyPassing = <String>[];

        for (final testcase in namespaceCases) {
          if (testcase.isSkipped) continue;
          ran++;
          final (valid, reason) = _runTestcase(testcase);
          final agrees = valid == testcase.expectSuccess;
          if (!agrees) diverged.add((testcase.id, reason));

          if (regenerate) continue;
          if (!agrees && !expectedFailures.contains(testcase.id)) {
            unexpected.add(
              '${testcase.id} (expected '
              '${testcase.expectSuccess ? "SUCCESS" : "FAILURE"})',
            );
          } else if (agrees && expectedFailures.contains(testcase.id)) {
            unexpectedlyPassing.add(testcase.id);
          }
        }

        expect(
          unexpected,
          isEmpty,
          reason:
              '${unexpected.length} testcase(s) diverged from x509-limbo and '
              'are not listed in ${expectedFailuresFile.path}',
        );
        expect(
          unexpectedlyPassing,
          isEmpty,
          reason:
              '${unexpectedlyPassing.length} testcase(s) are listed in '
              '${expectedFailuresFile.path} but now agree with x509-limbo. '
              'Remove them from the list.',
        );
      });
    }

    tearDownAll(() {
      final agreed = ran - diverged.length;
      final rate = ran == 0 ? 0.0 : 100 * agreed / ran;
      // ignore: avoid_print
      print(
        'x509-limbo: $agreed/$ran testcases agree '
        '(${rate.toStringAsFixed(1)}%), '
        '${testcases.length - ran} skipped as unsupported.',
      );
      if (!regenerate) return;
      expectedFailuresFile.writeAsStringSync(
        _renderExpectedFailures(diverged, {
          for (final testcase in testcases)
            testcase.id: testcase.json['description'] as String,
        }),
      );
      // ignore: avoid_print
      print(
        'Wrote ${diverged.length} divergences to ${expectedFailuresFile.path}',
      );
    });
  });
}
