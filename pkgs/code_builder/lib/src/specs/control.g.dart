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

class _$Condition extends Condition {
  @override
  final Expression? condition;
  @override
  final Block body;

  factory _$Condition([void Function(ConditionBuilder)? updates]) =>
      (ConditionBuilder()..update(updates)).build() as _$Condition;

  _$Condition._({this.condition, required this.body}) : super._();
  @override
  Condition rebuild(void Function(ConditionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ConditionBuilder toBuilder() => _$ConditionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Condition &&
        condition == other.condition &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, condition.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Condition')
          ..add('condition', condition)
          ..add('body', body))
        .toString();
  }
}

class _$ConditionBuilder extends ConditionBuilder {
  _$Condition? _$v;

  @override
  Expression? get condition {
    _$this;
    return super.condition;
  }

  @override
  set condition(Expression? condition) {
    _$this;
    super.condition = condition;
  }

  @override
  BlockBuilder get body {
    _$this;
    return super.body;
  }

  @override
  set body(BlockBuilder body) {
    _$this;
    super.body = body;
  }

  _$ConditionBuilder() : super._();

  ConditionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.condition = $v.condition;
      super.body = $v.body.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Condition other) {
    _$v = other as _$Condition;
  }

  @override
  void update(void Function(ConditionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Condition build() => _build();

  _$Condition _build() {
    _$Condition _$result;
    try {
      _$result = _$v ??
          _$Condition._(
            condition: condition,
            body: body.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Condition', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$IfTree extends IfTree {
  @override
  final BuiltList<Condition> blocks;

  factory _$IfTree([void Function(IfTreeBuilder)? updates]) =>
      (IfTreeBuilder()..update(updates)).build() as _$IfTree;

  _$IfTree._({required this.blocks}) : super._();
  @override
  IfTree rebuild(void Function(IfTreeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$IfTreeBuilder toBuilder() => _$IfTreeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IfTree && blocks == other.blocks;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, blocks.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IfTree')..add('blocks', blocks))
        .toString();
  }
}

class _$IfTreeBuilder extends IfTreeBuilder {
  _$IfTree? _$v;

  @override
  ListBuilder<Condition> get blocks {
    _$this;
    return super.blocks;
  }

  @override
  set blocks(ListBuilder<Condition> blocks) {
    _$this;
    super.blocks = blocks;
  }

  _$IfTreeBuilder() : super._();

  IfTreeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.blocks = $v.blocks.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IfTree other) {
    _$v = other as _$IfTree;
  }

  @override
  void update(void Function(IfTreeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IfTree build() => _build();

  _$IfTree _build() {
    IfTree._build(this);
    _$IfTree _$result;
    try {
      _$result = _$v ??
          _$IfTree._(
            blocks: blocks.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'blocks';
        blocks.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'IfTree', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$Case<T> extends Case<T> {
  @override
  final Expression pattern;
  @override
  final Expression? guard;
  @override
  final String? label;
  @override
  final T? body;

  factory _$Case([void Function(CaseBuilder<T>)? updates]) =>
      (CaseBuilder<T>()..update(updates))._build();

  _$Case._({required this.pattern, this.guard, this.label, this.body})
      : super._();
  @override
  Case<T> rebuild(void Function(CaseBuilder<T>) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CaseBuilder<T> toBuilder() => CaseBuilder<T>()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Case &&
        pattern == other.pattern &&
        guard == other.guard &&
        label == other.label &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pattern.hashCode);
    _$hash = $jc(_$hash, guard.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Case')
          ..add('pattern', pattern)
          ..add('guard', guard)
          ..add('label', label)
          ..add('body', body))
        .toString();
  }
}

class CaseBuilder<T> implements Builder<Case<T>, CaseBuilder<T>> {
  _$Case<T>? _$v;

  Expression? _pattern;
  Expression? get pattern => _$this._pattern;
  set pattern(Expression? pattern) => _$this._pattern = pattern;

  Expression? _guard;
  Expression? get guard => _$this._guard;
  set guard(Expression? guard) => _$this._guard = guard;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  T? _body;
  T? get body => _$this._body;
  set body(T? body) => _$this._body = body;

  CaseBuilder();

  CaseBuilder<T> get _$this {
    final $v = _$v;
    if ($v != null) {
      _pattern = $v.pattern;
      _guard = $v.guard;
      _label = $v.label;
      _body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Case<T> other) {
    _$v = other as _$Case<T>;
  }

  @override
  void update(void Function(CaseBuilder<T>)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Case<T> build() => _build();

  _$Case<T> _build() {
    final _$result = _$v ??
        _$Case<T>._(
          pattern: BuiltValueNullFieldError.checkNotNull(
              pattern, r'Case', 'pattern'),
          guard: guard,
          label: label,
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$SwitchStatement extends SwitchStatement {
  @override
  final Expression value;
  @override
  final BuiltList<Case<Code?>> cases;

  factory _$SwitchStatement([void Function(SwitchStatementBuilder)? updates]) =>
      (SwitchStatementBuilder()..update(updates))._build();

  _$SwitchStatement._({required this.value, required this.cases}) : super._();
  @override
  SwitchStatement rebuild(void Function(SwitchStatementBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SwitchStatementBuilder toBuilder() => SwitchStatementBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SwitchStatement &&
        value == other.value &&
        cases == other.cases;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, cases.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SwitchStatement')
          ..add('value', value)
          ..add('cases', cases))
        .toString();
  }
}

class SwitchStatementBuilder
    implements
        Builder<SwitchStatement, SwitchStatementBuilder>,
        SwitchBuilder<Code?> {
  _$SwitchStatement? _$v;

  Expression? _value;
  Expression? get value => _$this._value;
  set value(covariant Expression? value) => _$this._value = value;

  ListBuilder<Case<Code?>>? _cases;
  ListBuilder<Case<Code?>> get cases =>
      _$this._cases ??= ListBuilder<Case<Code?>>();
  set cases(covariant ListBuilder<Case<Code?>>? cases) => _$this._cases = cases;

  SwitchStatementBuilder();

  SwitchStatementBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _value = $v.value;
      _cases = $v.cases.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(covariant SwitchStatement other) {
    _$v = other as _$SwitchStatement;
  }

  @override
  void update(void Function(SwitchStatementBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SwitchStatement build() => _build();

  _$SwitchStatement _build() {
    _$SwitchStatement _$result;
    try {
      _$result = _$v ??
          _$SwitchStatement._(
            value: BuiltValueNullFieldError.checkNotNull(
                value, r'SwitchStatement', 'value'),
            cases: cases.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'cases';
        cases.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SwitchStatement', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$SwitchExpression extends SwitchExpression {
  @override
  final Expression value;
  @override
  final BuiltList<Case<Expression>> cases;

  factory _$SwitchExpression(
          [void Function(SwitchExpressionBuilder)? updates]) =>
      (SwitchExpressionBuilder()..update(updates))._build();

  _$SwitchExpression._({required this.value, required this.cases}) : super._();
  @override
  SwitchExpression rebuild(void Function(SwitchExpressionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SwitchExpressionBuilder toBuilder() =>
      SwitchExpressionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SwitchExpression &&
        value == other.value &&
        cases == other.cases;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, cases.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SwitchExpression')
          ..add('value', value)
          ..add('cases', cases))
        .toString();
  }
}

class SwitchExpressionBuilder
    implements
        Builder<SwitchExpression, SwitchExpressionBuilder>,
        SwitchBuilder<Expression> {
  _$SwitchExpression? _$v;

  Expression? _value;
  Expression? get value => _$this._value;
  set value(covariant Expression? value) => _$this._value = value;

  ListBuilder<Case<Expression>>? _cases;
  ListBuilder<Case<Expression>> get cases =>
      _$this._cases ??= ListBuilder<Case<Expression>>();
  set cases(covariant ListBuilder<Case<Expression>>? cases) =>
      _$this._cases = cases;

  SwitchExpressionBuilder();

  SwitchExpressionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _value = $v.value;
      _cases = $v.cases.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(covariant SwitchExpression other) {
    _$v = other as _$SwitchExpression;
  }

  @override
  void update(void Function(SwitchExpressionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SwitchExpression build() => _build();

  _$SwitchExpression _build() {
    _$SwitchExpression _$result;
    try {
      _$result = _$v ??
          _$SwitchExpression._(
            value: BuiltValueNullFieldError.checkNotNull(
                value, r'SwitchExpression', 'value'),
            cases: cases.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'cases';
        cases.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SwitchExpression', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$CatchBlock extends CatchBlock {
  @override
  final Reference? type;
  @override
  final String exception;
  @override
  final String? stacktrace;
  @override
  final Block body;

  factory _$CatchBlock([void Function(CatchBlockBuilder)? updates]) =>
      (CatchBlockBuilder()..update(updates))._build();

  _$CatchBlock._(
      {this.type, required this.exception, this.stacktrace, required this.body})
      : super._();
  @override
  CatchBlock rebuild(void Function(CatchBlockBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CatchBlockBuilder toBuilder() => CatchBlockBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CatchBlock &&
        type == other.type &&
        exception == other.exception &&
        stacktrace == other.stacktrace &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, exception.hashCode);
    _$hash = $jc(_$hash, stacktrace.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CatchBlock')
          ..add('type', type)
          ..add('exception', exception)
          ..add('stacktrace', stacktrace)
          ..add('body', body))
        .toString();
  }
}

class CatchBlockBuilder implements Builder<CatchBlock, CatchBlockBuilder> {
  _$CatchBlock? _$v;

  Reference? _type;
  Reference? get type => _$this._type;
  set type(Reference? type) => _$this._type = type;

  String? _exception;
  String? get exception => _$this._exception;
  set exception(String? exception) => _$this._exception = exception;

  String? _stacktrace;
  String? get stacktrace => _$this._stacktrace;
  set stacktrace(String? stacktrace) => _$this._stacktrace = stacktrace;

  BlockBuilder? _body;
  BlockBuilder get body => _$this._body ??= BlockBuilder();
  set body(BlockBuilder? body) => _$this._body = body;

  CatchBlockBuilder() {
    CatchBlock._initialize(this);
  }

  CatchBlockBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _exception = $v.exception;
      _stacktrace = $v.stacktrace;
      _body = $v.body.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CatchBlock other) {
    _$v = other as _$CatchBlock;
  }

  @override
  void update(void Function(CatchBlockBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CatchBlock build() => _build();

  _$CatchBlock _build() {
    _$CatchBlock _$result;
    try {
      _$result = _$v ??
          _$CatchBlock._(
            type: type,
            exception: BuiltValueNullFieldError.checkNotNull(
                exception, r'CatchBlock', 'exception'),
            stacktrace: stacktrace,
            body: body.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'CatchBlock', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$TryCatch extends TryCatch {
  @override
  final Block body;
  @override
  final BuiltList<CatchBlock> handlers;
  @override
  final Block? handleAll;

  factory _$TryCatch([void Function(TryCatchBuilder)? updates]) =>
      (TryCatchBuilder()..update(updates)).build() as _$TryCatch;

  _$TryCatch._({required this.body, required this.handlers, this.handleAll})
      : super._();
  @override
  TryCatch rebuild(void Function(TryCatchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$TryCatchBuilder toBuilder() => _$TryCatchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TryCatch &&
        body == other.body &&
        handlers == other.handlers &&
        handleAll == other.handleAll;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, handlers.hashCode);
    _$hash = $jc(_$hash, handleAll.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TryCatch')
          ..add('body', body)
          ..add('handlers', handlers)
          ..add('handleAll', handleAll))
        .toString();
  }
}

class _$TryCatchBuilder extends TryCatchBuilder {
  _$TryCatch? _$v;

  @override
  BlockBuilder get body {
    _$this;
    return super.body;
  }

  @override
  set body(BlockBuilder body) {
    _$this;
    super.body = body;
  }

  @override
  ListBuilder<CatchBlock> get handlers {
    _$this;
    return super.handlers;
  }

  @override
  set handlers(ListBuilder<CatchBlock> handlers) {
    _$this;
    super.handlers = handlers;
  }

  @override
  BlockBuilder get handleAll {
    _$this;
    return super.handleAll ??= BlockBuilder();
  }

  @override
  set handleAll(BlockBuilder? handleAll) {
    _$this;
    super.handleAll = handleAll;
  }

  _$TryCatchBuilder() : super._();

  TryCatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.body = $v.body.toBuilder();
      super.handlers = $v.handlers.toBuilder();
      super.handleAll = $v.handleAll?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TryCatch other) {
    _$v = other as _$TryCatch;
  }

  @override
  void update(void Function(TryCatchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TryCatch build() => _build();

  _$TryCatch _build() {
    TryCatch._build(this);
    _$TryCatch _$result;
    try {
      _$result = _$v ??
          _$TryCatch._(
            body: body.build(),
            handlers: handlers.build(),
            handleAll: super.handleAll?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'body';
        body.build();
        _$failedField = 'handlers';
        handlers.build();
        _$failedField = 'handleAll';
        super.handleAll?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'TryCatch', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
