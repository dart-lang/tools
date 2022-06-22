// Mocks generated by Mockito 5.1.0 from annotations
// in coverage/test/collect_coverage_mock_test.dart.
// Do not manually edit this file.

import 'dart:async' as _i3;

import 'package:mockito/mockito.dart' as _i1;
import 'package:vm_service/src/vm_service.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types

class _FakeBreakpoint_0 extends _i1.Fake implements _i2.Breakpoint {}

class _FakeSuccess_1 extends _i1.Fake implements _i2.Success {}

class _FakeResponse_2 extends _i1.Fake implements _i2.Response {}

class _FakeAllocationProfile_3 extends _i1.Fake
    implements _i2.AllocationProfile {}

class _FakeCpuSamples_4 extends _i1.Fake implements _i2.CpuSamples {}

class _FakeClassList_5 extends _i1.Fake implements _i2.ClassList {}

class _FakeFlagList_6 extends _i1.Fake implements _i2.FlagList {}

class _FakeInboundReferences_7 extends _i1.Fake
    implements _i2.InboundReferences {}

class _FakeInstanceSet_8 extends _i1.Fake implements _i2.InstanceSet {}

class _FakeIsolate_9 extends _i1.Fake implements _i2.Isolate {}

class _FakeIsolateGroup_10 extends _i1.Fake implements _i2.IsolateGroup {}

class _FakeMemoryUsage_11 extends _i1.Fake implements _i2.MemoryUsage {}

class _FakeScriptList_12 extends _i1.Fake implements _i2.ScriptList {}

class _FakeObj_13 extends _i1.Fake implements _i2.Obj {}

class _FakePortList_14 extends _i1.Fake implements _i2.PortList {}

class _FakeRetainingPath_15 extends _i1.Fake implements _i2.RetainingPath {}

class _FakeProcessMemoryUsage_16 extends _i1.Fake
    implements _i2.ProcessMemoryUsage {}

class _FakeStack_17 extends _i1.Fake implements _i2.Stack {}

class _FakeProtocolList_18 extends _i1.Fake implements _i2.ProtocolList {}

class _FakeSourceReport_19 extends _i1.Fake implements _i2.SourceReport {}

class _FakeVersion_20 extends _i1.Fake implements _i2.Version {}

class _FakeVM_21 extends _i1.Fake implements _i2.VM {}

class _FakeTimeline_22 extends _i1.Fake implements _i2.Timeline {}

class _FakeTimelineFlags_23 extends _i1.Fake implements _i2.TimelineFlags {}

class _FakeTimestamp_24 extends _i1.Fake implements _i2.Timestamp {}

class _FakeUriList_25 extends _i1.Fake implements _i2.UriList {}

class _FakeReloadReport_26 extends _i1.Fake implements _i2.ReloadReport {}

