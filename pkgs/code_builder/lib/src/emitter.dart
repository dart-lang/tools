// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'allocator.dart';
import 'base.dart';
import 'specs/class.dart';
import 'specs/code.dart';
import 'specs/constructor.dart';
import 'specs/directive.dart';
import 'specs/enum.dart';
import 'specs/expression.dart';
import 'specs/extension.dart';
import 'specs/extension_type.dart';
import 'specs/field.dart';
import 'specs/library.dart';
import 'specs/method.dart';
import 'specs/mixin.dart';
import 'specs/reference.dart';
import 'specs/type_function.dart';
import 'specs/type_record.dart';
import 'specs/type_reference.dart';
import 'specs/typedef.dart';
import 'visitors.dart';

/// Helper method improving on [StringSink.writeAll].
///
/// For every `Spec` in [elements], executing [visit].
///
/// If [elements] is at least 2 elements, inserts [separator] delimiting them.
StringSink visitAll<T>(
  Iterable<T> elements,
  StringSink output,
  void Function(T) visit, [
  String separator = ', ',
]) {
  // Basically, this whole method is an improvement on
  //   output.writeAll(specs.map((s) => s.accept(visitor));
  //
  // ... which would allocate more StringBuffer(s) for a one-time use.
  if (elements.isEmpty) {
    return output;
  }
  final iterator = elements.iterator..moveNext();
  visit(iterator.current);
  while (iterator.moveNext()) {
    output.write(separator);
    visit(iterator.current);
  }
  return output;
}

