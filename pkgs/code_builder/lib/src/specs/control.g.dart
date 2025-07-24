// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ForLoop extends ForLoop {
  @override
  final Expression? initialize;
  @override
  final Expression? condition;
  @override
  final Expression? advance;
  @override
  final Block body;
  @override
  final String? label;

  factory _$ForLoop([void Function(ForLoopBuilder)? updates]) =>
      (ForLoopBuilder()..update(updates))._build();

  _$ForLoop._(
      {this.initialize,
      this.condition,
      this.advance,
      required this.body,
      this.label})
      : super._();
  @override
  ForLoop rebuild(void Function(ForLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ForLoopBuilder toBuilder() => ForLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForLoop &&
        initialize == other.initialize &&
        condition == other.condition &&
        advance == other.advance &&
        body == other.body &&
        label == other.label;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, initialize.hashCode);
    _$hash = $jc(_$hash, condition.hashCode);
    _$hash = $jc(_$hash, advance.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForLoop')
          ..add('initialize', initialize)
          ..add('condition', condition)
          ..add('advance', advance)
          ..add('body', body)
          ..add('label', label))
        .toString();
  }
}

class ForLoopBuilder implements Builder<ForLoop, ForLoopBuilder> {
  _$ForLoop? _$v;

  Expression? _initialize;
  Expression? get initialize => _$this._initialize;
  set initialize(Expression? initialize) => _$this._initialize = initialize;

  Expression? _condition;
  Expression? get condition => _$this._condition;
  set condition(Expression? condition) => _$this._condition = condition;

  Expression? _advance;
  Expression? get advance => _$this._advance;
  set advance(Expression? advance) => _$this._advance = advance;

  BlockBuilder? _body;
  BlockBuilder get body => _$this._body ??= BlockBuilder();
  set body(BlockBuilder? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  ForLoopBuilder();

  ForLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _initialize = $v.initialize;
      _condition = $v.condition;
      _advance = $v.advance;
      _body = $v.body.toBuilder();
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ForLoop other) {
    _$v = other as _$ForLoop;
  }

  @override
  void update(void Function(ForLoopBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ForLoop build() => _build();

  _$ForLoop _build() {
    _$ForLoop _$result;
    try {
      _$result = _$v ??
          _$ForLoop._(
            initialize: initialize,
            condition: condition,
            advance: advance,
            body: body.build(),
            label: label,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ForLoop', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$ForInLoop extends ForInLoop {
  @override
  final bool? async;
  @override
  final Expression variable;
  @override
  final Expression object;
  @override
  final Block body;
  @override
  final String? label;

  factory _$ForInLoop([void Function(ForInLoopBuilder)? updates]) =>
      (ForInLoopBuilder()..update(updates))._build();

  _$ForInLoop._(
      {this.async,
      required this.variable,
      required this.object,
      required this.body,
      this.label})
      : super._();
  @override
  ForInLoop rebuild(void Function(ForInLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ForInLoopBuilder toBuilder() => ForInLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForInLoop &&
        async == other.async &&
        variable == other.variable &&
        object == other.object &&
        body == other.body &&
        label == other.label;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, async.hashCode);
    _$hash = $jc(_$hash, variable.hashCode);
    _$hash = $jc(_$hash, object.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForInLoop')
          ..add('async', async)
          ..add('variable', variable)
          ..add('object', object)
          ..add('body', body)
          ..add('label', label))
        .toString();
  }
}

class ForInLoopBuilder implements Builder<ForInLoop, ForInLoopBuilder> {
  _$ForInLoop? _$v;

  bool? _async;
  bool? get async => _$this._async;
  set async(bool? async) => _$this._async = async;

  Expression? _variable;
  Expression? get variable => _$this._variable;
  set variable(Expression? variable) => _$this._variable = variable;

  Expression? _object;
  Expression? get object => _$this._object;
  set object(Expression? object) => _$this._object = object;

  BlockBuilder? _body;
  BlockBuilder get body => _$this._body ??= BlockBuilder();
  set body(BlockBuilder? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  ForInLoopBuilder();

  ForInLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _async = $v.async;
      _variable = $v.variable;
      _object = $v.object;
      _body = $v.body.toBuilder();
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ForInLoop other) {
    _$v = other as _$ForInLoop;
  }

  @override
  void update(void Function(ForInLoopBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ForInLoop build() => _build();

  _$ForInLoop _build() {
    _$ForInLoop _$result;
    try {
      _$result = _$v ??
          _$ForInLoop._(
            async: async,
            variable: BuiltValueNullFieldError.checkNotNull(
                variable, r'ForInLoop', 'variable'),
            object: BuiltValueNullFieldError.checkNotNull(
                object, r'ForInLoop', 'object'),
            body: body.build(),
            label: label,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ForInLoop', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$WhileLoop extends WhileLoop {
  @override
  final bool? doWhile;
  @override
  final Expression condition;
  @override
  final Block body;
  @override
  final String? label;

  factory _$WhileLoop([void Function(WhileLoopBuilder)? updates]) =>
      (WhileLoopBuilder()..update(updates))._build();

  _$WhileLoop._(
      {this.doWhile, required this.condition, required this.body, this.label})
      : super._();
  @override
  WhileLoop rebuild(void Function(WhileLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  WhileLoopBuilder toBuilder() => WhileLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WhileLoop &&
        doWhile == other.doWhile &&
        condition == other.condition &&
        body == other.body &&
        label == other.label;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, doWhile.hashCode);
    _$hash = $jc(_$hash, condition.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WhileLoop')
          ..add('doWhile', doWhile)
          ..add('condition', condition)
          ..add('body', body)
          ..add('label', label))
        .toString();
  }
}

class WhileLoopBuilder implements Builder<WhileLoop, WhileLoopBuilder> {
  _$WhileLoop? _$v;

  bool? _doWhile;
  bool? get doWhile => _$this._doWhile;
  set doWhile(bool? doWhile) => _$this._doWhile = doWhile;

  Expression? _condition;
  Expression? get condition => _$this._condition;
  set condition(Expression? condition) => _$this._condition = condition;

  BlockBuilder? _body;
  BlockBuilder get body => _$this._body ??= BlockBuilder();
  set body(BlockBuilder? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  WhileLoopBuilder();

  WhileLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _doWhile = $v.doWhile;
      _condition = $v.condition;
      _body = $v.body.toBuilder();
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(WhileLoop other) {
    _$v = other as _$WhileLoop;
  }

  @override
  void update(void Function(WhileLoopBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WhileLoop build() => _build();

  _$WhileLoop _build() {
    _$WhileLoop _$result;
    try {
      _$result = _$v ??
          _$WhileLoop._(
            doWhile: doWhile,
            condition: BuiltValueNullFieldError.checkNotNull(
                condition, r'WhileLoop', 'condition'),
            body: body.build(),
            label: label,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'WhileLoop', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
