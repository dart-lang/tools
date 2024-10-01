// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service.dart';

import 'hitmap.dart';
import 'util.dart';

const _retryInterval = Duration(milliseconds: 200);
const _debugTokenPositions = bool.fromEnvironment('DEBUG_COVERAGE');

/// Collects coverage for all isolates in the running VM.
///
/// Collects a hit-map containing merged coverage for all isolates in the Dart
/// VM associated with the specified [serviceUri]. Returns a map suitable for
/// input to the coverage formatters that ship with this package.
///
/// [serviceUri] must specify the http/https URI of the service port of a
/// running Dart VM and must not be null.
///
/// If [resume] is true, all isolates will be resumed once coverage collection
/// is complete.
///
/// If [waitPaused] is true, collection will not begin for an isolate until it
/// is in the paused state.
///
/// If [includeDart] is true, code coverage for core `dart:*` libraries will be
/// collected.
///
/// If [functionCoverage] is true, function coverage information will be
/// collected.
///
/// If [branchCoverage] is true, branch coverage information will be collected.
/// This will only work correctly if the target VM was run with the
/// --branch-coverage flag.
///
/// If [scopedOutput] is non-empty, coverage will be restricted so that only
/// scripts that start with any of the provided paths are considered.
///
/// If [isolateIds] is set, the coverage gathering will be restricted to only
/// those VM isolates.
///
/// If [coverableLineCache] is set, the collector will avoid recompiling
/// libraries it has already seen (see VmService.getSourceReport's
/// librariesAlreadyCompiled parameter). This is only useful when doing more
/// than one [collect] call over the same libraries. Pass an empty map to the
/// first call, and then pass the same map to all subsequent calls.
///
/// [serviceOverrideForTesting] is for internal testing only, and should not be
/// set by users.
Future<Map<String, dynamic>> collect(Uri serviceUri, bool resume,
    bool waitPaused, bool includeDart, Set<String>? scopedOutput,
    {Set<String>? isolateIds,
    Duration? timeout,
    bool functionCoverage = false,
    bool branchCoverage = false,
    Map<String, Set<int>>? coverableLineCache,
    VmService? serviceOverrideForTesting}) async {
  scopedOutput ??= <String>{};

  late VmService service;
  if (serviceOverrideForTesting != null) {
    service = serviceOverrideForTesting;
  } else {
    // Create websocket URI. Handle any trailing slashes.
    final pathSegments =
        serviceUri.pathSegments.where((c) => c.isNotEmpty).toList()..add('ws');
    final uri = serviceUri.replace(scheme: 'ws', pathSegments: pathSegments);

    await retry(() async {
      try {
        final options = const CompressionOptions(enabled: false);
        final socket = await WebSocket.connect('$uri', compression: options);
        final controller = StreamController<String>();
        socket.listen((data) => controller.add(data as String), onDone: () {
          controller.close();
          service.dispose();
        });
        service = VmService(controller.stream, socket.add,
            log: StdoutLog(), disposeHandler: socket.close);
        await service.getVM().timeout(_retryInterval);
      } on TimeoutException {
        // The signature changed in vm_service version 6.0.0.
        // ignore: await_only_futures
        await service.dispose();
        rethrow;
      }
    }, _retryInterval, timeout: timeout);
  }

  try {
    return await _getAllCoverage(
        service,
        includeDart,
        functionCoverage,
        branchCoverage,
        scopedOutput,
        isolateIds,
        coverableLineCache,
        waitPaused);
  } finally {
    if (resume && !waitPaused) {
      await _resumeIsolates(service);
    }
    // The signature changed in vm_service version 6.0.0.
    // ignore: await_only_futures
    await service.dispose();
  }
}

Future<Map<String, dynamic>> _getAllCoverage(
    VmService service,
    bool includeDart,
    bool functionCoverage,
    bool branchCoverage,
    Set<String>? scopedOutput,
    Set<String>? isolateIds,
    Map<String, Set<int>>? coverableLineCache,
    bool waitPaused) async {
  final job = _CollectionJob(
      service,
      includeDart,
      functionCoverage,
      [
        SourceReportKind.kCoverage,
        if (branchCoverage) SourceReportKind.kBranchCoverage,
      ],
      scopedOutput ?? <String>{},
      isolateIds,
      coverableLineCache);
  return <String, dynamic>{
    'type': 'CodeCoverage',
    'coverage': await job.collectAll(waitPaused),
  };
}

class _CollectionJob {
  // Inputs.
  final VmService _service;
  final bool _includeDart;
  final bool _functionCoverage;
  final List<String> _sourceReportKinds;
  final Set<String> _scopedOutput;
  final Set<String>? _isolateIds;
  final Map<String, Set<int>>? _coverableLineCache;

  // State.
  final List<String>? _librariesAlreadyCompiled;
  final _coveredIsolateGroups = <String>{};
  final _coveredIsolates = <String>{};

  // Output.
  final _allCoverage = <Map<String, dynamic>>[];

