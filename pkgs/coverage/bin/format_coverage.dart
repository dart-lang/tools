// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:async";
import "dart:io";
import "dart:isolate";

import "package:args/args.dart";
import "package:coverage/coverage.dart";
import "package:path/path.dart";


/// Given an absolute path absPath, this function returns a [List] of files
/// are contained by it if it is a directory, or a [List] containing the file if
/// it is a file.
List filesToProcess(String absPath) {
  var filePattern = new RegExp(r"^dart-cov-\d+-\d+.json$");
  if (FileSystemEntity.isDirectorySync(absPath)) {
    return new Directory(absPath).listSync(recursive: true)
        .where((entity) => entity is File &&
            filePattern.hasMatch(basename(entity.path)))
        .toList();
  }

  return [new File(absPath)];
}

worker(WorkMessage msg) {
  final start = new DateTime.now().millisecondsSinceEpoch;

  List files = msg.files;
  var resolver =
      new Resolver(packageRoot: msg.pkgRoot, sdkRoot: msg.sdkRoot);
  var workerHitmap = {};
  files.forEach((File fileEntry) {
    // Read file sync, as it only contains 1 object.
    String contents = fileEntry.readAsStringSync();
    if (contents.length > 0) {
      mergeHitmaps(createHitmap(contents, resolver), workerHitmap);
    }
  });

  if (msg.verbose) {
    final end = new DateTime.now().millisecondsSinceEpoch;
    print("${msg.workerName}: Finished processing ${files.length} files. "
          "Took ${end - start} ms.");
  }

  msg.replyPort.send(new ResultMessage(workerHitmap, resolver.failed));
}

class WorkMessage {
  final String workerName;
  final String sdkRoot;
  final String pkgRoot;
  final List files;
  final SendPort replyPort;
  final bool verbose;
  WorkMessage(this.workerName, this.pkgRoot, this.sdkRoot, this.files, this.replyPort, this.verbose);
}

class ResultMessage {
  final hitmap;
  final failedResolves;
  ResultMessage(this.hitmap, this.failedResolves);
}

List<List> split(List list, int nBuckets) {
  var buckets = new List(nBuckets);
  var bucketSize = list.length ~/ nBuckets;
  var leftover = list.length % nBuckets;
  var taken = 0;
  var start = 0;
  for (int i = 0; i < nBuckets; i++) {
    var end = (i < leftover) ? (start + bucketSize + 1) : (start + bucketSize);
    buckets[i] = list.sublist(start, end);
    taken += buckets[i].length;
    start = end;
  }
  if (taken != list.length) throw "Error splitting";
  return buckets;
}

Future<ResultMessage> spawnWorker(name, pkgRoot, sdkRoot, files, verbose) {
  RawReceivePort port = new RawReceivePort();
  var completer = new Completer();
  port.handler = ((ResultMessage msg) {
    completer.complete(msg);
    port.close();
  });
  var msg = new WorkMessage(name, pkgRoot, sdkRoot, files, port.sendPort, verbose);
  Isolate.spawn(worker, msg);
  return completer.future;
}

/// [Environment] stores gathered arguments information.
class Environment {
  String sdkRoot;
  String pkgRoot;
  String input;
  IOSink output;
  int workers;
  bool prettyPrint;
  bool lcov;
  bool expectMarkers;
  bool verbose;
}

main(List<String> arguments) {
  final env = parseArgs(arguments);

  List files = filesToProcess(env.input);

  List failedResolves = [];
  List failedLoads = [];
  Map globalHitmap = {};
  int start = new DateTime.now().millisecondsSinceEpoch;

  if (env.verbose) {
    print("Environment:");
    print("  # files: ${files.length}");
    print("  # workers: ${env.workers}");
    print("  sdk-root: ${env.sdkRoot}");
    print("  package-root: ${env.pkgRoot}");
  }

  // Create workers.
  int workerId = 0;
  var results = split(files, env.workers).map((workerFiles) {
    var result = spawnWorker("Worker ${workerId++}", env.pkgRoot, env.sdkRoot,
        workerFiles, env.verbose);
    return result.then((ResultMessage message) {
      mergeHitmaps(message.hitmap, globalHitmap);
      failedResolves.addAll(message.failedResolves);
    });
  });

  Future.wait(results).then((ignore) {
    // All workers are done. Process the data.
    if (env.verbose) {
      final end = new DateTime.now().millisecondsSinceEpoch;
      print("Done creating a global hitmap. Took ${end - start} ms.");
    }

    Future out;
    if (env.prettyPrint) {
      out = prettyPrint(globalHitmap, failedLoads, env.output);
    }
    if (env.lcov) {
      out = lcov(globalHitmap, env.output);
    }

    out.then((_) {
      env.output.close().then((_) {
        if (env.verbose) {
          final end = new DateTime.now().millisecondsSinceEpoch;
          print("Done flushing output. Took ${end - start} ms.");
        }
      });

      if (env.verbose) {
        if (failedResolves.length > 0) {
          print("Failed to resolve:");
          failedResolves.toSet().forEach((e) {
            print("  ${e}");
          });
        }
        if (failedLoads.length > 0) {
          print("Failed to load:");
          failedLoads.toSet().forEach((e) {
            print("  ${e}");
          });
        }
      }
    });
  });
}

