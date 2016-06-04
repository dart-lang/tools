import 'package:coverage/src/resolver.dart';
import 'package:test/test.dart';

main() {
  group('Bazel resolver', () {
      const workspace = 'foo';
      final resolver = new BazelResolver(workspacePath: workspace);

      test('does not resolve SDK URIs', () {
        expect(resolver.resolve('dart:convert'), null);
      });

      test('resolves third-party package URIs', () {
        expect(resolver.resolve('package:foo/bar.dart'), 'third_party/dart/foo/lib/bar.dart');
        expect(resolver.resolve('package:foo/src/bar.dart'), 'third_party/dart/foo/lib/src/bar.dart');
      });

      test('resolves non-third-party package URIs', () {
        expect(resolver.resolve('package:foo.bar/baz.dart'), 'foo/bar/lib/baz.dart');
        expect(resolver.resolve('package:foo.bar/src/baz.dart'), 'foo/bar/lib/src/baz.dart');
      });

      test('resolves file URIs', () {
        expect(resolver.resolve('file://x/y/z.runfiles/$workspace/foo/bar/lib/baz.dart'), 'foo/bar/lib/baz.dart');
        expect(resolver.resolve('file://x/y/z.runfiles/$workspace/foo/bar/lib/src/baz.dart'), 'foo/bar/lib/src/baz.dart');
      });

      test('resolves HTTPS URIs', () {
        expect(resolver.resolve('https://a/b/packages/foo/bar.dart'), 'third_party/dart/foo/lib/bar.dart');
        expect(resolver.resolve('https://a/b/packages/foo/src/bar.dart'), 'third_party/dart/foo/lib/src/bar.dart');
        expect(resolver.resolve('https://a/b/packages/foo.bar/baz.dart'), 'foo/bar/lib/baz.dart');
        expect(resolver.resolve('https://a/b/packages/foo.bar/src/baz.dart'), 'foo/bar/lib/src/baz.dart');
      });

      test('resolves HTTP URIs', () {
        expect(resolver.resolve('http://a/b/packages/foo.bar/baz.dart'), 'foo/bar/lib/baz.dart');
        expect(resolver.resolve('http://a/b/packages/foo.bar/src/baz.dart'), 'foo/bar/lib/src/baz.dart');
      });
  });
}
