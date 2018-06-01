// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

String _encodeJson(Object input) =>
    const JsonEncoder.withIndent(' ').convert(input);

Matcher _throwsParsedYamlException(String prettyValue) => throwsA(allOf(
    const isInstanceOf<ParsedYamlException>(),
    new FeatureMatcher<ParsedYamlException>('formattedMessage', (e) {
      var message = e.formattedMessage;
      printOnFailure("Actual error format:\nr'''\n$message'''");
      _printDebugParsedYamlException(e);
      return message;
    }, prettyValue)));

void _printDebugParsedYamlException(ParsedYamlException e) {
  var innerError = e.innerError;
  var innerStack = e.innerStack;

  if (e.innerError is CheckedFromJsonException) {
    var cfje = e.innerError as CheckedFromJsonException;
    if (cfje.innerError != null) {
      innerError = cfje.innerError;
      innerStack = cfje.innerStack;
    }
  }

  if (innerError != null) {
    var items = [innerError];
    if (innerStack != null) {
      items.add(Trace.format(innerStack, terse: true));
    }

    var content =
        LineSplitter.split(items.join('\n')).map((e) => '  $e').join('\n');

    printOnFailure('Inner error details:\n$content');
  }
}

Pubspec parse(Object content, {bool quietOnError: false}) {
  quietOnError ??= false;
  try {
    return new Pubspec.parse(_encodeJson(content));
  } on ParsedYamlException catch (e) {
    if (!quietOnError) {
      _printDebugParsedYamlException(e);
    }
    rethrow;
  }
}

void expectParseThrows(Object content, String expectedError) => expect(
    () => parse(content, quietOnError: true),
    _throwsParsedYamlException(expectedError));

// TODO(kevmoo) add this to pkg/matcher – is nice!
class FeatureMatcher<T> extends CustomMatcher {
  final dynamic Function(T value) _feature;

  FeatureMatcher(String name, this._feature, matcher)
      : super('`$name`', '`$name`', matcher);

  @override
  featureValueOf(covariant T actual) => _feature(actual);
}
