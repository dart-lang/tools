//
//  Generated code. Do not modify.
//  source: worker_protocol.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// An input file.
class Input extends $pb.GeneratedMessage {
  factory Input({
    $core.String? path,
    $core.List<$core.int>? digest,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (digest != null) {
      $result.digest = digest;
    }
    return $result;
  }
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

  /// The path in the file system where to read this input artifact from. This is
  /// either a path relative to the execution root (the worker process is
  /// launched with the working directory set to the execution root), or an
  /// absolute path.
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

  /// A hash-value of the contents. The format of the contents is unspecified and
  /// the digest should be treated as an opaque token. This can be empty in some
  /// cases.
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

/// This represents a single work unit that Blaze sends to the worker.
class WorkRequest extends $pb.GeneratedMessage {
  factory WorkRequest({
    $core.Iterable<$core.String>? arguments,
    $core.Iterable<Input>? inputs,
    $core.int? requestId,
    $core.bool? cancel,
    $core.int? verbosity,
    $core.String? sandboxDir,
  }) {
    final $result = create();
    if (arguments != null) {
      $result.arguments.addAll(arguments);
    }
    if (inputs != null) {
      $result.inputs.addAll(inputs);
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (cancel != null) {
      $result.cancel = cancel;
    }
    if (verbosity != null) {
      $result.verbosity = verbosity;
    }
    if (sandboxDir != null) {
      $result.sandboxDir = sandboxDir;
    }
    return $result;
  }
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

  /// The inputs that the worker is allowed to read during execution of this
  /// request.
  @$pb.TagNumber(2)
  $core.List<Input> get inputs => $_getList(1);

  /// Each WorkRequest must have either a unique
  /// request_id or request_id = 0. If request_id is 0, this WorkRequest must be
  /// processed alone (singleplex), otherwise the worker may process multiple
  /// WorkRequests in parallel (multiplexing). As an exception to the above, if
  /// the cancel field is true, the request_id must be the same as a previously
  /// sent WorkRequest. The request_id must be attached unchanged to the
  /// corresponding WorkResponse. Only one singleplex request may be sent to a
  /// worker at a time.
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

  /// EXPERIMENTAL: When true, this is a cancel request, indicating that a
  /// previously sent WorkRequest with the same request_id should be cancelled.
  /// The arguments and inputs fields must be empty and should be ignored.
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

  /// Values greater than 0 indicate that the worker may output extra debug
  /// information to stderr (which will go into the worker log). Setting the
  /// --worker_verbose flag for Bazel makes this flag default to 10.
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

  /// The relative directory inside the workers working directory where the
  /// inputs and outputs are placed, for sandboxing purposes. For singleplex
  /// workers, this is unset, as they can use their working directory as sandbox.
  /// For multiplex workers, this will be set when the
  /// --experimental_worker_multiplex_sandbox flag is set _and_ the execution
  /// requirements for the worker includes 'supports-multiplex-sandbox'.
  /// The paths in `inputs` will not contain this prefix, but the actual files
  /// will be placed/must be written relative to this directory. The worker
  /// implementation is responsible for resolving the file paths.
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

/// The worker sends this message to Blaze when it finished its work on the
/// WorkRequest message.
class WorkResponse extends $pb.GeneratedMessage {
  factory WorkResponse({
    $core.int? exitCode,
    $core.String? output,
    $core.int? requestId,
    $core.bool? wasCancelled,
  }) {
    final $result = create();
    if (exitCode != null) {
      $result.exitCode = exitCode;
    }
    if (output != null) {
      $result.output = output;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (wasCancelled != null) {
      $result.wasCancelled = wasCancelled;
    }
    return $result;
  }
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

  /// This is printed to the user after the WorkResponse has been received and is
  /// supposed to contain compiler warnings / errors etc. - thus we'll use a
  /// string type here, which gives us UTF-8 encoding.
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

  /// This field must be set to the same request_id as the WorkRequest it is a
  /// response to. Since worker processes which support multiplex worker will
  /// handle multiple WorkRequests in parallel, this ID will be used to
  /// determined which WorkerProxy does this WorkResponse belong to.
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

  /// EXPERIMENTAL When true, indicates that this response was sent due to
  /// receiving a cancel request. The exit_code and output fields should be empty
  /// and will be ignored. Exactly one WorkResponse must be sent for each
  /// non-cancelling WorkRequest received by the worker, but if the worker
  /// received a cancel request, it doesn't matter if it replies with a regular
  /// WorkResponse or with one where was_cancelled = true.
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
