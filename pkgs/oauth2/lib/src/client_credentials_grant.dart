// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'client.dart';
import 'client_authenticator.dart';
import 'handle_access_token_response.dart';
import 'utils.dart';

/// Obtains credentials using a [client credentials grant](https://tools.ietf.org/html/rfc6749#section-1.3.4).
///
/// This mode of authorization uses the client's [identifier] and [secret]
/// to obtain an authorization token from the authorization server, instead
/// of sending a user through a dedicated flow.
///
/// The client [identifier] and [secret] are required, and are
/// used to identify and authenticate your specific OAuth2 client. These are
/// usually global to the program using this library.
///
/// The specific permissions being requested from the authorization server may
/// be specified via [scopes]. The scope strings are specific to the
/// authorization server and may be found in its documentation. Note that you
/// may not be granted access to every scope you request; you may check the
/// [Credentials.scopes] field of [Client.credentials] to see which scopes you
/// were granted.
///
/// The scope strings will be separated by the provided [delimiter]. This
/// defaults to `" "`, the OAuth2 standard, but some APIs (such as Facebook's)
/// use non-standard delimiters.
///
/// By default, this follows the OAuth2 spec and requires the server's responses
/// to be in JSON format. However, some servers return non-standard response
/// formats, which can be parsed using the [getParameters] function.
///
/// This function is passed the `Content-Type` header of the response as well as
/// its body as a UTF-8-decoded string. It should return a map in the same
/// format as the [standard JSON response](https://tools.ietf.org/html/rfc6749#section-5.1).
///
/// [customAuth] is an optional callback to add additional client
/// authentication headers or body parameters to a token request for advanced
/// scenarios, such as when using a JWT Bearer token for client authentication
/// per [RFC 7523](https://tools.ietf.org/html/rfc7523#section-2.2). When
/// provided, it replaces the default `basicAuth` credentials integration in
/// token requests.
Future<Client> clientCredentialsGrant(
    Uri authorizationEndpoint, String? identifier, String? secret,
    {Iterable<String>? scopes,
    bool basicAuth = true,
    http.Client? httpClient,
    String? delimiter,
    ClientAuthenticator? customAuth,
    Iterable<Uri>? resources,
    Map<String, dynamic> Function(MediaType? contentType, String body)?
        getParameters}) async {
  delimiter ??= ' ';
  var startTime = DateTime.now();

  var body = {'grant_type': 'client_credentials'};

  var headers = <String, String>{};

  if (customAuth != null) {
    if (identifier != null) body['client_id'] = identifier;
    await customAuth(headers, body);
  } else if (identifier != null) {
    if (basicAuth) {
      headers['Authorization'] = basicAuthHeader(identifier, secret!);
    } else {
      body['client_id'] = identifier;
      if (secret != null) body['client_secret'] = secret;
    }
  }

  if (scopes != null && scopes.isNotEmpty) {
    body['scope'] = scopes.join(delimiter);
  }

  if (resources != null && resources.isNotEmpty) {
    // http.post doesn't support Map<String, Iterable> for x-www-form-urlencoded
    // bodies, so we construct the body string manually to allow
    // multiple 'resource' parameters per RFC 8707.
    final encodedBody = body.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}')
        .toList();
    for (final r in resources) {
      encodedBody.add('resource=${Uri.encodeQueryComponent(r.toString())}');
    }

    httpClient ??= http.Client();
    var response = await httpClient.post(authorizationEndpoint,
        headers: headers
          ..['content-type'] = 'application/x-www-form-urlencoded',
        body: encodedBody.join('&'));

    var credentials = handleAccessTokenResponse(response, authorizationEndpoint,
        startTime, scopes?.toList() ?? [], delimiter,
        getParameters: getParameters);
    return Client(credentials,
        identifier: identifier,
        secret: secret,
        httpClient: httpClient,
        customAuth: customAuth);
  }

  httpClient ??= http.Client();
  var response = await httpClient.post(authorizationEndpoint,
      headers: headers, body: body);

  var credentials = handleAccessTokenResponse(response, authorizationEndpoint,
      startTime, scopes?.toList() ?? [], delimiter,
      getParameters: getParameters);
  return Client(credentials,
      identifier: identifier,
      secret: secret,
      httpClient: httpClient,
      customAuth: customAuth);
}
