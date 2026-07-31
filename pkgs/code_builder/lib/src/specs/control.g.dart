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
  final Code? body;
  @override
  final String? label;

  factory _$ForLoop([void Function(ForLoopBuilder)? updates]) =>
      (ForLoopBuilder()..update(updates))._build();

  _$ForLoop._({
    this.initialize,
    this.condition,
    this.advance,
    this.body,
    this.label,
  }) : super._();
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

class ForLoopBuilder
    with ControlBodyBuilder, ControlLabelBuilder
    implements Builder<ForLoop, ForLoopBuilder> {
  _$ForLoop? _$v;

  Expression? _initialize;
  Expression? get initialize => _$this._initialize;
  set initialize(covariant Expression? initialize) =>
      _$this._initialize = initialize;

  Expression? _condition;
  Expression? get condition => _$this._condition;
  set condition(covariant Expression? condition) =>
      _$this._condition = condition;

  Expression? _advance;
  Expression? get advance => _$this._advance;
  set advance(covariant Expression? advance) => _$this._advance = advance;

  Code? _body;
  Code? get body => _$this._body;
  set body(covariant Code? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(covariant String? label) => _$this._label = label;

  ForLoopBuilder();

  ForLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _initialize = $v.initialize;
      _condition = $v.condition;
      _advance = $v.advance;
      _body = $v.body;
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  // ignore: override_on_non_overriding_method
  void replace(covariant ForLoop other) {
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
          initialize: initialize,
          condition: condition,
          advance: advance,
          body: body,
          label: label,
        );
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
  final Code? body;
  @override
  final String? label;

  factory _$ForInLoop([void Function(ForInLoopBuilder)? updates]) =>
      (ForInLoopBuilder()..update(updates))._build();

  _$ForInLoop._({
    this.async,
    required this.variable,
    required this.object,
    this.body,
    this.label,
  }) : super._();
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

class ForInLoopBuilder
    with ControlBodyBuilder, ControlLabelBuilder
    implements Builder<ForInLoop, ForInLoopBuilder> {
  _$ForInLoop? _$v;

  bool? _async;
  bool? get async => _$this._async;
  set async(covariant bool? async) => _$this._async = async;

  Expression? _variable;
  Expression? get variable => _$this._variable;
  set variable(covariant Expression? variable) => _$this._variable = variable;

  Expression? _object;
  Expression? get object => _$this._object;
  set object(covariant Expression? object) => _$this._object = object;

  Code? _body;
  Code? get body => _$this._body;
  set body(covariant Code? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(covariant String? label) => _$this._label = label;

  ForInLoopBuilder();

  ForInLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _async = $v.async;
      _variable = $v.variable;
      _object = $v.object;
      _body = $v.body;
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  // ignore: override_on_non_overriding_method
  void replace(covariant ForInLoop other) {
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
          async: async,
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
          label: label,
        );
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
  final Code? body;
  @override
  final String? label;

  factory _$WhileLoop([void Function(WhileLoopBuilder)? updates]) =>
      (WhileLoopBuilder()..update(updates))._build();

  _$WhileLoop._({this.doWhile, required this.condition, this.body, this.label})
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

class WhileLoopBuilder
    with ControlBodyBuilder, ControlLabelBuilder
    implements Builder<WhileLoop, WhileLoopBuilder> {
  _$WhileLoop? _$v;

  bool? _doWhile;
  bool? get doWhile => _$this._doWhile;
  set doWhile(covariant bool? doWhile) => _$this._doWhile = doWhile;

  Expression? _condition;
  Expression? get condition => _$this._condition;
  set condition(covariant Expression? condition) =>
      _$this._condition = condition;

  Code? _body;
  Code? get body => _$this._body;
  set body(covariant Code? body) => _$this._body = body;

  String? _label;
  String? get label => _$this._label;
  set label(covariant String? label) => _$this._label = label;

  WhileLoopBuilder();

  WhileLoopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _doWhile = $v.doWhile;
      _condition = $v.condition;
      _body = $v.body;
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  // ignore: override_on_non_overriding_method
  void replace(covariant WhileLoop other) {
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
          doWhile: doWhile,
          condition: BuiltValueNullFieldError.checkNotNull(
            condition,
            r'WhileLoop',
            'condition',
          ),
          body: body,
          label: label,
        );
    replace(_$result);
    return _$result;
  }
}

class _$Branch extends Branch {
  @override
  final Expression? condition;
  @override
  final Code? body;

  factory _$Branch([void Function(BranchBuilder)? updates]) =>
      (BranchBuilder()..update(updates)).build() as _$Branch;

  _$Branch._({this.condition, this.body}) : super._();
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
  void replace(covariant Branch other) {
    _$v = other as _$Branch;
  }

  @override
  void update(void Function(BranchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Branch build() => _build();

  _$Branch _build() {
    final _$result = _$v ?? _$Branch._(condition: condition, body: body);
    replace(_$result);
    return _$result;
  }
}

class _$Conditional extends Conditional {
  @override
  final BuiltList<Branch> branches;

  factory _$Conditional([void Function(ConditionalBuilder)? updates]) =>
      (ConditionalBuilder()..update(updates)).build() as _$Conditional;

  _$Conditional._({required this.branches}) : super._();
  @override
  Conditional rebuild(void Function(ConditionalBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  _$ConditionalBuilder toBuilder() => _$ConditionalBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Conditional && branches == other.branches;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, branches.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Conditional')
      ..add('branches', branches)).toString();
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

  _$ConditionalBuilder() : super._();

  ConditionalBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.branches = $v.branches.toBuilder();
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
      _$result = _$v ?? _$Conditional._(branches: branches.build());
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
  final Reference? type;
  @override
  final String? exception;
  @override
  final String? stacktrace;
  @override
  final Code? body;

  factory _$Catch([void Function(CatchBuilder)? updates]) =>
      (CatchBuilder()..update(updates))._build();

  _$Catch._({this.type, this.exception, this.stacktrace, this.body})
    : super._();
  @override
  Catch rebuild(void Function(CatchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CatchBuilder toBuilder() => CatchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Catch &&
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
    return (newBuiltValueToStringHelper(r'Catch')
          ..add('type', type)
          ..add('exception', exception)
          ..add('stacktrace', stacktrace)
          ..add('body', body))
        .toString();
  }
}

class CatchBuilder
    with ControlBodyBuilder
    implements Builder<Catch, CatchBuilder> {
  _$Catch? _$v;

  Reference? _type;
  Reference? get type => _$this._type;
  set type(covariant Reference? type) => _$this._type = type;

  String? _exception;
  String? get exception => _$this._exception;
  set exception(covariant String? exception) => _$this._exception = exception;

  String? _stacktrace;
  String? get stacktrace => _$this._stacktrace;
  set stacktrace(covariant String? stacktrace) =>
      _$this._stacktrace = stacktrace;

  Code? _body;
  Code? get body => _$this._body;
  set body(covariant Code? body) => _$this._body = body;

  CatchBuilder();

  CatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _exception = $v.exception;
      _stacktrace = $v.stacktrace;
      _body = $v.body;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(covariant Catch other) {
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
          type: type,
          exception: exception,
          stacktrace: stacktrace,
          body: body,
        );
    replace(_$result);
    return _$result;
  }
}

class _$TryCatch extends TryCatch {
  @override
  final Code? body;
  @override
  final BuiltList<Catch> handlers;
  @override
  final Code? handleAll;

  factory _$TryCatch([void Function(TryCatchBuilder)? updates]) =>
      (TryCatchBuilder()..update(updates)).build() as _$TryCatch;

  _$TryCatch._({this.body, required this.handlers, this.handleAll}) : super._();
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
  ListBuilder<Catch> get handlers {
    _$this;
    return super.handlers;
  }

  @override
  set handlers(ListBuilder<Catch> handlers) {
    _$this;
    super.handlers = handlers;
  }

  @override
  Code? get handleAll {
    _$this;
    return super.handleAll;
  }

  @override
  set handleAll(Code? handleAll) {
    _$this;
    super.handleAll = handleAll;
  }

  _$TryCatchBuilder() : super._();

  TryCatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      super.body = $v.body;
      super.handlers = $v.handlers.toBuilder();
      super.handleAll = $v.handleAll;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(covariant TryCatch other) {
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
      _$result =
          _$v ??
          _$TryCatch._(
            body: body,
            handlers: handlers.build(),
            handleAll: handleAll,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'handlers';
        handlers.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'TryCatch',
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

class _$Case<T extends Spec?> extends Case<T> {
  @override
  final Expression? pattern;
  @override
  final Expression? guard;
  @override
  final String? label;
  @override
  final bool? isDefault;
  @override
  final T? body;

  factory _$Case([void Function(CaseBuilder<T>)? updates]) =>
      (CaseBuilder<T>()..update(updates))._build();

  _$Case._({this.pattern, this.guard, this.label, this.isDefault, this.body})
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
        isDefault == other.isDefault &&
        body == other.body;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pattern.hashCode);
    _$hash = $jc(_$hash, guard.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, isDefault.hashCode);
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
          ..add('isDefault', isDefault)
          ..add('body', body))
        .toString();
  }
}

class CaseBuilder<T extends Spec?> implements Builder<Case<T>, CaseBuilder<T>> {
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

  bool? _isDefault;
  bool? get isDefault => _$this._isDefault;
  set isDefault(bool? isDefault) => _$this._isDefault = isDefault;

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
      _isDefault = $v.isDefault;
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
    final _$result =
        _$v ??
        _$Case<T>._(
          pattern: pattern,
          guard: guard,
          label: label,
          isDefault: isDefault,
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
    with SwitchBuilder<Code?>
    implements Builder<SwitchStatement, SwitchStatementBuilder> {
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
      _$result =
          _$v ??
          _$SwitchStatement._(
            value: BuiltValueNullFieldError.checkNotNull(
              value,
              r'SwitchStatement',
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

class _$SwitchExpression extends SwitchExpression {
  @override
  final Expression value;
  @override
  final BuiltList<Case<Expression>> cases;

  factory _$SwitchExpression([
    void Function(SwitchExpressionBuilder)? updates,
  ]) => (SwitchExpressionBuilder()..update(updates))._build();

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
    with SwitchBuilder<Expression>
    implements Builder<SwitchExpression, SwitchExpressionBuilder> {
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