  _CollectionJob(
      this._service,
      this._includeDart,
      this._functionCoverage,
      this._sourceReportKinds,
      this._scopedOutput,
      this._isolateIds,
      this._coverableLineCache)
      : _librariesAlreadyCompiled = _coverableLineCache?.keys.toList() {}

  Future<List<Map<String, dynamic>>> collectAll(bool waitPaused) async {
    if (waitPaused) {
      await _collectPausedIsolatesUntilAllExit();
    } else {
      for (final isolateRef in await getAllIsolates(_service)) {
        await _collectOne(isolateRef);
      }
    }
    return _allCoverage;
  }

  Future<void> _collectPausedIsolatesUntilAllExit() async {
    await IsolatePausedListener(_service,
        (IsolateRef isolateRef, bool isLastIsolateInGroup) async {
      if (isLastIsolateInGroup) {
        await _collectOne(isolateRef);
      }
    }).listenUntilAllExited();
  }

  Future<void> _collectOne(IsolateRef isolateRef) async {
    if (!(_isolateIds?.contains(isolateRef.id) ?? true)) return;

    // _coveredIsolateGroups is only relevant for the !waitPaused flow. The
    // waitPaused flow only ever calls _collectOne once per isolate group.
    final isolateGroupId = isolateRef.isolateGroupId;
    if (isolateGroupId != null) {
      if (_coveredIsolateGroups.contains(isolateGroupId)) return;
      _coveredIsolateGroups.add(isolateGroupId);
    }

    late final SourceReport isolateReport;
    try {
      isolateReport = await _service.getSourceReport(
        isolateRef.id!,
        _sourceReportKinds,
        forceCompile: true,
        reportLines: true,
        libraryFilters: _scopedOutput.isNotEmpty
            ? List.from(_scopedOutput.map((filter) => 'package:$filter/'))
            : null,
        librariesAlreadyCompiled: _librariesAlreadyCompiled,
      );
    } on SentinelException {
      return;
    }

    final coverage = await _processSourceReport(
        _service,
        isolateRef,
        isolateReport,
        _includeDart,
        _functionCoverage,
        _coverableLineCache,
        _scopedOutput);
    _allCoverage.addAll(coverage);
  }
}

Future _resumeIsolates(VmService service) async {
  final vm = await service.getVM();
  final futures = <Future>[];
  for (var isolateRef in vm.isolates!) {
    // Guard against sync as well as async errors: sync - when we are writing
    // message to the socket, the socket might be closed; async - when we are
    // waiting for the response, the socket again closes.
    futures.add(Future.sync(() async {
      final isolate = await service.getIsolate(isolateRef.id!);
      if (isolate.pauseEvent!.kind != EventKind.kResume) {
        await service.resume(isolateRef.id!);
      }
    }));
  }
  try {
    await Future.wait(futures);
  } catch (_) {
    // Ignore resume isolate failures
  }
}

/// Returns the line number to which the specified token position maps.
///
/// Performs a binary search within the script's token position table to locate
/// the line in question.
int? _getLineFromTokenPos(Script script, int tokenPos) {
  // TODO(cbracken): investigate whether caching this lookup results in
  // significant performance gains.
  var min = 0;
  var max = script.tokenPosTable!.length;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final row = script.tokenPosTable![mid];
    if (row[1] > tokenPos) {
      max = mid;
    } else {
      for (var i = 1; i < row.length; i += 2) {
        if (row[i] == tokenPos) return row.first;
      }
      min = mid + 1;
    }
  }
  return null;
}