/// A class which mocks [VmService].
///
/// See the documentation for Mockito's code generation for more information.
class MockVmService extends _i1.Mock implements _i2.VmService {
  MockVmService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Stream<_i2.Event> get onVMEvent =>
      (super.noSuchMethod(Invocation.getter(#onVMEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onIsolateEvent =>
      (super.noSuchMethod(Invocation.getter(#onIsolateEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onDebugEvent =>
      (super.noSuchMethod(Invocation.getter(#onDebugEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onProfilerEvent =>
      (super.noSuchMethod(Invocation.getter(#onProfilerEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onGCEvent =>
      (super.noSuchMethod(Invocation.getter(#onGCEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onExtensionEvent =>
      (super.noSuchMethod(Invocation.getter(#onExtensionEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onTimelineEvent =>
      (super.noSuchMethod(Invocation.getter(#onTimelineEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onLoggingEvent =>
      (super.noSuchMethod(Invocation.getter(#onLoggingEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onServiceEvent =>
      (super.noSuchMethod(Invocation.getter(#onServiceEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onHeapSnapshotEvent =>
      (super.noSuchMethod(Invocation.getter(#onHeapSnapshotEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onStdoutEvent =>
      (super.noSuchMethod(Invocation.getter(#onStdoutEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<_i2.Event> get onStderrEvent =>
      (super.noSuchMethod(Invocation.getter(#onStderrEvent),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Stream<String> get onSend =>
      (super.noSuchMethod(Invocation.getter(#onSend),
          returnValue: Stream<String>.empty()) as _i3.Stream<String>);
  @override
  _i3.Stream<String> get onReceive =>
      (super.noSuchMethod(Invocation.getter(#onReceive),
          returnValue: Stream<String>.empty()) as _i3.Stream<String>);
  @override
  _i3.Future<dynamic> get onDone =>
      (super.noSuchMethod(Invocation.getter(#onDone),
          returnValue: Future<dynamic>.value()) as _i3.Future<dynamic>);
  @override
  _i3.Stream<_i2.Event> onEvent(String? streamId) =>
      (super.noSuchMethod(Invocation.method(#onEvent, [streamId]),
          returnValue: Stream<_i2.Event>.empty()) as _i3.Stream<_i2.Event>);
  @override
  _i3.Future<_i2.Breakpoint> addBreakpoint(
          String? isolateId, String? scriptId, int? line, {int? column}) =>
      (super.noSuchMethod(
              Invocation.method(#addBreakpoint, [isolateId, scriptId, line],
                  {#column: column}),
              returnValue: Future<_i2.Breakpoint>.value(_FakeBreakpoint_0()))
          as _i3.Future<_i2.Breakpoint>);
  @override
  _i3.Future<_i2.Breakpoint> addBreakpointWithScriptUri(
          String? isolateId, String? scriptUri, int? line, {int? column}) =>
      (super.noSuchMethod(
              Invocation.method(#addBreakpointWithScriptUri,
                  [isolateId, scriptUri, line], {#column: column}),
              returnValue: Future<_i2.Breakpoint>.value(_FakeBreakpoint_0()))
          as _i3.Future<_i2.Breakpoint>);
  @override
  _i3.Future<_i2.Breakpoint> addBreakpointAtEntry(
          String? isolateId, String? functionId) =>
      (super.noSuchMethod(
              Invocation.method(#addBreakpointAtEntry, [isolateId, functionId]),
              returnValue: Future<_i2.Breakpoint>.value(_FakeBreakpoint_0()))
          as _i3.Future<_i2.Breakpoint>);
  @override
  _i3.Future<_i2.Success> clearCpuSamples(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#clearCpuSamples, [isolateId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> clearVMTimeline() =>
      (super.noSuchMethod(Invocation.method(#clearVMTimeline, []),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Response> invoke(String? isolateId, String? targetId,
          String? selector, List<String>? argumentIds,
          {bool? disableBreakpoints}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #invoke,
                  [isolateId, targetId, selector, argumentIds],
                  {#disableBreakpoints: disableBreakpoints}),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Response> evaluate(
          String? isolateId, String? targetId, String? expression,
          {Map<String, String>? scope, bool? disableBreakpoints}) =>
      (super.noSuchMethod(
              Invocation.method(#evaluate, [isolateId, targetId, expression],
                  {#scope: scope, #disableBreakpoints: disableBreakpoints}),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Response> evaluateInFrame(
          String? isolateId, int? frameIndex, String? expression,
          {Map<String, String>? scope, bool? disableBreakpoints}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #evaluateInFrame,
                  [isolateId, frameIndex, expression],
                  {#scope: scope, #disableBreakpoints: disableBreakpoints}),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.AllocationProfile> getAllocationProfile(String? isolateId,
          {bool? reset, bool? gc}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #getAllocationProfile, [isolateId], {#reset: reset, #gc: gc}),
              returnValue: Future<_i2.AllocationProfile>.value(
                  _FakeAllocationProfile_3()))
          as _i3.Future<_i2.AllocationProfile>);
  @override
  _i3.Future<_i2.CpuSamples> getAllocationTraces(String? isolateId,
          {int? timeOriginMicros, int? timeExtentMicros, String? classId}) =>
      (super.noSuchMethod(
              Invocation.method(#getAllocationTraces, [
                isolateId
              ], {
                #timeOriginMicros: timeOriginMicros,
                #timeExtentMicros: timeExtentMicros,
                #classId: classId
              }),
              returnValue: Future<_i2.CpuSamples>.value(_FakeCpuSamples_4()))
          as _i3.Future<_i2.CpuSamples>);
  @override
  _i3.Future<_i2.ClassList> getClassList(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#getClassList, [isolateId]),
              returnValue: Future<_i2.ClassList>.value(_FakeClassList_5()))
          as _i3.Future<_i2.ClassList>);
  @override
  _i3.Future<_i2.CpuSamples> getCpuSamples(
          String? isolateId, int? timeOriginMicros, int? timeExtentMicros) =>
      (super.noSuchMethod(
              Invocation.method(#getCpuSamples,
                  [isolateId, timeOriginMicros, timeExtentMicros]),
              returnValue: Future<_i2.CpuSamples>.value(_FakeCpuSamples_4()))
          as _i3.Future<_i2.CpuSamples>);
  @override
  _i3.Future<_i2.FlagList> getFlagList() =>
      (super.noSuchMethod(Invocation.method(#getFlagList, []),
              returnValue: Future<_i2.FlagList>.value(_FakeFlagList_6()))
          as _i3.Future<_i2.FlagList>);
  @override
  _i3.Future<_i2.InboundReferences> getInboundReferences(
          String? isolateId, String? targetId, int? limit) =>
      (super.noSuchMethod(
              Invocation.method(
                  #getInboundReferences, [isolateId, targetId, limit]),
              returnValue: Future<_i2.InboundReferences>.value(
                  _FakeInboundReferences_7()))
          as _i3.Future<_i2.InboundReferences>);
  @override
  _i3.Future<_i2.InstanceSet> getInstances(
          String? isolateId, String? objectId, int? limit) =>
      (super.noSuchMethod(
              Invocation.method(#getInstances, [isolateId, objectId, limit]),
              returnValue: Future<_i2.InstanceSet>.value(_FakeInstanceSet_8()))
          as _i3.Future<_i2.InstanceSet>);
  @override
  _i3.Future<_i2.Isolate> getIsolate(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#getIsolate, [isolateId]),
              returnValue: Future<_i2.Isolate>.value(_FakeIsolate_9()))
          as _i3.Future<_i2.Isolate>);
  @override
  _i3.Future<_i2.IsolateGroup> getIsolateGroup(String? isolateGroupId) =>
      (super.noSuchMethod(Invocation.method(#getIsolateGroup, [isolateGroupId]),
              returnValue:
                  Future<_i2.IsolateGroup>.value(_FakeIsolateGroup_10()))
          as _i3.Future<_i2.IsolateGroup>);
  @override
  _i3.Future<_i2.MemoryUsage> getMemoryUsage(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#getMemoryUsage, [isolateId]),
              returnValue: Future<_i2.MemoryUsage>.value(_FakeMemoryUsage_11()))
          as _i3.Future<_i2.MemoryUsage>);
  @override
  _i3.Future<_i2.MemoryUsage> getIsolateGroupMemoryUsage(
          String? isolateGroupId) =>
      (super.noSuchMethod(
              Invocation.method(#getIsolateGroupMemoryUsage, [isolateGroupId]),
              returnValue: Future<_i2.MemoryUsage>.value(_FakeMemoryUsage_11()))
          as _i3.Future<_i2.MemoryUsage>);
  @override
  _i3.Future<_i2.ScriptList> getScripts(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#getScripts, [isolateId]),
              returnValue: Future<_i2.ScriptList>.value(_FakeScriptList_12()))
          as _i3.Future<_i2.ScriptList>);
  @override
  _i3.Future<_i2.Obj> getObject(String? isolateId, String? objectId,
          {int? offset, int? count}) =>
      (super.noSuchMethod(
              Invocation.method(#getObject, [isolateId, objectId],
                  {#offset: offset, #count: count}),
              returnValue: Future<_i2.Obj>.value(_FakeObj_13()))
          as _i3.Future<_i2.Obj>);
  @override
  _i3.Future<_i2.PortList> getPorts(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#getPorts, [isolateId]),
              returnValue: Future<_i2.PortList>.value(_FakePortList_14()))
          as _i3.Future<_i2.PortList>);
  @override
  _i3.Future<_i2.RetainingPath> getRetainingPath(
          String? isolateId, String? targetId, int? limit) =>
      (super.noSuchMethod(
          Invocation.method(#getRetainingPath, [isolateId, targetId, limit]),
          returnValue:
              Future<_i2.RetainingPath>.value(_FakeRetainingPath_15())) as _i3
          .Future<_i2.RetainingPath>);
  @override
  _i3.Future<_i2.ProcessMemoryUsage> getProcessMemoryUsage() =>
      (super.noSuchMethod(Invocation.method(#getProcessMemoryUsage, []),
              returnValue: Future<_i2.ProcessMemoryUsage>.value(
                  _FakeProcessMemoryUsage_16()))
          as _i3.Future<_i2.ProcessMemoryUsage>);
  @override
  _i3.Future<_i2.Stack> getStack(String? isolateId, {int? limit}) =>
      (super.noSuchMethod(
              Invocation.method(#getStack, [isolateId], {#limit: limit}),
              returnValue: Future<_i2.Stack>.value(_FakeStack_17()))
          as _i3.Future<_i2.Stack>);
  @override
  _i3.Future<_i2.ProtocolList> getSupportedProtocols() => (super.noSuchMethod(
          Invocation.method(#getSupportedProtocols, []),
          returnValue: Future<_i2.ProtocolList>.value(_FakeProtocolList_18()))
      as _i3.Future<_i2.ProtocolList>);
  @override
  _i3.Future<_i2.SourceReport> getSourceReport(
          String? isolateId, List<String>? reports,
          {String? scriptId,
          int? tokenPos,
          int? endTokenPos,
          bool? forceCompile,
          bool? reportLines,
          List<String>? libraryFilters}) =>
      (super.noSuchMethod(
              Invocation.method(#getSourceReport, [
                isolateId,
                reports
              ], {
                #scriptId: scriptId,
                #tokenPos: tokenPos,
                #endTokenPos: endTokenPos,
                #forceCompile: forceCompile,
                #reportLines: reportLines,
                #libraryFilters: libraryFilters
              }),
              returnValue:
                  Future<_i2.SourceReport>.value(_FakeSourceReport_19()))
          as _i3.Future<_i2.SourceReport>);
  @override
  _i3.Future<_i2.Version> getVersion() =>
      (super.noSuchMethod(Invocation.method(#getVersion, []),
              returnValue: Future<_i2.Version>.value(_FakeVersion_20()))
          as _i3.Future<_i2.Version>);
  @override
  _i3.Future<_i2.VM> getVM() => (super.noSuchMethod(
      Invocation.method(#getVM, []),
      returnValue: Future<_i2.VM>.value(_FakeVM_21())) as _i3.Future<_i2.VM>);
  @override
  _i3.Future<_i2.Timeline> getVMTimeline(
          {int? timeOriginMicros, int? timeExtentMicros}) =>
      (super.noSuchMethod(
              Invocation.method(#getVMTimeline, [], {
                #timeOriginMicros: timeOriginMicros,
                #timeExtentMicros: timeExtentMicros
              }),
              returnValue: Future<_i2.Timeline>.value(_FakeTimeline_22()))
          as _i3.Future<_i2.Timeline>);
  @override
  _i3.Future<_i2.TimelineFlags> getVMTimelineFlags() => (super.noSuchMethod(
          Invocation.method(#getVMTimelineFlags, []),
          returnValue: Future<_i2.TimelineFlags>.value(_FakeTimelineFlags_23()))
      as _i3.Future<_i2.TimelineFlags>);
  @override
  _i3.Future<_i2.Timestamp> getVMTimelineMicros() =>
      (super.noSuchMethod(Invocation.method(#getVMTimelineMicros, []),
              returnValue: Future<_i2.Timestamp>.value(_FakeTimestamp_24()))
          as _i3.Future<_i2.Timestamp>);
  @override
  _i3.Future<_i2.Success> pause(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#pause, [isolateId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> kill(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#kill, [isolateId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.UriList> lookupResolvedPackageUris(
          String? isolateId, List<String>? uris, {bool? local}) =>
      (super.noSuchMethod(
              Invocation.method(#lookupResolvedPackageUris, [isolateId, uris],
                  {#local: local}),
              returnValue: Future<_i2.UriList>.value(_FakeUriList_25()))
          as _i3.Future<_i2.UriList>);
  @override
  _i3.Future<_i2.UriList> lookupPackageUris(
          String? isolateId, List<String>? uris) =>
      (super.noSuchMethod(
              Invocation.method(#lookupPackageUris, [isolateId, uris]),
              returnValue: Future<_i2.UriList>.value(_FakeUriList_25()))
          as _i3.Future<_i2.UriList>);
  @override
  _i3.Future<_i2.Success> registerService(String? service, String? alias) =>
      (super.noSuchMethod(Invocation.method(#registerService, [service, alias]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.ReloadReport> reloadSources(String? isolateId,
          {bool? force,
          bool? pause,
          String? rootLibUri,
          String? packagesUri}) =>
      (super.noSuchMethod(
              Invocation.method(#reloadSources, [
                isolateId
              ], {
                #force: force,
                #pause: pause,
                #rootLibUri: rootLibUri,
                #packagesUri: packagesUri
              }),
              returnValue:
                  Future<_i2.ReloadReport>.value(_FakeReloadReport_26()))
          as _i3.Future<_i2.ReloadReport>);
  @override
  _i3.Future<_i2.Success> removeBreakpoint(
          String? isolateId, String? breakpointId) =>
      (super.noSuchMethod(
              Invocation.method(#removeBreakpoint, [isolateId, breakpointId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> requestHeapSnapshot(String? isolateId) =>
      (super.noSuchMethod(Invocation.method(#requestHeapSnapshot, [isolateId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> resume(String? isolateId,
          {String? step, int? frameIndex}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #resume, [isolateId], {#step: step, #frameIndex: frameIndex}),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Breakpoint> setBreakpointState(
          String? isolateId, String? breakpointId, bool? enable) =>
      (super.noSuchMethod(
              Invocation.method(
                  #setBreakpointState, [isolateId, breakpointId, enable]),
              returnValue: Future<_i2.Breakpoint>.value(_FakeBreakpoint_0()))
          as _i3.Future<_i2.Breakpoint>);
  @override
  _i3.Future<_i2.Success> setExceptionPauseMode(
          String? isolateId, String? mode) =>
      (super.noSuchMethod(
              Invocation.method(#setExceptionPauseMode, [isolateId, mode]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> setIsolatePauseMode(String? isolateId,
          {String? exceptionPauseMode, bool? shouldPauseOnExit}) =>
      (super.noSuchMethod(
              Invocation.method(#setIsolatePauseMode, [
                isolateId
              ], {
                #exceptionPauseMode: exceptionPauseMode,
                #shouldPauseOnExit: shouldPauseOnExit
              }),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Response> setFlag(String? name, String? value) =>
      (super.noSuchMethod(Invocation.method(#setFlag, [name, value]),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Success> setLibraryDebuggable(
          String? isolateId, String? libraryId, bool? isDebuggable) =>
      (super.noSuchMethod(
              Invocation.method(
                  #setLibraryDebuggable, [isolateId, libraryId, isDebuggable]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> setName(String? isolateId, String? name) =>
      (super.noSuchMethod(Invocation.method(#setName, [isolateId, name]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> setTraceClassAllocation(
          String? isolateId, String? classId, bool? enable) =>
      (super.noSuchMethod(
              Invocation.method(
                  #setTraceClassAllocation, [isolateId, classId, enable]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> setVMName(String? name) =>
      (super.noSuchMethod(Invocation.method(#setVMName, [name]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> setVMTimelineFlags(List<String>? recordedStreams) =>
      (super.noSuchMethod(
              Invocation.method(#setVMTimelineFlags, [recordedStreams]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> streamCancel(String? streamId) =>
      (super.noSuchMethod(Invocation.method(#streamCancel, [streamId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> streamCpuSamplesWithUserTag(List<String>? userTags) =>
      (super.noSuchMethod(
              Invocation.method(#streamCpuSamplesWithUserTag, [userTags]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Success> streamListen(String? streamId) =>
      (super.noSuchMethod(Invocation.method(#streamListen, [streamId]),
              returnValue: Future<_i2.Success>.value(_FakeSuccess_1()))
          as _i3.Future<_i2.Success>);
  @override
  _i3.Future<_i2.Response> callMethod(String? method,
          {String? isolateId, Map<String, dynamic>? args}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #callMethod, [method], {#isolateId: isolateId, #args: args}),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Response> callServiceExtension(String? method,
          {String? isolateId, Map<String, dynamic>? args}) =>
      (super.noSuchMethod(
              Invocation.method(#callServiceExtension, [method],
                  {#isolateId: isolateId, #args: args}),
              returnValue: Future<_i2.Response>.value(_FakeResponse_2()))
          as _i3.Future<_i2.Response>);
  @override
  _i3.Future<void> dispose() =>
      (super.noSuchMethod(Invocation.method(#dispose, []),
          returnValue: Future<void>.value(),
          returnValueForMissingStub: Future<void>.value()) as _i3.Future<void>);
  @override
  void registerServiceCallback(String? service, _i2.ServiceCallback? cb) =>
      super.noSuchMethod(
          Invocation.method(#registerServiceCallback, [service, cb]),
          returnValueForMissingStub: null);
}