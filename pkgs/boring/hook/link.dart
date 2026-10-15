// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:boring/src/bindings/record_use_mapping.g.dart';
import 'package:boring/src/hook_helpers/build_options.dart'
    show BuildModeEnum, BuildOptions;
import 'package:boring/src/hook_helpers/fetch.dart' show fetchPrebuiltLibrary;
import 'package:boring/src/hook_helpers/hashes.dart' show releaseTag;
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart' as record_use;

const _bindings = record_use.Library(
  'package:boring/src/bindings/boringssl.g.dart',
);

/// Links the static library from hook/build.dart into a dynamic library with
/// only the BoringSSL functions that the application uses.
///
/// If linking fails in the default `fetch` build mode, falls back to the
/// pre-built dynamic library.
Future<void> main(List<String> args) async {
  await link(args, (input, output) async {
    final staticLibrary = input.assets.code
        .where(
          (asset) => asset.id == 'package:${input.packageName}/boring.dart',
        )
        .firstOrNull;
    if (staticLibrary == null) {
      // hook/build.dart bundled a dynamic library instead.
      return;
    }
    final staticLibraryFile = staticLibrary.file!;

    final recordedUses = input.recordedUses;
    final List<String>? symbols;
    if (recordedUses == null) {
      // For example with `flutter config --no-enable-record-use`.
      stdout.writeln('boring: no recorded uses, keeping all functions.');
      symbols = null;
    } else {
      symbols = _usedSymbols(recordedUses);
      stdout.writeln(
        'boring: keeping the ${symbols.length} functions the application '
        'uses:\n  ${symbols.join('\n  ')}',
      );
    }

    final LinkerOptions linkerOptions;
    if (input.config.code.targetOS == OS.windows) {
      linkerOptions = await _windowsLinkerOptions(
        input,
        staticLibraryFile,
        symbols,
      );
    } else {
      linkerOptions = LinkerOptions.treeshake(symbolsToKeep: symbols);
    }

    try {
      await CLinker.library(
        name: 'bssl_dart',
        packageName: input.packageName,
        assetName: 'boring.dart',
        sources: [staticLibraryFile.toFilePath()],
        frameworks: const [],
        linkerOptions: linkerOptions,
        linkModePreference: LinkModePreference.dynamic,
      ).run(
        input: input,
        output: output,
        logger: Logger('')
          ..level = Level.ALL
          ..onRecord.listen((record) => stdout.writeln(record.message)),
      );
    } catch (e, s) {
      // Tree-shaking only makes the library smaller, so a missing or broken C
      // toolchain should not fail the build if there is an equivalent
      // pre-built library. This also catches errors, as native_toolchain_c
      // throws a `ToolError`, which extends `Error` and is not exported, if it
      // finds no toolchain.
      stdout.writeln('boring: linking failed: $e\n$s');
      if (!await _fallBackToPrebuiltLibrary(input, output, e)) rethrow;
    }
  });
}

/// Bundles the pre-built, not tree-shaken, dynamic library after linking the
/// static library failed with [linkError].
///
/// Returns `false` if there is no equivalent pre-built library to fall back
/// to.
Future<bool> _fallBackToPrebuiltLibrary(
  LinkInput input,
  LinkOutputBuilder output,
  Object linkError,
) async {
  final code = input.config.code;
  final target = '${code.targetOS}_${code.targetArchitecture}';
  final buildMode = BuildOptions.fromDefines(input.userDefines).buildMode;
  if (buildMode != BuildModeEnum.fetch) {
    // The static library was not fetched, but for example built from a local
    // checkout. Falling back would silently swap in different BoringSSL code.
    stderr.writeln(
      'package:boring could not link the static library built in the '
      '`${buildMode.name}` build mode for $target. Install a C toolchain '
      '(compiler and linker) for $target. Only the `fetch` build mode falls '
      'back to the pre-built dynamic library, which could differ from the '
      'library built in other modes.',
    );
    return false;
  }
  final library = await fetchPrebuiltLibrary(input, static: false);
  if (library == null) {
    return false;
  }
  final reason = switch (linkError) {
    // native_toolchain_c puts the whole linker command, which has an argument
    // for each used symbol, into the message.
    ProcessException(:final executable) =>
      'ProcessException: $executable failed',
    // The first line only, to keep the warning to one paragraph.
    _ => linkError.toString().split('\n').first,
  };
  stderr.writeln(
    'Warning: package:boring could not tree-shake its native library for '
    '$target, so it bundles the pre-built dynamic library of release '
    '$releaseTag instead, which is not tree-shaken and therefore '
    'larger. To enable tree-shaking, install a C toolchain (compiler and '
    'linker) for $target. Linking failed with: $reason',
  );
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: 'boring.dart',
      linkMode: DynamicLoadingBundled(),
      file: library,
    ),
  );
  return true;
}

