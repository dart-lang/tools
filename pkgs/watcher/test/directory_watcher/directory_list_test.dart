// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:watcher/src/directory_watcher/directory_list.dart';

import '../utils.dart';

void main() {
  group('directory list', () {
    test('files and directories', () async {
      writeFile('a/b/c');
      writeFile('a/d');
      createDir('a/e');

      expect(await list(''), {
        'd:a',
        'd:a/b',
        'd:a/e',
        'f:a/b/c',
        'f:a/d',
      });
    });

    test('links without cycle', () async {
      writeFile('targets/b/d/e/f');
      writeFile('targets/g/h/i/j');
      writeFile('workspace/a/b/c');
      writeLink(link: 'workspace/b', target: 'targets/b');
      writeLink(link: 'workspace/c', target: 'targets/g');

      expect(await list('workspace'), {
        'd:a',
        'd:a/b',
        'd:b',
        'd:b/d',
        'd:b/d/e',
        'd:c',
        'd:c/h',
        'd:c/h/i',
        'f:a/b/c',
        'f:b/d/e/f',
        'f:c/h/i/j'
      });
    });

    test('link cycle', () async {
      createDir('links');
      writeLink(link: 'links/link', target: 'links');
      expect(await list('links'), {
        'd:link',
        'l:link/link',
      });
    });

    test('double link cycle', () async {
      createDir('links');
      writeLink(link: 'links/link1', target: 'links');
      writeLink(link: 'links/link2', target: 'links');
      expect(await list('links'), {
        'd:link1',
        'd:link2',
        'l:link1/link1',
        'l:link1/link2',
        'l:link2/link1',
        'l:link2/link2',
      });
    });

    test('many link cycles', () async {
      createDir('links');
      writeLink(link: 'links/link1', target: 'links');
      writeLink(link: 'links/link2', target: 'links');
      writeLink(link: 'links/1/link3', target: 'links/1');
      writeLink(link: 'links/1/link4', target: 'links');
      writeLink(link: 'links/1/2/link5', target: 'links/1');

      expect((await list('links')).toList(), {
        'd:1',
        'd:1/2',
        'd:1/2/link5',
        'd:1/2/link5/2',
        'd:1/2/link5/link4',
        'd:1/2/link5/link4/1',
        'd:1/2/link5/link4/1/2',
        'd:1/link3',
        'd:1/link3/2',
        'd:1/link3/link4',
        'd:1/link3/link4/1',
        'd:1/link3/link4/1/2',
        'd:1/link4',
        'd:1/link4/1',
        'd:1/link4/1/2',
        'd:1/link4/1/2/link5',
        'd:1/link4/1/2/link5/2',
        'd:1/link4/1/link3',
        'd:1/link4/1/link3/2',
        'd:link1',
        'd:link1/1',
        'd:link1/1/2',
        'd:link1/1/2/link5',
        'd:link1/1/2/link5/2',
        'd:link1/1/link3',
        'd:link1/1/link3/2',
        'd:link2',
        'd:link2/1',
        'd:link2/1/2',
        'd:link2/1/2/link5',
        'd:link2/1/2/link5/2',
        'd:link2/1/link3',
        'd:link2/1/link3/2',
        'l:1/2/link5/2/link5',
        'l:1/2/link5/link3',
        'l:1/2/link5/link4/1/2/link5',
        'l:1/2/link5/link4/1/link3',
        'l:1/2/link5/link4/1/link4',
        'l:1/2/link5/link4/link1',
        'l:1/2/link5/link4/link2',
        'l:1/link3/2/link5',
        'l:1/link3/link3',
        'l:1/link3/link4/1/2/link5',
        'l:1/link3/link4/1/link3',
        'l:1/link3/link4/1/link4',
        'l:1/link3/link4/link1',
        'l:1/link3/link4/link2',
        'l:1/link4/1/2/link5/2/link5',
        'l:1/link4/1/2/link5/link3',
        'l:1/link4/1/2/link5/link4',
        'l:1/link4/1/link3/2/link5',
        'l:1/link4/1/link3/link3',
        'l:1/link4/1/link3/link4',
        'l:1/link4/1/link4',
        'l:1/link4/link1',
        'l:1/link4/link2',
        'l:link1/1/2/link5/2/link5',
        'l:link1/1/2/link5/link3',
        'l:link1/1/2/link5/link4',
        'l:link1/1/link3/2/link5',
        'l:link1/1/link3/link3',
        'l:link1/1/link3/link4',
        'l:link1/1/link4',
        'l:link1/link1',
        'l:link1/link2',
        'l:link2/1/2/link5/2/link5',
        'l:link2/1/2/link5/link3',
        'l:link2/1/2/link5/link4',
        'l:link2/1/link3/2/link5',
        'l:link2/1/link3/link3',
        'l:link2/1/link3/link4',
        'l:link2/1/link4',
        'l:link2/link1',
        'l:link2/link2',
      });
    });
  });
}

Future<Set<String>> list(String directory) async {
  directory = p.join(d.sandbox, directory);
  final fileSystemEntities =
      await Directory(directory).listRecursively().toList();

  final result = <String>{};
  for (final entity in fileSystemEntities) {
    final path =
        entity.path.substring(directory.length + 1).replaceAll('\\', '/');
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
  return result;
}
