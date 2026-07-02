import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:pool/pool.dart';
import 'package:tar/tar.dart';

typedef PackageStats = ({
  int fetchedVersions,
  int failedVersions,
  int uniqueYamlFiles,
  bool failedVersionListing,
});

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('max-packages',
        abbr: 'm', help: 'Maximum number of packages to fetch')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  final results = parser.parse(args);

  if (results['help'] == true) {
    print(parser.usage);
    return;
  }

  int? maxPackages;
  if (results['max-packages'] != null) {
    maxPackages = int.tryParse(results['max-packages'] as String);
  }

  print('Fetching package list from pub.dev...');
  final namesResponse =
      await http.get(Uri.parse('https://pub.dev/api/package-names'));
  if (namesResponse.statusCode != 200) {
    print('Error: Failed to fetch package list '
        '(HTTP ${namesResponse.statusCode})');
    return;
  }

  final namesJson = jsonDecode(namesResponse.body) as Map<String, dynamic>;
  final packages = (namesJson['packages'] as List<dynamic>).cast<String>();
  print('Found ${packages.length} packages on pub.dev.');

  final packagesToProcess = maxPackages != null
      ? packages.take(maxPackages).toList()
      : packages.toList();

  print('Processing ${packagesToProcess.length} packages...');

  final packageConfig = Isolate.packageConfigSync;
  final Directory dartToolDir;
  if (packageConfig != null) {
    dartToolDir = Directory.fromUri(packageConfig.resolve('.'));
  } else {
    dartToolDir = Directory('.dart_tool');
  }

  final outDir = Directory('${dartToolDir.path}/yaml/pub-dev-yaml-files');
  outDir.createSync(recursive: true);

  final pool = Pool(50);
  var completed = 0;

  var totalFetchedVersions = 0;
  var totalFailedVersions = 0;
  var totalUniqueYamlFiles = 0;
  var totalFailedVersionListing = 0;
  var totalPackagesDownloaded = 0;

  await Future.wait(
      packagesToProcess.map((package) async => pool.withResource(() async {
            final outFile = File('${outDir.path}/$package.jsonl.gz');
            if (outFile.existsSync()) {
              completed++;
              print('[$completed/${packagesToProcess.length}] '
                  'Skipped $package (already exists)');
              return;
            }

            try {
              final path = outFile.path;
              final stats = await _runIsolate(package, path);

              totalFetchedVersions += stats.fetchedVersions;
              totalFailedVersions += stats.failedVersions;
              totalUniqueYamlFiles += stats.uniqueYamlFiles;
              if (stats.failedVersionListing) {
                totalFailedVersionListing++;
              }
              totalPackagesDownloaded++;

              completed++;
              print('[$completed/${packagesToProcess.length}] '
                  'Processed $package (${stats.uniqueYamlFiles} yamls, '
                  '${stats.fetchedVersions} versions, '
                  '${stats.failedVersions} failed versions)');
            } catch (e) {
              completed++;
              print('[$completed/${packagesToProcess.length}] '
                  'Failed to process $package: $e');
            }
          })));

  await pool.close();

  print('\n=== SUMMARY ===');
  print('Packages downloaded: $totalPackagesDownloaded');
  print('Packages failed to list versions: $totalFailedVersionListing');
  print('Total versions fetched successfully: $totalFetchedVersions');
  print('Total versions failed fetching/extracting: $totalFailedVersions');
  print('Total unique YAML files: $totalUniqueYamlFiles');
}

Future<PackageStats> _runIsolate(String package, String outPath) =>
    Isolate.run(() => _processPackage(package, outPath));

Future<PackageStats> _processPackage(String package, String outPath) async {
  final client = RetryClient(http.Client());
  final results = <String>[];
  var fetchedVersions = 0;
  var failedVersions = 0;
  var uniqueYamlFiles = 0;
  var failedVersionListing = false;

  try {
    final apiUrl = Uri.parse('https://pub.dev/api/packages/$package');
    final apiResponse = await client.get(apiUrl);

    if (apiResponse.statusCode != 200) {
      return (
        fetchedVersions: fetchedVersions,
        failedVersions: failedVersions,
        uniqueYamlFiles: uniqueYamlFiles,
        failedVersionListing: true,
      );
    }

    final metadata = jsonDecode(apiResponse.body) as Map<String, dynamic>;
    final versionsList = metadata['versions'] as List<dynamic>? ?? [];

    // Process from newest to oldest
    final versions = versionsList.reversed.toList();
    final seenHashes = <String>{};

    for (final versionInfo in versions) {
      if (versionInfo is! Map) continue;

      final version = versionInfo['version'] as String;
      final archiveUrl = versionInfo['archive_url'] as String?;

      if (archiveUrl == null) continue;

      try {
        final request = http.Request('GET', Uri.parse(archiveUrl));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          failedVersions++;
          continue;
        }

        final tarStream = response.stream.transform(gzip.decoder);
        final reader = TarReader(tarStream);

        try {
          while (await reader.moveNext()) {
            final entry = reader.current;
            if (entry.type == TypeFlag.reg &&
                (entry.name.endsWith('.yaml') || entry.name.endsWith('.yml'))) {
              final bytesBuilder = BytesBuilder();
              await for (final chunk in entry.contents) {
                bytesBuilder.add(chunk);
              }
              final bytes = bytesBuilder.takeBytes();

              final fileHash = base64Encode(sha256.convert(bytes).bytes);

              if (!seenHashes.contains(fileHash)) {
                seenHashes.add(fileHash);
                final contentString = utf8.decode(bytes, allowMalformed: true);

                final jsonLine = jsonEncode({
                  'package': package,
                  'version': version,
                  'file': entry.name,
                  'contents': contentString,
                });
                results.add(jsonLine);
                uniqueYamlFiles++;
              }
            }
          }
        } finally {
          await reader.cancel();
        }
        fetchedVersions++;
      } catch (e) {
        failedVersions++;
      }
    }
  } finally {
    client.close();
  }

  final outFile = File(outPath);
  if (results.isNotEmpty) {
    final gzipBytes = gzip.encode(utf8.encode('${results.join('\n')}\n'));
    await outFile.writeAsBytes(gzipBytes);
  } else {
    await outFile.writeAsBytes(gzip.encode([]));
  }

  return (
    fetchedVersions: fetchedVersions,
    failedVersions: failedVersions,
    uniqueYamlFiles: uniqueYamlFiles,
    failedVersionListing: failedVersionListing,
  );
}
