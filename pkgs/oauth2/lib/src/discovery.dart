// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// An exception thrown when OAuth 2.0 discovery fails.
class DiscoveryException implements Exception {
  final String message;

  DiscoveryException(this.message);

  @override
  String toString() => message;
}

/// OAuth 2.0 Authorization Server Metadata (RFC 8414).
final class OAuthServerMetadata {
  /// The authorization server's issuer identifier.
  ///
  /// This is a URL that uniquely identifies the authorization server. It is
  /// typically used as a base URL for other endpoints and to prevent
  /// mix-up attacks.
  final String issuer;

  /// URL of the authorization server's authorization endpoint.
  ///
  /// This is the URL to which the user should be redirected to begin the
  /// authorization process.
  final String authorizationEndpoint;

  /// URL of the authorization server's token endpoint.
  ///
  /// This is the URL where the client exchanges an authorization grant (like
  /// an authorization code) for an access token.
  final String tokenEndpoint;

  /// URL of the authorization server's OAuth 2.0 Dynamic Client Registration
  /// endpoint.
  ///
  /// This is used by clients to dynamically register with the authorization
  /// server to obtain a client ID and optionally a client secret.
  final String? registrationEndpoint;

  /// JSON array containing a list of the OAuth 2.0 scope values that this
  /// authorization server supports.
  ///
  /// This allows clients to know in advance which scopes they can request.
  final List<String>? scopesSupported;

  /// JSON array containing a list of the OAuth 2.0 response type values
  /// that this authorization server supports.
  ///
  /// This indicates which authorization flows (e.g., "code", "token") are
  /// available.
  final List<String> responseTypesSupported;

  /// JSON array containing a list of the OAuth 2.0 grant type values that this
  /// authorization server supports.
  ///
  /// This informs clients about the supported methods for obtaining a token
  /// (e.g., "authorization_code", "client_credentials").
  final List<String>? grantTypesSupported;

  /// JSON array containing a list of client authentication methods supported
  /// by this token endpoint.
  ///
  /// This specifies how the client should authenticate itself when requesting
  /// a token (e.g., "client_secret_basic", "client_secret_post").
  final List<String>? tokenEndpointAuthMethodsSupported;

  /// JSON array containing a list of PKCE code challenge methods supported
  /// by this authorization server.
  ///
  /// This lists the supported hashing algorithms for Proof Key for Code
  /// Exchange (e.g., "S256", "plain").
  final List<String>? codeChallengeMethodsSupported;

  /// Boolean value specifying whether the authorization server supports
  /// multiple issuers.
  ///
  /// If true, the server can issue tokens for multiple issuers, which might
  /// require additional verification steps by the client.
  final bool? clientIdMetadataDocumentSupported;

  const OAuthServerMetadata({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.registrationEndpoint,
    this.scopesSupported,
    required this.responseTypesSupported,
    this.grantTypesSupported,
    this.tokenEndpointAuthMethodsSupported,
    this.codeChallengeMethodsSupported,
    this.clientIdMetadataDocumentSupported,
  });

  factory OAuthServerMetadata.fromJson(Map<String, dynamic> json) {
    return OAuthServerMetadata(
      issuer: json['issuer'] as String,
      authorizationEndpoint: json['authorization_endpoint'] as String,
      tokenEndpoint: json['token_endpoint'] as String,
      registrationEndpoint: json['registration_endpoint'] as String?,
      scopesSupported: _stringList(json['scopes_supported']),
      responseTypesSupported:
          _stringList(json['response_types_supported']) ?? const [],
      grantTypesSupported: _stringList(json['grant_types_supported']),
      tokenEndpointAuthMethodsSupported: _stringList(
        json['token_endpoint_auth_methods_supported'],
      ),
      codeChallengeMethodsSupported: _stringList(
        json['code_challenge_methods_supported'],
      ),
      clientIdMetadataDocumentSupported:
          json['client_id_metadata_document_supported'] as bool?,
    );
  }
}

/// OAuth 2.0 Protected Resource Metadata (RFC 9728).
final class OAuthProtectedResourceMetadata {
  /// A URI that identifies the protected resource.
  ///
  /// This is used to prevent mix-up and spoofing attacks by ensuring the
  /// metadata corresponds to the intended resource server.
  final String resource;

  /// JSON array of authorization server identifiers that the protected resource
  /// trusts.
  ///
  /// This tells clients which authorization servers they can use to obtain
  /// access tokens for this resource.
  final List<String>? authorizationServers;

  /// JSON array of the scope values that the protected resource supports.
  ///
  /// This helps clients understand what level of access they can request
  /// for this specific resource.
  final List<String>? scopesSupported;

  const OAuthProtectedResourceMetadata({
    required this.resource,
    this.authorizationServers,
    this.scopesSupported,
  });

