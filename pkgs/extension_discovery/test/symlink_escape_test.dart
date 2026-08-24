@TestOn('linux')
library;

import 'dart:io';
import 'dart:isolate' show Isolate;

import 'package:extension_discovery/extension_discovery.dart';
import 'package:test/test.dart';

import 'test_descriptor.dart' as d;

void main() {
  test('Prevents symlink cache poisoning', () async {
    final pkgLibDir = await Isolate.resolvePackageUri(
      Uri.parse('package:extension_discovery/'),
    );
    final pkgDir = pkgLibDir!.resolve('..');

    // Create a target secret file outside the packages
    await d.file('target_secret.txt', '{"secret":"initial secret"}').create();
    final targetPath = d.path('target_secret.txt');

    // Create a victim app and an evil package
    await d.dir('evil_pkg', [
      d.pubspec({
        'name': 'evil_pkg',
        'environment': {'sdk': '^3.0.0'},
      }),
      d.dir('extension', [
        d.dir('devtools', [
          d.json('config.yaml', {'secret': 'fake initial safe file'})
        ])
      ]),
    ]).create();

    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'extension_discovery': {'path': pkgDir.toFilePath()},
          'evil_pkg': {'path': '../evil_pkg'},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Round 1: Run findExtensions with a proper file
    var extensions = await findExtensions(
      'devtools',
      packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
    );

    // Verify it finds the extension
    expect(extensions, isNotEmpty);
    expect(extensions.first.config['secret'], 'fake initial safe file');

    // Evict cache by deleting .dart_tool and re-running pub get
    final dartToolDir = Directory(d.path('myapp/.dart_tool'));
    if (dartToolDir.existsSync()) {
      dartToolDir.deleteSync(recursive: true);
    }
    await d.dartPubGet(d.path('myapp'));

    // Delete the safe file and create the symlink config.yaml utilizing
    // test_descriptor
    File(d.path('evil_pkg/extension/devtools/config.yaml')).deleteSync();

    await d
        .link('evil_pkg/extension/devtools/config.yaml', targetPath)
        .create();

    // Round 2: Run findExtensions with the malicious symlink
    extensions = await findExtensions(
      'devtools',
      packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
    );

    // Verify that evil_pkg did not poison the cache and leak the secret
    expect(extensions, isEmpty);
  });
}