/// The symbols of the bound functions that the application calls, tears off,
/// or takes the address of with `addresses`.
List<String> _usedSymbols(record_use.Recordings recordedUses) => [
  for (final definition in recordedUses.calls.keys)
    if (definition.library == _bindings) ?recordUseMapping[definition.name],
]..sort();

/// The options for linking a DLL exporting [symbols], or all bound functions
/// if [symbols] is null.
///
/// Only exports the functions that the [staticLibrary] defines. BoringSSL
/// doesn't compile some for Windows, such as
/// `RAND_enable_fork_unsafe_buffering`, and exporting them would fail the link.
Future<LinkerOptions> _windowsLinkerOptions(
  LinkInput input,
  Uri staticLibrary,
  List<String>? symbols,
) async {
  final defined = _definedBindings(
    await File.fromUri(staticLibrary).readAsBytes(),
  );
  final exports = symbols?.where(defined.contains).toList() ?? [...defined];

  // `LinkerOptions.treeshake` passes an `/INCLUDE:<symbol>` per symbol, and
  // Windows limits command lines to 32767 characters. Leave room for the
  // paths and other flags.
  final includesLength = exports.fold(0, (sum, s) => sum + s.length + 10);
  if (symbols != null && includesLength < 24000) {
    return LinkerOptions.treeshake(symbolsToKeep: exports);
  }

  // Link the whole archive instead, which keeps the assembly the DLL doesn't
  // use. The objects aren't compiled with `__declspec(dllexport)`, so the
  // module-definition file determines what the DLL exports.
  final moduleDefinition = input.outputDirectory.resolve('bssl_dart.def');
  await File.fromUri(moduleDefinition).writeAsString(
    ['EXPORTS', for (final symbol in exports) '    $symbol', ''].join('\n'),
  );
  return LinkerOptions.manual(
    linkerScript: moduleDefinition,
    symbolsToKeep: null,
  );
}

/// The symbols of the bound functions that the COFF [archive] defines.
Set<String> _definedBindings(Uint8List archive) {
  final defined = _archiveSymbols(archive);
  return {
    for (final symbol in recordUseMapping.values)
      // x86 prefixes C symbols with an underscore, which the module-definition
      // file omits.
      if (defined.contains(symbol) || defined.contains('_$symbol')) symbol,
  };
}

/// The symbols that the members of the COFF [archive] define, read from its
/// first linker member.
///
/// See https://learn.microsoft.com/windows/win32/debug/pe-format#first-linker-member.
Set<String> _archiveSymbols(Uint8List archive) {
  const signature = '!<arch>\n';
  const memberHeaderSize = 60;
  const start = signature.length + memberHeaderSize;
  if (archive.length < start + 4 ||
      String.fromCharCodes(archive, 0, signature.length) != signature ||
      String.fromCharCodes(archive, signature.length, 24).trimRight() != '/') {
    throw const FormatException('Not an archive with a linker member.');
  }
  final count = ByteData.sublistView(archive).getUint32(start, Endian.big);
  // The member offsets are followed by the NUL-terminated symbol names.
  var offset = start + 4 + 4 * count;
  if (offset > archive.length) {
    throw const FormatException('Archive is truncated or corrupted.');
  }
  final symbols = <String>{};
  for (var i = 0; i < count; i++) {
    if (offset >= archive.length) {
      throw const FormatException('Archive is truncated or corrupted.');
    }
    final end = archive.indexOf(0, offset);
    if (end == -1) {
      throw const FormatException('Archive symbol name is not NUL-terminated.');
    }
    symbols.add(String.fromCharCodes(archive, offset, end));
    offset = end + 1;
  }
  return symbols;
}
