library samples_test;

import 'dart:mirrors';
import 'dart:io';
import 'package:test/test.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/src/messages.dart';
import 'testing.dart';

const testOptions = const PreprocessorOptions(
    useColors: false,
    checked: false,
    warningsAsErrors: true,
    inputFile: 'memory');

void testCSSFile(File cssFile) {
  final errors = <Message>[];
  final css = cssFile.readAsStringSync();
  final stylesheet = parseCss(css, errors: errors, opts: testOptions);

  expect(stylesheet, isNotNull);
  expect(errors, isEmpty, reason: errors.toString());
}

main() {
  final libraryUri = currentMirrorSystem().findLibrary(#samples_test).uri;
  final cssDir = new Directory.fromUri(libraryUri.resolve('examples'));
  for (var element in cssDir.listSync())
    if (element is File && element.uri.pathSegments.last.endsWith('.css')) {
      test(element.uri.pathSegments.last, () => testCSSFile(element));
    }
}
