///
//  Generated code. Do not modify.
//  source: third_party/bazel/src/main/protobuf/worker_protocol.proto

// ignore: UNUSED_SHOWN_NAME
import 'dart:core' show int, bool, double, String, List, override;

import 'package:protobuf/protobuf.dart' as $pb;

class Input extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = new $pb.BuilderInfo('Input', package: const $pb.PackageName('blaze.worker'))
    ..aOS(1, 'path')
    ..a<List<int>>(2, 'digest', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  Input() : super();
  Input.fromBuffer(List<int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Input.fromJson(String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Input clone() => new Input()..mergeFromMessage(this);
  Input copyWith(void Function(Input) updates) => super.copyWith((message) => updates(message as Input));
  $pb.BuilderInfo get info_ => _i;
  static Input create() => new Input();
  static $pb.PbList<Input> createRepeated() => new $pb.PbList<Input>();
  static Input getDefault() => _defaultInstance ??= create()..freeze();
  static Input _defaultInstance;
  static void $checkItem(Input v) {
    if (v is! Input) $pb.checkItemFailed(v, _i.qualifiedMessageName);
  }

  String get path => $_getS(0, '');
  set path(String v) { $_setString(0, v); }
  bool hasPath() => $_has(0);
  void clearPath() => clearField(1);

  List<int> get digest => $_getN(1);
  set digest(List<int> v) { $_setBytes(1, v); }
  bool hasDigest() => $_has(1);
  void clearDigest() => clearField(2);
}

class WorkRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = new $pb.BuilderInfo('WorkRequest', package: const $pb.PackageName('blaze.worker'))
    ..pPS(1, 'arguments')
    ..pp<Input>(2, 'inputs', $pb.PbFieldType.PM, Input.$checkItem, Input.create)
    ..hasRequiredFields = false
  ;

  WorkRequest() : super();
  WorkRequest.fromBuffer(List<int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  WorkRequest.fromJson(String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  WorkRequest clone() => new WorkRequest()..mergeFromMessage(this);
  WorkRequest copyWith(void Function(WorkRequest) updates) => super.copyWith((message) => updates(message as WorkRequest));
  $pb.BuilderInfo get info_ => _i;
  static WorkRequest create() => new WorkRequest();
  static $pb.PbList<WorkRequest> createRepeated() => new $pb.PbList<WorkRequest>();
  static WorkRequest getDefault() => _defaultInstance ??= create()..freeze();
  static WorkRequest _defaultInstance;
  static void $checkItem(WorkRequest v) {
    if (v is! WorkRequest) $pb.checkItemFailed(v, _i.qualifiedMessageName);
  }

  List<String> get arguments => $_getList(0);

  List<Input> get inputs => $_getList(1);
}

class WorkResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = new $pb.BuilderInfo('WorkResponse', package: const $pb.PackageName('blaze.worker'))
    ..a<int>(1, 'exitCode', $pb.PbFieldType.O3)
    ..aOS(2, 'output')
    ..hasRequiredFields = false
  ;

  WorkResponse() : super();
  WorkResponse.fromBuffer(List<int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  WorkResponse.fromJson(String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  WorkResponse clone() => new WorkResponse()..mergeFromMessage(this);
  WorkResponse copyWith(void Function(WorkResponse) updates) => super.copyWith((message) => updates(message as WorkResponse));
  $pb.BuilderInfo get info_ => _i;
  static WorkResponse create() => new WorkResponse();
  static $pb.PbList<WorkResponse> createRepeated() => new $pb.PbList<WorkResponse>();
  static WorkResponse getDefault() => _defaultInstance ??= create()..freeze();
  static WorkResponse _defaultInstance;
  static void $checkItem(WorkResponse v) {
    if (v is! WorkResponse) $pb.checkItemFailed(v, _i.qualifiedMessageName);
  }

  int get exitCode => $_get(0, 0);
  set exitCode(int v) { $_setSignedInt32(0, v); }
  bool hasExitCode() => $_has(0);
  void clearExitCode() => clearField(1);

  String get output => $_getS(1, '');
  set output(String v) { $_setString(1, v); }
  bool hasOutput() => $_has(1);
  void clearOutput() => clearField(2);
}

