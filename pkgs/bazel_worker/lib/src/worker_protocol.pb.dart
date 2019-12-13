///
//  Generated code. Do not modify.
//  source: worker_protocol.proto
//
// @dart = 2.3
// ignore_for_file: camel_case_types,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type
// ignore_for_file: annotate_overrides

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Input extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('Input',
      package: const $pb.PackageName('blaze.worker'),
      createEmptyInstance: create)
    ..aOS(1, 'path')
    ..a<$core.List<$core.int>>(2, 'digest', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  Input._() : super();
  factory Input() => create();
  factory Input.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Input.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  Input clone() => Input()..mergeFromMessage(this);
  Input copyWith(void Function(Input) updates) =>
      super.copyWith((message) => updates(message as Input));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static Input create() => Input._();
  Input createEmptyInstance() => create();
  static $pb.PbList<Input> createRepeated() => $pb.PbList<Input>();
  @$core.pragma('dart2js:noInline')
  static Input getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Input>(create);
  static Input _defaultInstance;

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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('WorkRequest',
      package: const $pb.PackageName('blaze.worker'),
      createEmptyInstance: create)
    ..pPS(1, 'arguments')
    ..pc<Input>(2, 'inputs', $pb.PbFieldType.PM, subBuilder: Input.create)
    ..a<$core.int>(3, 'requestId', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  WorkRequest._() : super();
  factory WorkRequest() => create();
  factory WorkRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WorkRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  WorkRequest clone() => WorkRequest()..mergeFromMessage(this);
  WorkRequest copyWith(void Function(WorkRequest) updates) =>
      super.copyWith((message) => updates(message as WorkRequest));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static WorkRequest create() => WorkRequest._();
  WorkRequest createEmptyInstance() => create();
  static $pb.PbList<WorkRequest> createRepeated() => $pb.PbList<WorkRequest>();
  @$core.pragma('dart2js:noInline')
  static WorkRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkRequest>(create);
  static WorkRequest _defaultInstance;

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
}

class WorkResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('WorkResponse',
      package: const $pb.PackageName('blaze.worker'),
      createEmptyInstance: create)
    ..a<$core.int>(1, 'exitCode', $pb.PbFieldType.O3)
    ..aOS(2, 'output')
    ..a<$core.int>(3, 'requestId', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  WorkResponse._() : super();
  factory WorkResponse() => create();
  factory WorkResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WorkResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  WorkResponse clone() => WorkResponse()..mergeFromMessage(this);
  WorkResponse copyWith(void Function(WorkResponse) updates) =>
      super.copyWith((message) => updates(message as WorkResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static WorkResponse create() => WorkResponse._();
  WorkResponse createEmptyInstance() => create();
  static $pb.PbList<WorkResponse> createRepeated() =>
      $pb.PbList<WorkResponse>();
  @$core.pragma('dart2js:noInline')
  static WorkResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkResponse>(create);
  static WorkResponse _defaultInstance;

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
}
