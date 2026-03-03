// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'authorization_exception.dart';
import 'discovery.dart';

/// OAuth 2.0 Client Metadata (RFC 7591).
class OAuthClientMetadata {
  /// Array of redirection URI strings for use in redirect-based flows.
  final List<String> redirectUris;

  /// String indicator of the requested authentication method for the token endpoint.
  final String? tokenEndpointAuthMethod;

  /// Array of OAuth 2.0 grant type strings that the client can use at the token endpoint.
  final List<String>? grantTypes;

  /// Array of the OAuth 2.0 response type strings that the client can use at the
  /// authorization endpoint.
  final List<String>? responseTypes;

  /// Human-readable string name of the client to be presented to the end-user.
  final String? clientName;

  /// URL string of a web page providing information about the client.
  final String? clientUri;

  /// String containing a space-separated list of scope values that the client
  /// can use when requesting access tokens.
  final String? scope;

  /// A unique identifier string assigned by the client developer or
  /// software publisher used by registration endpoints.
  final String? softwareId;

  /// A version identifier string for the client software identified by [softwareId].
  final String? softwareVersion;

  const OAuthClientMetadata({
    required this.redirectUris,
    this.tokenEndpointAuthMethod,
    this.grantTypes,
    this.responseTypes,
    this.clientName,
    this.clientUri,
    this.scope,
    this.softwareId,
    this.softwareVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'redirect_uris': redirectUris,
      if (tokenEndpointAuthMethod != null)
        'token_endpoint_auth_method': tokenEndpointAuthMethod,
      if (grantTypes != null) 'grant_types': grantTypes,
      if (responseTypes != null) 'response_types': responseTypes,
      if (clientName != null) 'client_name': clientName,
      if (clientUri != null) 'client_uri': clientUri,
      if (scope != null) 'scope': scope,
      if (softwareId != null) 'software_id': softwareId,
      if (softwareVersion != null) 'software_version': softwareVersion,
    };
  }
}

/// OAuth 2.0 Client Information (RFC 7591).
class OAuthClientInformation {
  /// Opaque value used by the client to identify itself to the authorization server.
  final String clientId;

  /// String value specifying the client secret.
  final String? clientSecret;

  /// Time at which the client identifier was issued.
  final int? clientIdIssuedAt;

  /// Time at which the client secret will expire or 0 if it will not expire.
  final int? clientSecretExpiresAt;

  /// String indicator of the authentication method that the authorization server
  /// will accept from the client when using the token endpoint.
  final String? tokenEndpointAuthMethod;

  const OAuthClientInformation({
    required this.clientId,
    this.clientSecret,
    this.clientIdIssuedAt,
    this.clientSecretExpiresAt,
    this.tokenEndpointAuthMethod,
  });

  factory OAuthClientInformation.fromJson(Map<String, dynamic> json) {
    return OAuthClientInformation(
      clientId: json['client_id'] as String,
      clientSecret: json['client_secret'] as String?,
      clientIdIssuedAt: json['client_id_issued_at'] as int?,
      clientSecretExpiresAt: json['client_secret_expires_at'] as int?,
      tokenEndpointAuthMethod: json['token_endpoint_auth_method'] as String?,
    );
  }
}

/// Performs RFC 7591 Dynamic Client Registration.
///
/// The returned [Future] completes with the client information. It will
/// complete with an [AuthorizationException] if the request is rejected by the
/// server.
Future<OAuthClientInformation> registerClient(
  Uri authorizationServerUrl,
  OAuthClientMetadata clientMetadata, {
  OAuthServerMetadata? metadata,
  http.Client? httpClient,
}) async {
  if (!authorizationServerUrl.isScheme('https')) {
    throw ArgumentError.value(authorizationServerUrl, 'authorizationServerUrl',
        'Must be an HTTPS URL per RFC 7591.');
  }

  final client = httpClient ?? http.Client();
  try {
    final endpoint = metadata?.registrationEndpoint;
    Uri registrationUrl;
    if (endpoint != null) {
      registrationUrl = Uri.parse(endpoint);
    } else {
      registrationUrl = authorizationServerUrl.replace(path: '/register');
    }

    if (!registrationUrl.isScheme('https')) {
      throw ArgumentError.value(registrationUrl, 'registrationEndpoint',
          'Must be an HTTPS URL per RFC 7591.');
    }

    final response = await client.post(
      registrationUrl,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(clientMetadata.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.headers['content-type']?.contains('application/json') ==
          true) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        var description = body['error_description'] as String?;
        var uriString = body['error_uri'] as String?;
        var uri = uriString == null ? null : Uri.parse(uriString);
        throw AuthorizationException(body['error'] as String, description, uri);
      }
      throw StateError(
          'HTTP ${response.statusCode} registering client at $registrationUrl');
    }
    return OAuthClientInformation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  } finally {
    if (httpClient == null) client.close();
  }
}