/// Returns a JSON coverage list backward-compatible with pre-1.16.0 SDKs.
Future<List<Map<String, dynamic>>> _processSourceReport(
    VmService service,
    IsolateRef isolateRef,
    SourceReport report,
    bool includeDart,
    bool functionCoverage,
    Map<String, Set<int>>? coverableLineCache,
    Set<String> scopedOutput) async {
  final hitMaps = <Uri, HitMap>{};
  final scripts = <ScriptRef, Script>{};
  final libraries = <LibraryRef>{};
  final needScripts = functionCoverage;

  Future<Script?> getScript(ScriptRef? scriptRef) async {
    if (scriptRef == null) {
      return null;
    }
    if (!scripts.containsKey(scriptRef)) {
      scripts[scriptRef] =
          await service.getObject(isolateRef.id!, scriptRef.id!) as Script;
    }
    return scripts[scriptRef];
  }

  HitMap getHitMap(Uri scriptUri) => hitMaps.putIfAbsent(scriptUri, HitMap.new);

  Future<void> processFunction(FuncRef funcRef) async {
    final func = await service.getObject(isolateRef.id!, funcRef.id!) as Func;
    if ((func.implicit ?? false) || (func.isAbstract ?? false)) {
      return;
    }
    final location = func.location;
    if (location == null) {
      return;
    }
    final script = await getScript(location.script);
    if (script == null) {
      return;
    }
    final funcName = await _getFuncName(service, isolateRef, func);
    // TODO(liama): Is this still necessary, or is location.line valid?
    final tokenPos = location.tokenPos!;
    final line = _getLineFromTokenPos(script, tokenPos);
    if (line == null) {
      if (_debugTokenPositions) {
        stderr.writeln(
            'tokenPos $tokenPos in function ${funcRef.name} has no line '
            'mapping for script ${script.uri!}');
      }
      return;
    }
    final hits = getHitMap(Uri.parse(script.uri!));
    hits.funcHits ??= <int, int>{};
    (hits.funcNames ??= <int, String>{})[line] = funcName;
  }

  for (var range in report.ranges!) {
    final scriptRef = report.scripts![range.scriptIndex!];
    final scriptUriString = scriptRef.uri;
    if (!scopedOutput.includesScript(scriptUriString)) {
      // Sometimes a range's script can be different to the function's script
      // (eg mixins), so we have to re-check the scope filter.
      // See https://github.com/dart-lang/coverage/issues/495
      continue;
    }
    final scriptUri = Uri.parse(scriptUriString!);

    // If we have a coverableLineCache, use it in the same way we use
    // SourceReportCoverage.misses: to add zeros to the coverage result for all
    // the lines that don't have a hit. Afterwards, add all the lines that were
    // hit or missed to the cache, so that the next coverage collection won't
    // need to compile this libarry.
    final coverableLines =
        coverableLineCache?.putIfAbsent(scriptUriString, () => <int>{});

    // Not returned in scripts section of source report.
    if (scriptUri.scheme == 'evaluate') continue;

    // Skip scripts from dart:.
    if (!includeDart && scriptUri.scheme == 'dart') continue;

    // Look up the hit maps for this script (shared across isolates).
    final hits = getHitMap(scriptUri);

    Script? script;
    if (needScripts) {
      script = await getScript(scriptRef);
      if (script == null) continue;
    }

    // If the script's library isn't loaded, load it then look up all its funcs.
    final libRef = script?.library;
    if (functionCoverage && libRef != null && !libraries.contains(libRef)) {
      libraries.add(libRef);
      final library =
          await service.getObject(isolateRef.id!, libRef.id!) as Library;
      if (library.functions != null) {
        for (var funcRef in library.functions!) {
          await processFunction(funcRef);
        }
      }
      if (library.classes != null) {
        for (var classRef in library.classes!) {
          final clazz =
              await service.getObject(isolateRef.id!, classRef.id!) as Class;
          if (clazz.functions != null) {
            for (var funcRef in clazz.functions!) {
              await processFunction(funcRef);
            }
          }
        }
      }
    }

    // Collect hits and misses.
    final coverage = range.coverage;

    if (coverage == null) continue;

    void forEachLine(List<int>? tokenPositions, void Function(int line) body) {
      if (tokenPositions == null) return;
      for (final line in tokenPositions) {
        body(line);
      }
    }

    if (coverableLines != null) {
      for (final line in coverableLines) {
        hits.lineHits.putIfAbsent(line, () => 0);
      }
    }

    forEachLine(coverage.hits, (line) {
      hits.lineHits.increment(line);
      coverableLines?.add(line);
      if (hits.funcNames != null && hits.funcNames!.containsKey(line)) {
        hits.funcHits!.increment(line);
      }
    });
    forEachLine(coverage.misses, (line) {
      hits.lineHits.putIfAbsent(line, () => 0);
      coverableLines?.add(line);
    });
    hits.funcNames?.forEach((line, funcName) {
      hits.funcHits?.putIfAbsent(line, () => 0);
    });

    final branchCoverage = range.branchCoverage;
    if (branchCoverage != null) {
      hits.branchHits ??= <int, int>{};
      forEachLine(branchCoverage.hits, (line) {
        hits.branchHits!.increment(line);
      });
      forEachLine(branchCoverage.misses, (line) {
        hits.branchHits!.putIfAbsent(line, () => 0);
      });
    }
  }

  // Output JSON
  final coverage = <Map<String, dynamic>>[];
  hitMaps.forEach((uri, hits) {
    coverage.add(hitmapToJson(hits, uri));
  });
  return coverage;
}

extension _MapExtension<T> on Map<T, int> {
  void increment(T key) => this[key] = (this[key] ?? 0) + 1;
}

Future<String> _getFuncName(
    VmService service, IsolateRef isolateRef, Func func) async {
  if (func.name == null) {
    return '${func.type}:${func.location!.tokenPos}';
  }
  final owner = func.owner;
  if (owner is ClassRef) {
    final cls = await service.getObject(isolateRef.id!, owner.id!) as Class;
    if (cls.name != null) return '${cls.name}.${func.name}';
  }
  return func.name!;
}

class StdoutLog extends Log {
  @override
  void warning(String message) => print(message);

  @override
  void severe(String message) => print(message);
}

extension _ScopedOutput on Set<String> {
  bool includesScript(String? scriptUriString) {
    if (scriptUriString == null) return false;

    // If the set is empty, it means the user didn't specify a --scope-output
    // flag, so allow everything.
    if (isEmpty) return true;

    final scriptUri = Uri.parse(scriptUriString);
    if (scriptUri.scheme != 'package') return false;

    final scope = scriptUri.pathSegments.first;
    return contains(scope);
  }
}
