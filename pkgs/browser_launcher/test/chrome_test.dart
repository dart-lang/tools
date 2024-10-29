// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@OnPlatform({'windows': Skip('appveyor is not setup to install Chrome')})
library;

import 'dart:async';
import 'dart:io';

import 'package:browser_launcher/src/chrome.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

const _headlessOnlyEnvironment = 'HEADLESS_ONLY';

bool get headlessOnlyEnvironment =>
    Platform.environment[_headlessOnlyEnvironment] == 'true';

void _configureLogging(bool verbose) {
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

void main() {
  Chrome? chrome;

  // Pass 'true' for debugging.
  _configureLogging(false);

  Future<ChromeTab?> getTab(String url) => chrome!.chromeConnection.getTab(
        (t) => t.url.contains(url),
        retryFor: const Duration(seconds: 5),
      );

  Future<List<ChromeTab>?> getTabs() => chrome!.chromeConnection.getTabs(
        retryFor: const Duration(seconds: 5),
      );

  Future<WipConnection> connectToTab(String url) async {
    final tab = await getTab(url);
    expect(tab, isNotNull);
    return tab!.connect();
  }

  Future<HttpClientResponse> openTab(String url) =>
      chrome!.chromeConnection.getUrl(_openTabUrl(url));

  Future<void> launchChromeWithDebugPort({
    int port = 0,
    String? userDataDir,
    bool signIn = false,
    bool headless = false,
  }) async {
    chrome = await Chrome.startWithDebugPort(
      [_googleUrl],
      debugPort: port,
      userDataDir: userDataDir,
      signIn: signIn,
      headless: headless,
    );
  }

  Future<void> launchChrome({bool headless = false}) async {
    await Chrome.start([_googleUrl], args: [if (headless) '--headless']);
  }

  final headlessModes = [
    true,
    if (!headlessOnlyEnvironment) false,
  ];

  for (var headless in headlessModes) {
    group('(headless: $headless)', () {
      group('chrome with temp data dir', () {
        tearDown(() async {
          await chrome?.close();
          chrome = null;
        });

        test('can launch chrome', () async {
          await launchChrome(headless: headless);
          expect(chrome, isNull);
        });

        test('can launch chrome with debug port', () async {
          await launchChromeWithDebugPort(headless: headless);
          expect(chrome, isNotNull);
        });

        test('has a working debugger', () async {
          await launchChromeWithDebugPort(headless: headless);
          final tabs = await getTabs();
          expect(
            tabs,
            contains(
              const TypeMatcher<ChromeTab>()
                  .having((t) => t.url, 'url', _googleUrl),
            ),
          );
        });

        test('uses open debug port if provided port is 0', () async {
          await launchChromeWithDebugPort(headless: headless);
          expect(chrome!.debugPort, isNot(equals(0)));
        });

        test('can provide a specific debug port', () async {
          final port = await findUnusedPort();
          await launchChromeWithDebugPort(port: port, headless: headless);
          expect(chrome!.debugPort, port);
        });
      });

      group('chrome with user data dir', () {
        late Directory dataDir;
        const waitMilliseconds = Duration(milliseconds: 100);

        for (var signIn in [false, true]) {
          group('and signIn = $signIn', () {
            setUp(() {
              dataDir = Directory.systemTemp.createTempSync(_userDataDirName);
            });

            tearDown(() async {
              await chrome?.close();
              chrome = null;

              var attempts = 0;
              while (true) {
                try {
                  attempts++;
                  await Future<dynamic>.delayed(waitMilliseconds);
                  dataDir.deleteSync(recursive: true);
                  break;
                } catch (_) {
                  if (attempts > 3) rethrow;
                }
              }
            });

            test('can launch with debug port', () async {
              await launchChromeWithDebugPort(
                userDataDir: dataDir.path,
                signIn: signIn,
                headless: headless,
              );
              expect(chrome, isNotNull);
            });

            test('has a working debugger', () async {
              await launchChromeWithDebugPort(
                userDataDir: dataDir.path,
                signIn: signIn,
                headless: headless,
              );
              final tabs = await getTabs();
              expect(
                tabs,
                contains(
                  const TypeMatcher<ChromeTab>()
                      .having((t) => t.url, 'url', _googleUrl),
                ),
              );
            });

            test(
              'has correct profile path',
              () async {
                await launchChromeWithDebugPort(
                  userDataDir: dataDir.path,
                  signIn: signIn,
                  headless: headless,
                );
                await openTab(_chromeVersionUrl);
                final wipConnection = await connectToTab(_chromeVersionUrl);
                await wipConnection.debugger.enable();
                await wipConnection.runtime.enable();
                final result = await _evaluate(
                  wipConnection.page,
                  "document.getElementById('profile_path').textContent",
                );
                expect(result, contains(_userDataDirName));
              },
              // Note: When re-enabling, skip for headless mode because headless
              // mode does not allow chrome: urls.
              skip: 'https://github.com/dart-lang/sdk/issues/52357',
            );
          });
        }
      });
    });
  }
}

String _openTabUrl(String url) => '/json/new?$url';

Future<String?> _evaluate(WipPage page, String expression) async {
  String? result;
  const stopInSeconds = Duration(seconds: 5);
  const waitMilliseconds = Duration(milliseconds: 100);
  final stopTime = DateTime.now().add(stopInSeconds);

  while (result == null && DateTime.now().isBefore(stopTime)) {
    await Future<dynamic>.delayed(waitMilliseconds);
    try {
      final wipResponse = await page.sendCommand(
        'Runtime.evaluate',
        params: {'expression': expression},
      );
      final response = wipResponse.json['result'] as Map<String, dynamic>;
      final value = (response['result'] as Map<String, dynamic>)['value'];
      result = value?.toString();
    } catch (_) {
      return null;
    }
  }
  return result;
}

const _googleUrl = 'https://www.google.com/';
const _chromeVersionUrl = 'chrome://version/';
const _userDataDirName = 'data dir';
