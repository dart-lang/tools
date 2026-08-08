// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Branch extends Branch {
  @override
  final Condition condition;
  @override
  final Code? body;

  factory _$Branch([void Function(BranchBuilder)? updates]) =>
      (BranchBuilder()..update(updates)).build() as _$Branch;

  _$Branch._({required this.condition, this.body}) : super._();
  @override
  Branch rebuild(void Function(BranchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$BranchBuilder toBuilder() => _$BranchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Branch &&
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
    return (newBuiltValueToStringHelper(r'Branch')
          ..add('condition', condition)
          ..add('body', body))
        .toString();
  }
}

class _$BranchBuilder extends BranchBuilder {
  _$Branch? _$v;

  @override
  Condition? get condition {
    _$this;
    return super.condition;
  }

  @override
  set condition(Condition? condition) {
    _$this;
    super.condition = condition;
  }

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$BranchBuilder() : super._();

  BranchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.condition = $v.condition;
      super.body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Branch other) {
    _$v = other as _$Branch;
  }

  @override
  void update(void Function(BranchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Branch build() => _build();

  _$Branch _build() {
    final _$result =
        _$v ??
        _$Branch._(
          condition: BuiltValueNullFieldError.checkNotNull(
            condition,
            r'Branch',
            'condition',
          ),
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$Conditional extends Conditional {
  @override
  final BuiltList<Branch> branches;
  @override
  final Code? orElse;

  factory _$Conditional([void Function(ConditionalBuilder)? updates]) =>
      (ConditionalBuilder()..update(updates)).build() as _$Conditional;

  _$Conditional._({required this.branches, this.orElse}) : super._();
  @override
  Conditional rebuild(void Function(ConditionalBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ConditionalBuilder toBuilder() => _$ConditionalBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Conditional &&
        branches == other.branches &&
        orElse == other.orElse;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, branches.hashCode);
    _$hash = $jc(_$hash, orElse.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Conditional')
          ..add('branches', branches)
          ..add('orElse', orElse))
        .toString();
  }
}

class _$ConditionalBuilder extends ConditionalBuilder {
  _$Conditional? _$v;

  @override
  ListBuilder<Branch> get branches {
    _$this;
    return super.branches;
  }

  @override
  set branches(ListBuilder<Branch> branches) {
    _$this;
    super.branches = branches;
  }

  @override
  Code? get orElse {
    _$this;
    return super.orElse;
  }

  @override
  set orElse(Code? orElse) {
    _$this;
    super.orElse = orElse;
  }

  _$ConditionalBuilder() : super._();

  ConditionalBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.branches = $v.branches.toBuilder();
      super.orElse = $v.orElse;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Conditional other) {
    _$v = other as _$Conditional;
  }

  @override
  void update(void Function(ConditionalBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Conditional build() => _build();

  _$Conditional _build() {
    _$Conditional _$result;
    try {
      _$result =
          _$v ?? _$Conditional._(branches: branches.build(), orElse: orElse);
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'branches';
        branches.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'Conditional',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$Catch extends Catch {
  @override
  final Reference? on;
  @override
  final String? exception;
  @override
  final String? stackTrace;
  @override
  final Code? body;

  factory _$Catch([void Function(CatchBuilder)? updates]) =>
      (CatchBuilder()..update(updates)).build() as _$Catch;

  _$Catch._({this.on, this.exception, this.stackTrace, this.body}) : super._();
  @override
  Catch rebuild(void Function(CatchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$CatchBuilder toBuilder() => _$CatchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Catch &&
        on == other.on &&
        exception == other.exception &&
        stackTrace == other.stackTrace &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, on.hashCode);
    _$hash = $jc(_$hash, exception.hashCode);
    _$hash = $jc(_$hash, stackTrace.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Catch')
          ..add('on', on)
          ..add('exception', exception)
          ..add('stackTrace', stackTrace)
          ..add('body', body))
        .toString();
  }
}

class _$CatchBuilder extends CatchBuilder {
  _$Catch? _$v;

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
  String? get exception {
    _$this;
    return super.exception;
  }

  @override
  set exception(String? exception) {
    _$this;
    super.exception = exception;
  }

  @override
  String? get stackTrace {
    _$this;
    return super.stackTrace;
  }

  @override
  set stackTrace(String? stackTrace) {
    _$this;
    super.stackTrace = stackTrace;
  }

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$CatchBuilder() : super._();

  CatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.on = $v.on;
      super.exception = $v.exception;
      super.stackTrace = $v.stackTrace;
      super.body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Catch other) {
    _$v = other as _$Catch;
  }

  @override
  void update(void Function(CatchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Catch build() => _build();

  _$Catch _build() {
    final _$result =
        _$v ??
        _$Catch._(
          on: on,
          exception: exception,
          stackTrace: stackTrace,
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$Try extends Try {
  @override
  final Code? body;
  @override
  final BuiltList<Catch> catches;
  @override
  final Code? finallyBlock;

  factory _$Try([void Function(TryBuilder)? updates]) =>
      (TryBuilder()..update(updates)).build() as _$Try;

  _$Try._({this.body, required this.catches, this.finallyBlock}) : super._();
  @override
  Try rebuild(void Function(TryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$TryBuilder toBuilder() => _$TryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Try &&
        body == other.body &&
        catches == other.catches &&
        finallyBlock == other.finallyBlock;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, catches.hashCode);
    _$hash = $jc(_$hash, finallyBlock.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Try')
          ..add('body', body)
          ..add('catches', catches)
          ..add('finallyBlock', finallyBlock))
        .toString();
  }
}

class _$TryBuilder extends TryBuilder {
  _$Try? _$v;

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  @override
  ListBuilder<Catch> get catches {
    _$this;
    return super.catches;
  }

  @override
  set catches(ListBuilder<Catch> catches) {
    _$this;
    super.catches = catches;
  }

  @override
  Code? get finallyBlock {
    _$this;
    return super.finallyBlock;
  }

  @override
  set finallyBlock(Code? finallyBlock) {
    _$this;
    super.finallyBlock = finallyBlock;
  }

  _$TryBuilder() : super._();

  TryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.body = $v.body;
      super.catches = $v.catches.toBuilder();
      super.finallyBlock = $v.finallyBlock;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Try other) {
    _$v = other as _$Try;
  }

  @override
  void update(void Function(TryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Try build() => _build();

  _$Try _build() {
    _$Try _$result;
    try {
      _$result =
          _$v ??
          _$Try._(
            body: body,
            catches: catches.build(),
            finallyBlock: finallyBlock,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'catches';
        catches.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'Try', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$ForLoop extends ForLoop {
  @override
  final String? label;
  @override
  final Expression? initialize;
  @override
  final Expression? condition;
  @override
  final Expression? advance;
  @override
  final Code? body;

  factory _$ForLoop([void Function(ForLoopBuilder)? updates]) =>
      (ForLoopBuilder()..update(updates)).build() as _$ForLoop;

  _$ForLoop._({
    this.label,
    this.initialize,
    this.condition,
    this.advance,
    this.body,
  }) : super._();
  @override
  ForLoop rebuild(void Function(ForLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ForLoopBuilder toBuilder() => _$ForLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForLoop &&
        label == other.label &&
        initialize == other.initialize &&
        condition == other.condition &&
        advance == other.advance &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, initialize.hashCode);
    _$hash = $jc(_$hash, condition.hashCode);
    _$hash = $jc(_$hash, advance.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForLoop')
          ..add('label', label)
          ..add('initialize', initialize)
          ..add('condition', condition)
          ..add('advance', advance)
          ..add('body', body))
        .toString();
  }
}

class _$ForLoopBuilder extends ForLoopBuilder {
  _$ForLoop? _$v;

  @override
  String? get label {
    _$this;
    return super.label;
  }

  @override
  set label(String? label) {
    _$this;
    super.label = label;
  }

  @override
  Expression? get initialize {
    _$this;
    return super.initialize;
  }

  @override
  set initialize(Expression? initialize) {
    _$this;
    super.initialize = initialize;
  }

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
  Expression? get advance {
    _$this;
    return super.advance;
  }

  @override
  set advance(Expression? advance) {
    _$this;
    super.advance = advance;
  }

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$ForLoopBuilder() : super._();

  ForLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.label = $v.label;
      super.initialize = $v.initialize;
      super.condition = $v.condition;
      super.advance = $v.advance;
      super.body = $v.body;
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
    final _$result =
        _$v ??
        _$ForLoop._(
          label: label,
          initialize: initialize,
          condition: condition,
          advance: advance,
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$ForInLoop extends ForInLoop {
  @override
  final String? label;
  @override
  final bool async;
  @override
  final Expression variable;
  @override
  final Expression object;
  @override
  final Code? body;

  factory _$ForInLoop([void Function(ForInLoopBuilder)? updates]) =>
      (ForInLoopBuilder()..update(updates)).build() as _$ForInLoop;

  _$ForInLoop._({
    this.label,
    required this.async,
    required this.variable,
    required this.object,
    this.body,
  }) : super._();
  @override
  ForInLoop rebuild(void Function(ForInLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ForInLoopBuilder toBuilder() => _$ForInLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForInLoop &&
        label == other.label &&
        async == other.async &&
        variable == other.variable &&
        object == other.object &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, async.hashCode);
    _$hash = $jc(_$hash, variable.hashCode);
    _$hash = $jc(_$hash, object.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForInLoop')
          ..add('label', label)
          ..add('async', async)
          ..add('variable', variable)
          ..add('object', object)
          ..add('body', body))
        .toString();
  }
}

class _$ForInLoopBuilder extends ForInLoopBuilder {
  _$ForInLoop? _$v;

  @override
  String? get label {
    _$this;
    return super.label;
  }

  @override
  set label(String? label) {
    _$this;
    super.label = label;
  }

  @override
  bool get async {
    _$this;
    return super.async;
  }

  @override
  set async(bool async) {
    _$this;
    super.async = async;
  }

  @override
  Expression? get variable {
    _$this;
    return super.variable;
  }

  @override
  set variable(Expression? variable) {
    _$this;
    super.variable = variable;
  }

  @override
  Expression? get object {
    _$this;
    return super.object;
  }

  @override
  set object(Expression? object) {
    _$this;
    super.object = object;
  }

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$ForInLoopBuilder() : super._();

  ForInLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.label = $v.label;
      super.async = $v.async;
      super.variable = $v.variable;
      super.object = $v.object;
      super.body = $v.body;
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
    final _$result =
        _$v ??
        _$ForInLoop._(
          label: label,
          async: BuiltValueNullFieldError.checkNotNull(
            async,
            r'ForInLoop',
            'async',
          ),
          variable: BuiltValueNullFieldError.checkNotNull(
            variable,
            r'ForInLoop',
            'variable',
          ),
          object: BuiltValueNullFieldError.checkNotNull(
            object,
            r'ForInLoop',
            'object',
          ),
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$WhileLoop extends WhileLoop {
  @override
  final String? label;
  @override
  final bool doWhile;
  @override
  final Expression condition;
  @override
  final Code? body;

  factory _$WhileLoop([void Function(WhileLoopBuilder)? updates]) =>
      (WhileLoopBuilder()..update(updates)).build() as _$WhileLoop;

  _$WhileLoop._({
    this.label,
    required this.doWhile,
    required this.condition,
    this.body,
  }) : super._();
  @override
  WhileLoop rebuild(void Function(WhileLoopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$WhileLoopBuilder toBuilder() => _$WhileLoopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WhileLoop &&
        label == other.label &&
        doWhile == other.doWhile &&
        condition == other.condition &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, doWhile.hashCode);
    _$hash = $jc(_$hash, condition.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WhileLoop')
          ..add('label', label)
          ..add('doWhile', doWhile)
          ..add('condition', condition)
          ..add('body', body))
        .toString();
  }
}

class _$WhileLoopBuilder extends WhileLoopBuilder {
  _$WhileLoop? _$v;

  @override
  String? get label {
    _$this;
    return super.label;
  }

  @override
  set label(String? label) {
    _$this;
    super.label = label;
  }

  @override
  bool get doWhile {
    _$this;
    return super.doWhile;
  }

  @override
  set doWhile(bool doWhile) {
    _$this;
    super.doWhile = doWhile;
  }

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
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$WhileLoopBuilder() : super._();

  WhileLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.label = $v.label;
      super.doWhile = $v.doWhile;
      super.condition = $v.condition;
      super.body = $v.body;
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
    final _$result =
        _$v ??
        _$WhileLoop._(
          label: label,
          doWhile: BuiltValueNullFieldError.checkNotNull(
            doWhile,
            r'WhileLoop',
            'doWhile',
          ),
          condition: BuiltValueNullFieldError.checkNotNull(
            condition,
            r'WhileLoop',
            'condition',
          ),
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$CaseStatement extends CaseStatement {
  @override
  final String? label;
  @override
  final Pattern pattern;
  @override
  final Expression? guard;
  @override
  final Code? body;

  factory _$CaseStatement([void Function(CaseStatementBuilder)? updates]) =>
      (CaseStatementBuilder()..update(updates)).build() as _$CaseStatement;

  _$CaseStatement._({this.label, required this.pattern, this.guard, this.body})
    : super._();
  @override
  CaseStatement rebuild(void Function(CaseStatementBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$CaseStatementBuilder toBuilder() => _$CaseStatementBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CaseStatement &&
        label == other.label &&
        pattern == other.pattern &&
        guard == other.guard &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, pattern.hashCode);
    _$hash = $jc(_$hash, guard.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CaseStatement')
          ..add('label', label)
          ..add('pattern', pattern)
          ..add('guard', guard)
          ..add('body', body))
        .toString();
  }
}

class _$CaseStatementBuilder extends CaseStatementBuilder {
  _$CaseStatement? _$v;

  @override
  String? get label {
    _$this;
    return super.label;
  }

  @override
  set label(String? label) {
    _$this;
    super.label = label;
  }

  @override
  Pattern? get pattern {
    _$this;
    return super.pattern;
  }

  @override
  set pattern(Pattern? pattern) {
    _$this;
    super.pattern = pattern;
  }

  @override
  Expression? get guard {
    _$this;
    return super.guard;
  }

  @override
  set guard(Expression? guard) {
    _$this;
    super.guard = guard;
  }

  @override
  Code? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Code? body) {
    _$this;
    super.body = body;
  }

  _$CaseStatementBuilder() : super._();

  CaseStatementBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.label = $v.label;
      super.pattern = $v.pattern;
      super.guard = $v.guard;
      super.body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CaseStatement other) {
    _$v = other as _$CaseStatement;
  }

  @override
  void update(void Function(CaseStatementBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CaseStatement build() => _build();

  _$CaseStatement _build() {
    final _$result =
        _$v ??
        _$CaseStatement._(
          label: label,
          pattern: BuiltValueNullFieldError.checkNotNull(
            pattern,
            r'CaseStatement',
            'pattern',
          ),
          guard: guard,
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$SwitchStatement extends SwitchStatement {
  @override
  final String? label;
  @override
  final Expression value;
  @override
  final BuiltList<CaseStatement> cases;
  @override
  final Code? defaultCase;

  factory _$SwitchStatement([void Function(SwitchStatementBuilder)? updates]) =>
      (SwitchStatementBuilder()..update(updates)).build() as _$SwitchStatement;

  _$SwitchStatement._({
    this.label,
    required this.value,
    required this.cases,
    this.defaultCase,
  }) : super._();
  @override
  SwitchStatement rebuild(void Function(SwitchStatementBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$SwitchStatementBuilder toBuilder() =>
      _$SwitchStatementBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SwitchStatement &&
        label == other.label &&
        value == other.value &&
        cases == other.cases &&
        defaultCase == other.defaultCase;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, cases.hashCode);
    _$hash = $jc(_$hash, defaultCase.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SwitchStatement')
          ..add('label', label)
          ..add('value', value)
          ..add('cases', cases)
          ..add('defaultCase', defaultCase))
        .toString();
  }
}

class _$SwitchStatementBuilder extends SwitchStatementBuilder {
  _$SwitchStatement? _$v;

  @override
  String? get label {
    _$this;
    return super.label;
  }

  @override
  set label(String? label) {
    _$this;
    super.label = label;
  }

  @override
  Expression? get value {
    _$this;
    return super.value;
  }

  @override
  set value(Expression? value) {
    _$this;
    super.value = value;
  }

  @override
  ListBuilder<CaseStatement> get cases {
    _$this;
    return super.cases;
  }

  @override
  set cases(ListBuilder<CaseStatement> cases) {
    _$this;
    super.cases = cases;
  }

  @override
  Code? get defaultCase {
    _$this;
    return super.defaultCase;
  }

  @override
  set defaultCase(Code? defaultCase) {
    _$this;
    super.defaultCase = defaultCase;
  }

  _$SwitchStatementBuilder() : super._();

  SwitchStatementBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.label = $v.label;
      super.value = $v.value;
      super.cases = $v.cases.toBuilder();
      super.defaultCase = $v.defaultCase;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SwitchStatement other) {
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
      _$result =
          _$v ??
          _$SwitchStatement._(
            label: label,
            value: BuiltValueNullFieldError.checkNotNull(
              value,
              r'SwitchStatement',
              'value',
            ),
            cases: cases.build(),
            defaultCase: defaultCase,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'cases';
        cases.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SwitchStatement',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

class _$CaseExpression extends CaseExpression {
  @override
  final Pattern pattern;
  @override
  final Expression? guard;
  @override
  final Expression body;

  factory _$CaseExpression([void Function(CaseExpressionBuilder)? updates]) =>
      (CaseExpressionBuilder()..update(updates)).build() as _$CaseExpression;

  _$CaseExpression._({required this.pattern, this.guard, required this.body})
    : super._();
  @override
  CaseExpression rebuild(void Function(CaseExpressionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$CaseExpressionBuilder toBuilder() =>
      _$CaseExpressionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CaseExpression &&
        pattern == other.pattern &&
        guard == other.guard &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pattern.hashCode);
    _$hash = $jc(_$hash, guard.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CaseExpression')
          ..add('pattern', pattern)
          ..add('guard', guard)
          ..add('body', body))
        .toString();
  }
}

class _$CaseExpressionBuilder extends CaseExpressionBuilder {
  _$CaseExpression? _$v;

  @override
  Pattern? get pattern {
    _$this;
    return super.pattern;
  }

  @override
  set pattern(Pattern? pattern) {
    _$this;
    super.pattern = pattern;
  }

  @override
  Expression? get guard {
    _$this;
    return super.guard;
  }

  @override
  set guard(Expression? guard) {
    _$this;
    super.guard = guard;
  }

  @override
  Expression? get body {
    _$this;
    return super.body;
  }

  @override
  set body(Expression? body) {
    _$this;
    super.body = body;
  }

  _$CaseExpressionBuilder() : super._();

  CaseExpressionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.pattern = $v.pattern;
      super.guard = $v.guard;
      super.body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CaseExpression other) {
    _$v = other as _$CaseExpression;
  }

  @override
  void update(void Function(CaseExpressionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CaseExpression build() => _build();

  _$CaseExpression _build() {
    final _$result =
        _$v ??
        _$CaseExpression._(
          pattern: BuiltValueNullFieldError.checkNotNull(
            pattern,
            r'CaseExpression',
            'pattern',
          ),
          guard: guard,
          body: BuiltValueNullFieldError.checkNotNull(
            body,
            r'CaseExpression',
            'body',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

class _$SwitchExpression extends SwitchExpression {
  @override
  final Expression value;
  @override
  final BuiltList<CaseExpression> cases;

  factory _$SwitchExpression([
    void Function(SwitchExpressionBuilder)? updates,
  ]) =>
      (SwitchExpressionBuilder()..update(updates)).build()
          as _$SwitchExpression;

  _$SwitchExpression._({required this.value, required this.cases}) : super._();
  @override
  SwitchExpression rebuild(void Function(SwitchExpressionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$SwitchExpressionBuilder toBuilder() =>
      _$SwitchExpressionBuilder()..replace(this);

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

class _$SwitchExpressionBuilder extends SwitchExpressionBuilder {
  _$SwitchExpression? _$v;

  @override
  Expression? get value {
    _$this;
    return super.value;
  }

  @override
  set value(Expression? value) {
    _$this;
    super.value = value;
  }

  @override
  ListBuilder<CaseExpression> get cases {
    _$this;
    return super.cases;
  }

  @override
  set cases(ListBuilder<CaseExpression> cases) {
    _$this;
    super.cases = cases;
  }

  _$SwitchExpressionBuilder() : super._();

  SwitchExpressionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.value = $v.value;
      super.cases = $v.cases.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SwitchExpression other) {
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
      _$result =
          _$v ??
          _$SwitchExpression._(
            value: BuiltValueNullFieldError.checkNotNull(
              value,
              r'SwitchExpression',
              'value',
            ),
            cases: cases.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'cases';
        cases.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SwitchExpression',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
