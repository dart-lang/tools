// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// OAuth 2.0 Authorization Server Metadata (RFC 8414).
class OAuthServerMetadata {
  final String issuer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? registrationEndpoint;
  final List<String>? scopesSupported;
  final List<String> responseTypesSupported;
  final List<String>? grantTypesSupported;
  final List<String>? tokenEndpointAuthMethodsSupported;
  final List<String>? codeChallengeMethodsSupported;
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
class OAuthProtectedResourceMetadata {
  final String resource;
  final List<String>? authorizationServers;
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
Future<OAuthServerMetadata?> discoverAuthorizationServerMetadata(
  Uri authorizationServerUrl, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    for (final endpoint in _buildDiscoveryUrls(authorizationServerUrl)) {
      try {
        final response = await client.get(endpoint);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode >= 400 && response.statusCode < 500) {
            continue;
          }
          throw StateError(
            'HTTP ${response.statusCode} loading authorization server '
            'metadata from $endpoint',
          );
        }
        final metadata = OAuthServerMetadata.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        final expectedIssuer = authorizationServerUrl.toString();
        if (metadata.issuer != expectedIssuer &&
            metadata.issuer != expectedIssuer.replaceFirst(RegExp(r'/$'), '')) {
          throw StateError(
            'Issuer spoofing detected: metadata issuer "${metadata.issuer}" '
            'does not match expected "$expectedIssuer".',
          );
        }
        return metadata;
      } catch (e) {
        if (e is StateError) rethrow;
        continue;
      }
    }
    return null;
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Discovers RFC 9728 OAuth 2.0 Protected Resource Metadata.
Future<OAuthProtectedResourceMetadata> discoverProtectedResourceMetadata(
  Uri serverUrl, {
  Uri? resourceMetadataUrl,
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    final url = resourceMetadataUrl ??
        serverUrl.replace(
          path: '/.well-known/oauth-protected-resource${serverUrl.path}',
        );

    final response = await client.get(url);
    if (response.statusCode == 404) {
      throw StateError(
        'Resource server does not implement OAuth 2.0 Protected Resource '
        'Metadata.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode} loading protected resource metadata.',
      );
    }
    final metadata = OAuthProtectedResourceMetadata.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    final expectedResource = serverUrl.toString();
    if (metadata.resource != expectedResource &&
        metadata.resource != expectedResource.replaceFirst(RegExp(r'/$'), '')) {
      throw StateError(
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
  final hasPath = authServerUrl.path != '/';
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
