// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:watcher/src/directory_watcher/polling/directory_list.dart';

import '../../utils.dart';

void main() {
  group('directory list', () {
    test('fails on missing directory', () async {
      await expectLater(list('missing'), throwsA(isA<PathNotFoundException>()));
    });

    test('reports files and directories', () async {
      writeFile('1');
      writeFile('2');
      writeFile('a/1');
      writeFile('a/2');
      writeFile('a/b/1');
      writeFile('a/b/2');
      createDir('a/b/c');

      expect(await list(''), {
        'd:a',
        'd:a/b',
        'd:a/b/c',
        'f:1',
        'f:2',
        'f:a/1',
        'f:a/2',
        'f:a/b/1',
        'f:a/b/2',
      });
    });

    test('reports broken link as a link', () async {
      writeLink(link: '1', target: '0');

      expect(await list(''), {'l:1'});
    });

    test('follows a link to a file', () async {
      writeFile('a/1');
      writeLink(link: 'b/1', target: 'a/1');

      expect(await list(''), {'d:a', 'd:b', 'f:a/1', 'f:b/1'});
    });

    test('follows a link to a link of a file', () async {
      writeFile('a/1');
      writeLink(link: 'b/1', target: 'a/1');
      writeLink(link: 'c/1', target: 'b/1');

      expect(await list(''), {'d:a', 'd:b', 'd:c', 'f:a/1', 'f:b/1', 'f:c/1'});
    });

    test('follows a link to a peer directory', () async {
      writeFile('a/1');
      writeLink(link: 'b', target: 'a');

      expect(await list(''), {'d:a', 'd:b', 'f:a/1', 'f:b/1'});
    });

    test('ignores a link to a parent directory within the list root', () async {
      writeFile('a/1');
      writeLink(link: 'a/b', target: 'a');

      expect(await list(''), {'d:a', 'f:a/1'});
    });

    test('correctly reports a two link loop', () async {
      writeFile('a/1');
      writeFile('b/2');
      writeLink(link: 'a/b', target: 'b');
      writeLink(link: 'b/a', target: 'a');

      // Listing from within the loop, all files are found once.
      expect(await list('a'), {'d:b', 'f:1', 'f:b/2'});

      // Listing from outside the loop each file is found twice, once via each
      // entrypoint into the loop.
      expect(await list(''), {
        'd:a',
        'd:a/b',
        'd:b',
        'd:b/a',
        'f:a/1',
        'f:a/b/2',
        'f:b/2',
        'f:b/a/1',
      });
    });
  });

  test('correctly reports a three link loop', () async {
    writeFile('a/1');
    writeFile('b/2');
    writeFile('c/3');
    writeLink(link: 'a/b', target: 'b');
    writeLink(link: 'b/c', target: 'c');
    writeLink(link: 'c/a', target: 'a');

    // Listing from within the loop, all files are found once.
    expect(await list('a'), {'d:b', 'd:b/c', 'f:1', 'f:b/2', 'f:b/c/3'});

    // Listing from outside the loop each file is found three times, once via
    // each entrypoint into the loop.
    expect(await list(''), {
      'd:a',
      'd:a/b',
      'd:a/b/c',
      'd:b',
      'd:b/c',
      'd:b/c/a',
      'd:c',
      'd:c/a',
      'd:c/a/b',
      'f:a/1',
      'f:a/b/2',
      'f:a/b/c/3',
      'f:b/2',
      'f:b/c/3',
      'f:b/c/a/1',
      'f:c/3',
      'f:c/a/1',
      'f:c/a/b/2',
    });
  });

  test('follows a link to a parent directory above the list root', () async {
    writeFile('1');
    writeFile('a/2');
    writeFile('a/b/3');
    writeLink(link: 'a/b/c', target: '');

    // Linking to above the list root finds `1`, which is above the list root,
    // but does not enter the root again. So each file is listed once.
    expect(await list('a'), {'d:b', 'd:b/c', 'f:2', 'f:b/3', 'f:b/c/1'});
  });

  test('correctly reports with double links to parent directories', () async {
    writeFile('a/1');
    writeFile('a/b/2');
    writeFile('d/3');
    writeFile('d/e/4');
    writeLink(link: 'a/b/c', target: 'd');
    writeLink(link: 'd/e/f', target: 'a');

    // Each file is found once, the second link that would close the loop is not
    // followed.
    expect(await list('a/b'), {
      'd:c',
      'd:c/e',
      'd:c/e/f',
      'f:2',
      'f:c/3',
      'f:c/e/4',
      'f:c/e/f/1',
    });
  });
}

/// Lists [directory] using `directory_list.dart`.
///
/// Checks that there are no duplicates in the results.
///
/// On Linux only, checks that the results match `find -L`, ensuring that the
/// test expectations above are correct.
Future<Set<String>> list(String directory) async {
  directory = p.join(d.sandbox, directory);
  String normalizePath(String path) {
    return path.substring(directory.length + 1).replaceAll('\\', '/');
  }

  final fileSystemEntities = await Directory(
    directory,
  ).listRecursively().toList();
  final result = <String>[];
  for (final entity in fileSystemEntities) {
    final path = normalizePath(entity.path);
    if (entity is File) {
      result.add('f:$path');
    } else if (entity is Directory) {
      result.add('d:$path');
    } else if (entity is Link) {
      result.add('l:$path');
    } else {
      fail('Unexpected entity type: $entity');
    }
  }

  // Check there were no duplicate results.
  final resultSet = result.toSet();
  expect(result.length, resultSet.length);

  // If on Linux, run `find -L` and compare.
  if (Platform.isLinux) {
    Iterable<String> listForType(String type) {
      final result = Process.runSync('bash', [
        '-c',
        'find -L $directory -type $type -mindepth 1',
      ]);
      return (result.stdout as String).split('\n').where((l) => l.isNotEmpty);
    }

    final findResult = {
      ...listForType('d').map((p) => 'd:${normalizePath(p)}'),
      ...listForType('f').map((p) => 'f:${normalizePath(p)}'),
      ...listForType('l').map((p) => 'l:${normalizePath(p)}'),
    };
    expect(resultSet, findResult);
  }

  return resultSet;
}
