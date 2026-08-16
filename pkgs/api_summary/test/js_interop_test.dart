// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'dart:core';

import 'package:api_summary/api_summary.dart';
import 'package:api_summary/src/api_builder.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_utils.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(JsInteropTest);
  });
}

@reflectiveTest
class JsInteropTest extends ApiSummaryTest {
  Future<ApiSummary> _buildModel(Map<String, String> files) async {
    files.forEach(newFile);
    for (final file in files.keys) {
      if (file.endsWith('.dart')) await assertNoDiagnosticsInFile(file);
    }
    final context = contextCollection.contextFor(
      convertPath(testPackageLibPath),
    );
    return buildApiPackage('test', context, const ApiSummaryCustomizer());
  }

  Future<void> test_js_interop_members_and_extension_types() async {
    final model = await _buildModel({
      '$testPackageLibPath/interop.dart': '''
import 'dart:js_interop';

class JSExport {
  final String? name;
  const JSExport([this.name]);
}

@JS()
extension type Window(JSObject _) implements JSObject {
  @JS('document')
  external Document get doc;

  @JS('alert')
  external void showAlert(String message);
}

@JS('CustomDoc')
extension type Document(JSObject _) implements JSObject {
  @JS()
  external String get title;
}

@JS('globalFunc')
external void performAction();

@JSExport()
class ExportedService {
  @JSExport('customCompute')
  int computeValue() => 42;
}
''',
    });

    final text = model.toString();
    expect(text, contains('Window (extension type implements JSObject, js):'));
    expect(text, contains('doc (getter: Document, js: "document")'));
    expect(
      text,
      contains('showAlert (method: void Function(String), js: "alert")'),
    );
    expect(
      text,
      contains(
        'Document (extension type implements JSObject, js: "CustomDoc"):',
      ),
    );
    expect(text, contains('title (getter: String, js)'));
    expect(
      text,
      contains('performAction (function: void Function(), js: "globalFunc")'),
    );
    expect(text, contains('ExportedService (class extends Object, jsExport):'));
    expect(
      text,
      contains(
        'computeValue (method: int Function(), jsExport: "customCompute")',
      ),
    );

    // Verify JSON round-trip
    final json = model.toJson();
    final rehydrated = ApiSummary.fromJson(json);
    expect(rehydrated.toString(), equals(text));

    final lib = rehydrated.libraries.single;
    final windowExt = lib.extensionTypes.singleWhere((e) => e.name == 'Window');
    expect(windowExt.hasJsBinding, isTrue);
    expect(windowExt.jsBindingName, isNull);

    final docGetter = windowExt.methods.singleWhere((m) => m.name == 'doc');
    expect(docGetter.hasJsBinding, isTrue);
    expect(docGetter.jsBindingName, 'document');

    final exportedClass = lib.classes.singleWhere(
      (c) => c.name == 'ExportedService',
    );
    expect(exportedClass.hasJsExport, isTrue);
    expect(exportedClass.jsExportName, isNull);

    final computeMethod = exportedClass.methods.singleWhere(
      (m) => m.name == 'computeValue',
    );
    expect(computeMethod.hasJsExport, isTrue);
    expect(computeMethod.jsExportName, 'customCompute');
  }

  Future<void> test_library_js_annotation() async {
    final model = await _buildModel({
      '$testPackageLibPath/browser.dart': '''
@JS('DOM')
library;

import 'dart:js_interop';

@JS('Element')
extension type Element(JSObject _) implements JSObject {}
''',
    });

    final text = model.toString();
    expect(text, contains('package:test/browser.dart (js: "DOM"):'));
    expect(
      text,
      contains('Element (extension type implements JSObject, js: "Element"):'),
    );

    final json = model.toJson();
    final rehydrated = ApiSummary.fromJson(json);
    expect(rehydrated.toString(), equals(text));

    final lib = rehydrated.libraries.single;
    final trait = lib.traits.whereType<JsBindingTrait>().single;
    expect(trait.name, 'DOM');
  }

  void test_js_traits_sorting_equality_and_deduplication() {
    const js1 = JsBindingTrait('foo');
    const js2 = JsBindingTrait('foo');
    const js3 = JsBindingTrait('bar');
    const jsExport1 = JsExportTrait('compute');
    const jsExport2 = JsExportTrait('compute');
    final meta = MetaContractTrait([MetaContract.protected]);

    // Equality & Hash code
    expect(js1, equals(js2));
    expect(js1.hashCode, equals(js2.hashCode));
    expect(js1, isNot(equals(js3)));
    expect(jsExport1, equals(jsExport2));

    // Comparable sorting: 'js' < 'js_export' < 'meta', and within 'js':
    // 'bar' < 'foo'.
    final unsorted = [meta, js1, jsExport1, js3, js2];
    final sorted = unsorted.toSet().toList()..sort();
    expect(
      sorted,
      equals([
        js3, // js: "bar"
        js1, // js: "foo"
        jsExport1, // js_export: "compute"
        meta, // meta: protected
      ]),
    );

    // ApiDeclaration deduplication and sorting
    final exec = ApiExecutable(
      name: 'testFunc',
      kind: ApiExecutableKind.function,
      typeParameters: const {},
      returnType: const ApiVoidType(),
      parameters: const [],
      isStatic: true,
      traits: [meta, js1, jsExport1, js2, js1],
    );

    expect(exec.traits.toList(), equals([js1, jsExport1, meta]));
    expect(() => (exec.traits as dynamic).add(js3), throwsUnsupportedError);
  }
}