/// Checks the validity of the provided arguments. Does not initialize actual
/// processing.
parseArgs(List<String> arguments) {
  final env = new Environment();
  var parser = new ArgParser();

  parser.addOption("sdk-root", abbr: "s",
                   help: "path to the SDK root");
  parser.addOption("package-root", abbr: "p",
                   help: "path to the package root");
  parser.addOption("in", abbr: "i",
                   help: "input(s): may be file or directory");
  parser.addOption("out", abbr: "o",
                   help: "output: may be file or stdout",
                   defaultsTo: "stdout");
  parser.addOption("workers", abbr: "j",
                   help: "number of workers",
                   defaultsTo: "1");
  parser.addFlag("pretty-print", abbr: "r",
                 help: "convert coverage data to pretty print format",
                 negatable: false);
  parser.addFlag("lcov", abbr :"l",
                 help: "convert coverage data to lcov format",
                 negatable: false);
  parser.addFlag("verbose", abbr :"v",
                 help: "verbose output",
                 negatable: false);
  parser.addFlag("help", abbr: "h",
                 help: "show this help",
                 negatable: false);

  var args = parser.parse(arguments);

  printUsage() {
    print("Usage: dart format_coverage.dart [OPTION...]\n");
    print(parser.getUsage());
  }

  fail(String msg) {
    print("\n$msg\n");
    printUsage();
    exit(1);
  }

  if (args["help"]) {
    printUsage();
    exit(0);
  }

  env.sdkRoot = args["sdk-root"];
  if (env.sdkRoot == null) {
    if (Platform.environment.containsKey("DART_SDK")) {
      env.sdkRoot =
        join(absolute(normalize(Platform.environment["DART_SDK"])), "lib");
    }
  } else {
    env.sdkRoot = join(absolute(normalize(env.sdkRoot)), "lib");
  }
  if ((env.sdkRoot != null) && !FileSystemEntity.isDirectorySync(env.sdkRoot)) {
    fail("Provided SDK root '${args["sdk-root"]}' is not a valid SDK "
         "top-level directory");
  }

  env.pkgRoot = args["package-root"];
  if (env.pkgRoot != null) {
    env.pkgRoot = absolute(normalize(args["package-root"]));
    if (!FileSystemEntity.isDirectorySync(env.pkgRoot)) {
      fail("Provided package root '${args["package-root"]}' is not directory.");
    }
  }

  if (args["in"] == null) {
    fail("No input files given.");
  } else {
    env.input = absolute(normalize(args["in"]));
    if (!FileSystemEntity.isDirectorySync(env.input) &&
        !FileSystemEntity.isFileSync(env.input)) {
      fail("Provided input '${args["in"]}' is neither a directory, nor a file.");
    }
  }

  if (args["out"] == "stdout") {
    env.output = stdout;
  } else {
    env.output = absolute(normalize(args["out"]));
    env.output = new File(env.output).openWrite();
  }

  env.lcov = args["lcov"];
  if (args["pretty-print"] && env.lcov) {
    fail("Choose one of pretty-print or lcov output");
  } else if (!env.lcov) {
    // Use pretty-print either explicitly or by default.
    env.prettyPrint = true;
  }

  try {
    env.workers = int.parse("${args["workers"]}");
  } catch (e) {
    fail("Invalid worker count: $e");
  }

  env.verbose = args["verbose"];
  return env;
}
