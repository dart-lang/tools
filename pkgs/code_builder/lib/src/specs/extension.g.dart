// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extension.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Extension extends Extension {
  @override
  final BuiltList<Expression> annotations;
  @override
  final BuiltList<String> docs;
  @override
  final Reference? on;
  @override
  final BuiltList<Reference> types;
  @override
  final BuiltList<Method> methods;
  @override
  final BuiltList<Field> fields;
  @override
  final String? name;

  factory _$Extension([void Function(ExtensionBuilder)? updates]) =>
      (new ExtensionBuilder()..update(updates)).build() as _$Extension;

  _$Extension._(
      {required this.annotations,
      required this.docs,
      this.on,
      required this.types,
      required this.methods,
      required this.fields,
      this.name})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        annotations, r'Extension', 'annotations');
    BuiltValueNullFieldError.checkNotNull(docs, r'Extension', 'docs');
    BuiltValueNullFieldError.checkNotNull(types, r'Extension', 'types');
    BuiltValueNullFieldError.checkNotNull(methods, r'Extension', 'methods');
    BuiltValueNullFieldError.checkNotNull(fields, r'Extension', 'fields');
  }

  @override
  Extension rebuild(void Function(ExtensionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ExtensionBuilder toBuilder() => new _$ExtensionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Extension &&
        annotations == other.annotations &&
        docs == other.docs &&
        on == other.on &&
        types == other.types &&
        methods == other.methods &&
        fields == other.fields &&
        name == other.name;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, annotations.hashCode);
    _$hash = $jc(_$hash, docs.hashCode);
    _$hash = $jc(_$hash, on.hashCode);
    _$hash = $jc(_$hash, types.hashCode);
    _$hash = $jc(_$hash, methods.hashCode);
    _$hash = $jc(_$hash, fields.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Extension')
          ..add('annotations', annotations)
          ..add('docs', docs)
          ..add('on', on)
          ..add('types', types)
          ..add('methods', methods)
          ..add('fields', fields)
          ..add('name', name))
        .toString();
  }
}

class _$ExtensionBuilder extends ExtensionBuilder {
  _$Extension? _$v;

  @override
  ListBuilder<Expression> get annotations {
    _$this;
    return super.annotations;
  }

  @override
  set annotations(ListBuilder<Expression> annotations) {
    _$this;
    super.annotations = annotations;
  }

  @override
  ListBuilder<String> get docs {
    _$this;
    return super.docs;
  }

  @override
  set docs(ListBuilder<String> docs) {
    _$this;
    super.docs = docs;
  }

  @override
  Reference? get on {
    _$this;
    return super.on;
  }

  @override
  set on(Reference? on) {
    _$this;
    super.on = on;
  }

  @override
  ListBuilder<Reference> get types {
    _$this;
    return super.types;
  }

  @override
  set types(ListBuilder<Reference> types) {
    _$this;
    super.types = types;
  }

  @override
  ListBuilder<Method> get methods {
    _$this;
    return super.methods;
  }

  @override
  set methods(ListBuilder<Method> methods) {
    _$this;
    super.methods = methods;
  }

  @override
  ListBuilder<Field> get fields {
    _$this;
    return super.fields;
  }

  @override
  set fields(ListBuilder<Field> fields) {
    _$this;
    super.fields = fields;
  }

  @override
  String? get name {
    _$this;
    return super.name;
  }

  @override
  set name(String? name) {
    _$this;
    super.name = name;
  }

  _$ExtensionBuilder() : super._();

  ExtensionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.annotations = $v.annotations.toBuilder();
      super.docs = $v.docs.toBuilder();
      super.on = $v.on;
      super.types = $v.types.toBuilder();
      super.methods = $v.methods.toBuilder();
      super.fields = $v.fields.toBuilder();
      super.name = $v.name;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Extension other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Extension;
  }

  @override
  void update(void Function(ExtensionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Extension build() => _build();

  _$Extension _build() {
    _$Extension _$result;
    try {
      _$result = _$v ??
          new _$Extension._(
              annotations: annotations.build(),
              docs: docs.build(),
              on: on,
              types: types.build(),
              methods: methods.build(),
              fields: fields.build(),
              name: name);
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'annotations';
        annotations.build();
        _$failedField = 'docs';
        docs.build();

        _$failedField = 'types';
        types.build();
        _$failedField = 'methods';
        methods.build();
        _$failedField = 'fields';
        fields.build();
      } catch (e) {
        throw new BuiltValueNestedFieldError(
            r'Extension', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