class DartEmitter extends Object
    with CodeEmitter, ExpressionEmitter
    implements SpecVisitor<StringSink> {
  @override
  final Allocator allocator;

  /// If directives should be ordered while emitting.
  ///
  /// Ordering rules follow the guidance in
  /// [Effective Dart](https://dart.dev/guides/language/effective-dart/style#ordering)
  /// and the
  /// [directives_ordering](https://dart-lang.github.io/linter/lints/directives_ordering.html)
  /// lint.
  final bool orderDirectives;

  /// If nullable types should be emitted with the nullable suffix ("?").
  ///
  /// Null safety syntax should only be enabled if the output will be used with
  /// a Dart language version which supports it.
  final bool _useNullSafetySyntax;

  /// Creates a new instance of [DartEmitter].
  ///
  /// May specify an [Allocator] to use for references and imports,
  /// otherwise uses [Allocator.none] which never prefixes references and will
  /// not automatically emit import directives.
  DartEmitter(
      {this.allocator = Allocator.none,
      this.orderDirectives = false,
      bool useNullSafetySyntax = false})
      : _useNullSafetySyntax = useNullSafetySyntax;

  /// Creates a new instance of [DartEmitter] with simple automatic imports.
  factory DartEmitter.scoped(
          {bool orderDirectives = false, bool useNullSafetySyntax = false}) =>
      DartEmitter(
          allocator: Allocator.simplePrefixing(),
          orderDirectives: orderDirectives,
          useNullSafetySyntax: useNullSafetySyntax);

  static bool _isLambdaBody(Code? code) =>
      code is ToCodeExpression && !code.isStatement;

  /// Whether the provided [method] is considered a lambda method.
  static bool _isLambdaMethod(Method method) =>
      method.lambda ?? _isLambdaBody(method.body);

  /// Whether the provided [constructor] is considered a lambda method.
  static bool _isLambdaConstructor(Constructor constructor) =>
      constructor.lambda ??
      constructor.factory && _isLambdaBody(constructor.body);

  @override
  StringSink visitAnnotation(Expression spec, [StringSink? output]) {
    (output ??= StringBuffer()).write('@');
    spec.accept(this, output);
    output.write(' ');
    return output;
  }

  @override
  StringSink visitClass(Class spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }

    void writeModifier() {
      if (spec.modifier != null) {
        out.write('${spec.modifier!.name} ');
      }
    }

    if (spec.sealed) {
      out.write('sealed ');
    } else {
      if (spec.abstract) {
        out.write('abstract ');
      }
      writeModifier();
      if (spec.mixin) {
        out.write('mixin ');
      }
    }
    out.write('class ${spec.name}');
    visitTypeParameters(spec.types.map((r) => r.type), out);
    if (spec.extend != null) {
      out.write(' extends ');
      spec.extend!.type.accept(this, out);
    }
    if (spec.mixins.isNotEmpty) {
      out
        ..write(' with ')
        ..writeAll(
            spec.mixins.map<StringSink>((m) => m.type.accept(this)), ',');
    }
    if (spec.implements.isNotEmpty) {
      out
        ..write(' implements ')
        ..writeAll(
            spec.implements.map<StringSink>((m) => m.type.accept(this)), ',');
    }
    out.write(' {');
    for (var c in spec.constructors) {
      visitConstructor(c, spec.name, out);
      out.writeln();
    }
    for (var f in spec.fields) {
      visitField(f, out);
      out.writeln();
    }
    for (var m in spec.methods) {
      visitMethod(m, out);
      if (_isLambdaMethod(m)) {
        out.writeln(';');
      }
      out.writeln();
    }
    out.writeln(' }');
    return out;
  }

  @override
  StringSink visitMixin(Mixin spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }

    if (spec.base) {
      out.write('base ');
    }
    out.write('mixin ${spec.name}');
    visitTypeParameters(spec.types.map((r) => r.type), out);
    if (spec.on != null) {
      out.write(' on ');
      spec.on!.type.accept(this, out);
    }
    if (spec.implements.isNotEmpty) {
      out
        ..write(' implements ')
        ..writeAll(
            spec.implements.map<StringSink>((m) => m.type.accept(this)), ',');
    }
    out.write('  {');
    for (var f in spec.fields) {
      visitField(f, out);
      out.writeln();
    }
    for (var m in spec.methods) {
      visitMethod(m, out);
      if (_isLambdaMethod(m)) {
        out.write(';');
      }
      out.writeln();
    }
    out.write('  }');
    return out;
  }

  @override
  StringSink visitConstructor(Constructor spec, String clazz,
      [StringSink? output]) {
    output ??= StringBuffer();
    spec.docs.forEach(output.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, output);
    }
    if (spec.external) {
      output.write('external ');
    }
    if (spec.constant) {
      output.write('const ');
    }
    if (spec.factory) {
      output.write('factory ');
    }
    output.write(clazz);
    if (spec.name != null) {
      output
        ..write('.')
        ..write(spec.name);
    }
    output.write('(');
    final hasMultipleParameters =
        spec.requiredParameters.length + spec.optionalParameters.length > 1;
    if (spec.requiredParameters.isNotEmpty) {
      var count = 0;
      for (final p in spec.requiredParameters) {
        count++;
        _visitParameter(p, output);
        if (hasMultipleParameters ||
            spec.requiredParameters.length != count ||
            spec.optionalParameters.isNotEmpty) {
          output.write(', ');
        }
      }
    }
    if (spec.optionalParameters.isNotEmpty) {
      final named = spec.optionalParameters.any((p) => p.named);
      if (named) {
        output.write('{');
      } else {
        output.write('[');
      }
      var count = 0;
      for (final p in spec.optionalParameters) {
        count++;
        _visitParameter(p, output, optional: true, named: named);
        if (hasMultipleParameters || spec.optionalParameters.length != count) {
          output.write(', ');
        }
      }
      if (named) {
        output.write('}');
      } else {
        output.write(']');
      }
    }
    output.write(')');
    if (spec.initializers.isNotEmpty) {
      output.write(' : ');
      var count = 0;
      for (final initializer in spec.initializers) {
        count++;
        initializer.accept(this, output);
        if (count != spec.initializers.length) {
          output.write(', ');
        }
      }
    }
    if (spec.redirect != null) {
      output.write(' = ');
      spec.redirect!.type.accept(this, output);
      output.write(';');
    } else if (spec.body != null) {
      if (_isLambdaConstructor(spec)) {
        output.write(' => ');
        spec.body!.accept(this, output);
        output.write(';');
      } else {
        output.write(' { ');
        spec.body!.accept(this, output);
        output.write(' }');
      }
    } else {
      output.write(';');
    }
    output.writeln();
    return output;
  }

  @override
  StringSink visitExtension(Extension spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }

    out.write('extension');
    if (spec.name != null) {
      out.write(' ${spec.name}');
    }
    visitTypeParameters(spec.types.map((r) => r.type), out);
    if (spec.on != null) {
      out.write(' on ');
      spec.on!.type.accept(this, out);
    }
    out.write(' {');
    for (var f in spec.fields) {
      visitField(f, out);
      out.writeln();
    }
    for (var m in spec.methods) {
      visitMethod(m, out);
      if (_isLambdaMethod(m)) {
        out.write(';');
      }
      out.writeln();
    }
    out.writeln(' }');
    return out;
  }

  @override
  StringSink visitExtensionType(ExtensionType spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }

    out.write('extension type ');
    if (spec.constant) out.write('const ');
    out.write(spec.name);
    visitTypeParameters(spec.types.map((r) => r.type), out);
    if (spec.primaryConstructorName.isNotEmpty) {
      out.write('.${spec.primaryConstructorName}');
    }
    out.write('(');
    _visitRepresentationDeclaration(spec.representationDeclaration, out);
    out.write(')');

    if (spec.implements.isNotEmpty) {
      out
        ..write(' implements ')
        ..writeAll(
            spec.implements.map<StringSink>((m) => m.type.accept(this)), ',');
    }

    out.writeln(' {');
    for (var c in spec.constructors) {
      visitConstructor(c, spec.name, out);
      out.writeln();
    }
    for (var f in spec.fields) {
      visitField(f, out);
      out.writeln();
    }
    for (var m in spec.methods) {
      visitMethod(m, out);
      if (_isLambdaMethod(m)) {
        out.writeln(';');
      }
      out.writeln();
    }
    out.writeln('}');
    return out;
  }

  void _visitRepresentationDeclaration(
      RepresentationDeclaration spec, StringSink out) {
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }
    spec.declaredRepresentationType.accept(this, out);
    out.write(' ${spec.name}');
  }

  @override
  StringSink visitDirective(Directive spec, [StringSink? output]) {
    output ??= StringBuffer();
    switch (spec.type) {
      case DirectiveType.import:
        output.write('import ');
        break;
      case DirectiveType.export:
        output.write('export ');
        break;
      case DirectiveType.part:
        output.write('part ');
        break;
      case DirectiveType.partOf:
        output.write('part of ');
        break;
    }
    output.write("'${spec.url}'");
    if (spec.as != null) {
      if (spec.deferred) {
        output.write(' deferred ');
      }
      output.write(' as ${spec.as}');
    }
    if (spec.show.isNotEmpty) {
      output
        ..write(' show ')
        ..writeAll(spec.show, ', ');
    } else if (spec.hide.isNotEmpty) {
      output
        ..write(' hide ')
        ..writeAll(spec.hide, ', ');
    }
    output.write(';');
    return output;
  }

  @override
  StringSink visitField(Field spec, [StringSink? output]) {
    output ??= StringBuffer();
    spec.docs.forEach(output.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, output);
    }
    if (spec.static) {
      output.write('static ');
    }
    if (spec.late && _useNullSafetySyntax) {
      output.write('late ');
    }
    if (spec.external) {
      output.write('external ');
    }
    switch (spec.modifier) {
      case FieldModifier.var$:
        if (spec.type == null) {
          output.write('var ');
        }
        break;
      case FieldModifier.final$:
        output.write('final ');
        break;
      case FieldModifier.constant:
        output.write('const ');
        break;
    }
    if (spec.type != null) {
      spec.type!.type.accept(this, output);
      output.write(' ');
    }
    output.write(spec.name);
    if (spec.assignment != null) {
      output.write(' = ');
      startConstCode(spec.modifier == FieldModifier.constant, () {
        spec.assignment!.accept(this, output);
      });
    }
    output.writeln(';');
    return output;
  }

  @override
  StringSink visitLibrary(Library spec, [StringSink? output]) {
    output ??= StringBuffer();

    if (spec.comments.isNotEmpty) {
      spec.comments.map((line) => '// $line').forEach(output.writeln);
      output.writeln();
    }

    if (spec.generatedByComment != null) {
      output
        ..writeln('// ${spec.generatedByComment}')
        ..writeln();
    }

    if (spec.ignoreForFile.isNotEmpty) {
      final ignores = spec.ignoreForFile.toList()..sort();
      final lines = ['// ignore_for_file: ${ignores.first}'];
      for (var ignore in ignores.skip(1)) {
        if (lines.last.length + 2 + ignore.length > 80) {
          lines.add('// ignore_for_file: $ignore');
        } else {
          lines[lines.length - 1] = '${lines.last}, $ignore';
        }
      }
      lines.forEach(output.writeln);
      output.writeln();
    }

    // Process the body first in order to prime the allocators.
    final body = StringBuffer();
    for (final spec in spec.body) {
      spec.accept(this, body);
      if (spec is Method && _isLambdaMethod(spec)) {
        body.write(';');
      }
    }

    spec.docs.forEach(output.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, output);
    }
    if (spec.name != null) {
      output.write('library ${spec.name!};');
    } else if (spec.annotations.isNotEmpty || spec.docs.isNotEmpty) {
      // An explicit _unnamed_ library directive is only required if there are
      // annotations or doc comments on the library.
      output.write('library;');
    }

    final directives = <Directive>[...allocator.imports, ...spec.directives];

    if (orderDirectives) {
      directives.sort();
    }

    Directive? previous;
    if (directives.any((d) => d.as?.startsWith('_') ?? false)) {
      output.writeln(
          '// ignore_for_file: no_leading_underscores_for_library_prefixes');
    }
    for (final directive in directives) {
      if (_newLineBetween(orderDirectives, previous, directive)) {
        // Note: dartfmt handles creating new lines between directives.
        // 2 lines are written here. The first one comes after the previous
        // directive `;`, the second is the empty line.
        output
          ..writeln()
          ..writeln();
      }
      directive.accept(this, output);
      previous = directive;
    }
    output.write(body);
    return output;
  }

  @override
  StringSink visitFunctionType(FunctionType spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    if (spec.returnType != null) {
      spec.returnType!.accept(this, out);
      out.write(' ');
    }
    out.write('Function');
    if (spec.types.isNotEmpty) {
      out.write('<');
      visitAll<Reference>(spec.types, out, (spec) {
        spec.accept(this, out);
      });
      out.write('>');
    }
    out.write('(');
    final needsTrailingComma = spec.requiredParameters.length +
            spec.optionalParameters.length +
            spec.namedRequiredParameters.length +
            spec.namedParameters.length >
        1;
    visitAll<Reference>(spec.requiredParameters, out, (spec) {
      spec.accept(this, out);
    });
    final hasNamedParameters = spec.namedRequiredParameters.isNotEmpty ||
        spec.namedParameters.isNotEmpty;
    if (spec.requiredParameters.isNotEmpty &&
        (needsTrailingComma ||
            spec.optionalParameters.isNotEmpty ||
            hasNamedParameters)) {
      out.write(', ');
    }
    if (spec.optionalParameters.isNotEmpty) {
      out.write('[');
      visitAll<Reference>(spec.optionalParameters, out, (spec) {
        spec.accept(this, out);
      });
      if (needsTrailingComma) {
        out.write(', ');
      }
      out.write(']');
    } else if (hasNamedParameters) {
      out.write('{');
      visitAll<String>(spec.namedRequiredParameters.keys, out, (name) {
        out.write('required ');
        spec.namedRequiredParameters[name]!.accept(this, out);
        out
          ..write(' ')
          ..write(name);
      });
      if (spec.namedRequiredParameters.isNotEmpty &&
          spec.namedParameters.isNotEmpty) {
        out.write(', ');
      }
      visitAll<String>(spec.namedParameters.keys, out, (name) {
        spec.namedParameters[name]!.accept(this, out);
        out
          ..write(' ')
          ..write(name);
      });
      if (needsTrailingComma) {
        out.write(', ');
      }
      out.write('}');
    }
    out.write(')');
    if (_useNullSafetySyntax && (spec.isNullable ?? false)) {
      out.write('?');
    }
    return out;
  }

  @override
  StringSink visitRecordType(RecordType spec, [StringSink? output]) {
    final out = (output ??= StringBuffer())..write('(');
    visitAll<Reference>(spec.positionalFieldTypes, out, (spec) {
      spec.accept(this, out);
    });
    if (spec.namedFieldTypes.isNotEmpty) {
      if (spec.positionalFieldTypes.isNotEmpty) {
        out.write(', ');
      }
      out.write('{');
      visitAll<MapEntry<String, Reference>>(spec.namedFieldTypes.entries, out,
          (entry) {
        entry.value.accept(this, out);
        out.write(' ${entry.key}');
      });
      out.write('}');
    } else if (spec.positionalFieldTypes.length == 1) {
      out.write(',');
    }
    out.write(')');
    // It doesn't really make sense to use records without
    // `_useNullSafetySyntax`, but since code_builder is generally very
    // permissive, follow it here too.
    if (_useNullSafetySyntax && (spec.isNullable ?? false)) {
      out.write('?');
    }
    return out;
  }

  @override
  StringSink visitTypeDef(TypeDef spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }
    out.write('typedef ${spec.name}');
    visitTypeParameters(spec.types.map((r) => r.type), out);
    out.write(' = ');
    spec.definition.accept(this, out);
    out.writeln(';');
    return out;
  }

  @override
  StringSink visitMethod(Method spec, [StringSink? output]) {
    output ??= StringBuffer();
    spec.docs.forEach(output.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, output);
    }
    if (spec.external) {
      output.write('external ');
    }
    if (spec.static) {
      output.write('static ');
    }
    if (spec.returns != null) {
      spec.returns!.accept(this, output);
      output.write(' ');
    }
    if (spec.type == MethodType.getter) {
      output
        ..write('get ')
        ..write(spec.name);
    } else {
      if (spec.type == MethodType.setter) {
        output.write('set ');
      }
      if (spec.name != null) {
        output.write(spec.name);
      }
      visitTypeParameters(spec.types.map((r) => r.type), output);
      output.write('(');
      final hasMultipleParameters =
          spec.requiredParameters.length + spec.optionalParameters.length > 1;
      if (spec.requiredParameters.isNotEmpty) {
        var count = 0;
        for (final p in spec.requiredParameters) {
          count++;
          _visitParameter(p, output);
          if (hasMultipleParameters ||
              spec.requiredParameters.length != count ||
              spec.optionalParameters.isNotEmpty) {
            output.write(', ');
          }
        }
      }
      if (spec.optionalParameters.isNotEmpty) {
        final named = spec.optionalParameters.any((p) => p.named);
        if (named) {
          output.write('{');
        } else {
          output.write('[');
        }
        var count = 0;
        for (final p in spec.optionalParameters) {
          count++;
          _visitParameter(p, output, optional: true, named: named);
          if (hasMultipleParameters ||
              spec.optionalParameters.length != count) {
            output.write(', ');
          }
        }
        if (named) {
          output.write('}');
        } else {
          output.write(']');
        }
      }
      output.write(')');
    }
    if (spec.body != null) {
      if (spec.modifier != null) {
        switch (spec.modifier!) {
          case MethodModifier.async:
            output.write(' async ');
            break;
          case MethodModifier.asyncStar:
            output.write(' async* ');
            break;
          case MethodModifier.syncStar:
            output.write(' sync* ');
            break;
        }
      }
      if (_isLambdaMethod(spec)) {
        output.write(' => ');
      } else {
        output.write(' { ');
      }
      spec.body!.accept(this, output);
      if (!_isLambdaMethod(spec)) {
        output.write(' } ');
      }
    } else {
      output.write(';');
    }
    return output;
  }

  // Expose as a first-class visit function only if needed.
  void _visitParameter(
    Parameter spec,
    StringSink output, {
    bool optional = false,
    bool named = false,
  }) {
    spec.docs.forEach(output.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, output);
    }
    // The `required` keyword must precede the `covariant` keyword.
    if (spec.required) {
      output.write('required ');
    }
    if (spec.covariant) {
      output.write('covariant ');
    }
    if (spec.type != null) {
      spec.type!.type.accept(this, output);
      output.write(' ');
    }
    if (spec.toThis) {
      output.write('this.');
    }
    if (spec.toSuper) {
      output.write('super.');
    }
    output.write(spec.name);
    if (optional && spec.defaultTo != null) {
      output.write(' = ');
      spec.defaultTo!.accept(this, output);
    }
  }

  @override
  StringSink visitReference(Reference spec, [StringSink? output]) =>
      (output ??= StringBuffer())..write(allocator.allocate(spec));

  @override
  StringSink visitSpec(Spec spec, [StringSink? output]) =>
      spec.accept(this, output);

  @override
  StringSink visitType(TypeReference spec, [StringSink? output]) {
    output ??= StringBuffer();
    // Intentionally not .accept to avoid stack overflow.
    visitReference(spec, output);
    if (spec.bound != null) {
      output.write(' extends ');
      spec.bound!.type.accept(this, output);
    }
    visitTypeParameters(spec.types.map((r) => r.type), output);
    if (_useNullSafetySyntax && (spec.isNullable ?? false)) {
      output.write('?');
    }
    return output;
  }

  @override
  StringSink visitTypeParameters(Iterable<Reference> specs,
      [StringSink? output]) {
    output ??= StringBuffer();
    if (specs.isNotEmpty) {
      output
        ..write('<')
        ..writeAll(specs.map<StringSink>((s) => s.accept(this)), ',')
        ..write('>');
    }
    return output;
  }

  @override
  StringSink visitEnum(Enum spec, [StringSink? output]) {
    final out = output ??= StringBuffer();
    spec.docs.forEach(out.writeln);
    for (var a in spec.annotations) {
      visitAnnotation(a, out);
    }
    out.write('enum ${spec.name}');
    visitTypeParameters(spec.types.map((r) => r.type), out);
    if (spec.mixins.isNotEmpty) {
      out
        ..write(' with ')
        ..writeAll(
            spec.mixins.map<StringSink>((m) => m.type.accept(this)), ', ');
    }
    if (spec.implements.isNotEmpty) {
      out
        ..write(' implements ')
        ..writeAll(
            spec.implements.map<StringSink>((m) => m.type.accept(this)), ', ');
    }
    out.write(' { ');
    for (var v in spec.values) {
      v.docs.forEach(out.writeln);
      for (var a in v.annotations) {
        visitAnnotation(a, out);
      }
      out.write(v.name);
      if (v.constructorName != null) {
        out.write('.${v.constructorName}');
      }
      visitTypeParameters(v.types.map((r) => r.type), out);
      final takesArguments = v.constructorName != null ||
          v.arguments.isNotEmpty ||
          v.namedArguments.isNotEmpty;
      if (takesArguments) {
        out.write('(');
      }
      if (v.arguments.isNotEmpty) {
        out.writeAll(
            v.arguments.map<StringSink>((arg) => arg.accept(this)), ', ');
      }
      if (v.arguments.isNotEmpty && v.namedArguments.isNotEmpty) {
        out.write(', ');
      }
      visitAll<String>(v.namedArguments.keys, out, (name) {
        out
          ..write(name)
          ..write(': ');
        v.namedArguments[name]!.accept(this, out);
      });
      if (takesArguments) {
        out.write(')');
      }
      if (v != spec.values.last) {
        out.writeln(',');
      } else if (spec.constructors.isNotEmpty ||
          spec.fields.isNotEmpty ||
          spec.methods.isNotEmpty) {
        out.writeln(';');
      }
    }
    for (var c in spec.constructors) {
      visitConstructor(c, spec.name, out);
      out.writeln();
    }
    for (var f in spec.fields) {
      visitField(f, out);
      out.writeln();
    }
    for (var m in spec.methods) {
      visitMethod(m, out);
      if (_isLambdaMethod(m)) {
        out.write(';');
      }
      out.writeln();
    }
    out.writeln(' }');
    return out;
  }
}

/// Returns `true` if:
///
/// * [ordered] is `true`
/// * [a] is non-`null`
/// * If there should be an empty line before [b] if it's emitted after [a].
bool _newLineBetween(bool ordered, Directive? a, Directive? b) {
  if (!ordered) return false;
  if (a == null) return false;

  assert(b != null);

  // Put a line between imports and exports
  if (a.type != b!.type) return true;

  // Within exports, don't put in extra blank lines
  if (a.type == DirectiveType.export) {
    assert(b.type == DirectiveType.export);
    return false;
  }

  // Return `true` if the schemes for [a] and [b] are different
  return !Uri.parse(a.url).isScheme(Uri.parse(b.url).scheme);
}