  factory OAuthProtectedResourceMetadata.fromJson(Map<String, dynamic> json) {
    return OAuthProtectedResourceMetadata(
      resource: json['resource'] as String,
      authorizationServers: _stringList(json['authorization_servers']),
      scopesSupported: _stringList(json['scopes_supported']),
    );
  }
}

List<String>? _stringList(dynamic value) {
  if (value is! List) return null;
  return value.whereType<String>().toList();
}

/// Discovers OAuth 2.0 / OpenID Connect authorization server metadata.
///
/// Tries RFC 8414 (`oauth-authorization-server`) first, then falls back to
/// OpenID Connect Discovery (`openid-configuration`).
///
/// Completes with the metadata, or with `null` if no metadata endpoint could
/// be found.
///
/// If a metadata endpoint is found but returns an invalid response (e.g.,
/// malformed JSON or issuer spoofing is detected), the function will catch
/// the resulting exception and automatically try the next fallback URL.
/// It throws a [DiscoveryException] or [FormatException] only if all attempted
/// endpoints fail with errors.
Future<OAuthServerMetadata?> discoverAuthorizationServerMetadata(
  Uri authorizationServerUrl, {
  http.Client? httpClient,
}) async {
  if (!authorizationServerUrl.isScheme('https')) {
    throw ArgumentError.value(authorizationServerUrl, 'authorizationServerUrl',
        'Must be an HTTPS URL per RFC 8414.');
  }
  final client = httpClient ?? http.Client();
  try {
    for (final endpoint in _buildDiscoveryUrls(authorizationServerUrl)) {
      try {
        final response = await client.get(endpoint);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode >= 400 && response.statusCode < 500) {
            continue;
          }
          throw DiscoveryException(
            'HTTP ${response.statusCode} loading authorization server '
            'metadata from $endpoint',
          );
        }
        final metadata = OAuthServerMetadata.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        final expectedIssuer = authorizationServerUrl.toString();
        if (metadata.issuer.replaceAll(RegExp(r'/$'), '') !=
            expectedIssuer.replaceAll(RegExp(r'/$'), '')) {
          throw DiscoveryException(
            'Issuer spoofing detected: metadata issuer "${metadata.issuer}" '
            'does not match expected "$expectedIssuer".',
          );
        }
        return metadata;
      } catch (e) {
        if (e is DiscoveryException) rethrow;
        continue;
      }
    }
    return null;
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Discovers RFC 9728 OAuth 2.0 Protected Resource Metadata.
///
/// The returned [Future] completes with the metadata. It completes with a
/// [DiscoveryException] if the metadata endpoint is not found (HTTP 404) or
/// returns another invalid response.
Future<OAuthProtectedResourceMetadata> discoverProtectedResourceMetadata(
  Uri serverUrl, {
  Uri? resourceMetadataUrl,
  http.Client? httpClient,
}) async {
  if (!serverUrl.isScheme('https')) {
    throw ArgumentError.value(
        serverUrl, 'serverUrl', 'Must be an HTTPS URL per RFC 9728.');
  }
  if (resourceMetadataUrl != null && !resourceMetadataUrl.isScheme('https')) {
    throw ArgumentError.value(resourceMetadataUrl, 'resourceMetadataUrl',
        'Must be an HTTPS URL per RFC 9728.');
  }
  final client = httpClient ?? http.Client();
  try {
    final url = resourceMetadataUrl ??
        serverUrl.replace(
          path: '/.well-known/oauth-protected-resource${serverUrl.path}',
        );

    final response = await client.get(url);
    if (response.statusCode == 404) {
      throw DiscoveryException(
        'Resource server does not implement OAuth 2.0 Protected Resource '
        'Metadata.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiscoveryException(
        'HTTP ${response.statusCode} loading protected resource metadata.',
      );
    }
    final metadata = OAuthProtectedResourceMetadata.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    final expectedResource = serverUrl.toString();
    if (metadata.resource.replaceAll(RegExp(r'/$'), '') !=
        expectedResource.replaceAll(RegExp(r'/$'), '')) {
      throw DiscoveryException(
        'Resource spoofing detected: metadata resource "${metadata.resource}" '
        'does not match expected "$expectedResource".',
      );
    }
    return metadata;
  } finally {
    if (httpClient == null) client.close();
  }
}

List<Uri> _buildDiscoveryUrls(Uri authServerUrl) {
  final hasPath = authServerUrl.path.isNotEmpty && authServerUrl.path != '/';
  final origin = authServerUrl.origin;

  if (!hasPath) {
    return [
      Uri.parse('$origin/.well-known/oauth-authorization-server'),
      Uri.parse('$origin/.well-known/openid-configuration'),
    ];
  }

  var path = authServerUrl.path;
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return [
    Uri.parse('$origin/.well-known/oauth-authorization-server$path'),
    Uri.parse('$origin/.well-known/openid-configuration$path'),
    Uri.parse('$origin$path/.well-known/openid-configuration'),
  ];
}
