//
//  Generated code. Do not modify.
//  source: worker_protocol.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Input extends $pb.GeneratedMessage {
  factory Input() => create();
  Input._() : super();
  factory Input.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Input.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Input',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'blaze.worker'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'digest', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Input clone() => Input()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Input copyWith(void Function(Input) updates) =>
      super.copyWith((message) => updates(message as Input)) as Input;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Input create() => Input._();
  Input createEmptyInstance() => create();
  static $pb.PbList<Input> createRepeated() => $pb.PbList<Input>();
  @$core.pragma('dart2js:noInline')
  static Input getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Input>(create);
  static Input? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get digest => $_getN(1);
  @$pb.TagNumber(2)
  set digest($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDigest() => $_has(1);
  @$pb.TagNumber(2)
  void clearDigest() => clearField(2);
}

class WorkRequest extends $pb.GeneratedMessage {
  factory WorkRequest() => create();
  WorkRequest._() : super();
  factory WorkRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WorkRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'blaze.worker'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'arguments')
    ..pc<Input>(2, _omitFieldNames ? '' : 'inputs', $pb.PbFieldType.PM,
        subBuilder: Input.create)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.O3)
    ..aOB(4, _omitFieldNames ? '' : 'cancel')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'verbosity', $pb.PbFieldType.O3)
    ..aOS(6, _omitFieldNames ? '' : 'sandboxDir')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  WorkRequest clone() => WorkRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  WorkRequest copyWith(void Function(WorkRequest) updates) =>
      super.copyWith((message) => updates(message as WorkRequest))
          as WorkRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkRequest create() => WorkRequest._();
  WorkRequest createEmptyInstance() => create();
  static $pb.PbList<WorkRequest> createRepeated() => $pb.PbList<WorkRequest>();
  @$core.pragma('dart2js:noInline')
  static WorkRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkRequest>(create);
  static WorkRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get arguments => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<Input> get inputs => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get requestId => $_getIZ(2);
  @$pb.TagNumber(3)
  set requestId($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get cancel => $_getBF(3);
  @$pb.TagNumber(4)
  set cancel($core.bool v) {
    $_setBool(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCancel() => $_has(3);
  @$pb.TagNumber(4)
  void clearCancel() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get verbosity => $_getIZ(4);
  @$pb.TagNumber(5)
  set verbosity($core.int v) {
    $_setSignedInt32(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasVerbosity() => $_has(4);
  @$pb.TagNumber(5)
  void clearVerbosity() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get sandboxDir => $_getSZ(5);
  @$pb.TagNumber(6)
  set sandboxDir($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasSandboxDir() => $_has(5);
  @$pb.TagNumber(6)
  void clearSandboxDir() => clearField(6);
}

class WorkResponse extends $pb.GeneratedMessage {
  factory WorkResponse() => create();
  WorkResponse._() : super();
  factory WorkResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WorkResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'blaze.worker'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'exitCode', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'output')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.O3)
    ..aOB(4, _omitFieldNames ? '' : 'wasCancelled')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  WorkResponse clone() => WorkResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  WorkResponse copyWith(void Function(WorkResponse) updates) =>
      super.copyWith((message) => updates(message as WorkResponse))
          as WorkResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkResponse create() => WorkResponse._();
  WorkResponse createEmptyInstance() => create();
  static $pb.PbList<WorkResponse> createRepeated() =>
      $pb.PbList<WorkResponse>();
  @$core.pragma('dart2js:noInline')
  static WorkResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkResponse>(create);
  static WorkResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get exitCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set exitCode($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasExitCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearExitCode() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get output => $_getSZ(1);
  @$pb.TagNumber(2)
  set output($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasOutput() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutput() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get requestId => $_getIZ(2);
  @$pb.TagNumber(3)
  set requestId($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get wasCancelled => $_getBF(3);
  @$pb.TagNumber(4)
  set wasCancelled($core.bool v) {
    $_setBool(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasWasCancelled() => $_has(3);
  @$pb.TagNumber(4)
  void clearWasCancelled() => clearField(4);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
