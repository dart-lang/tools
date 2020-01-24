define(['dart_sdk', 'packages/test_core/test_core', 'packages/sample/main', 'packages/test_api/src/backend/closed_exception', 'packages/matcher/src/core_matchers'], function(dart_sdk, packages__test_core__test_core, packages__sample__main, packages__test_api__src__backend__closed_exception, packages__matcher__src__core_matchers) {
  'use strict';
  const core = dart_sdk.core;
  const async = dart_sdk.async;
  const dart = dart_sdk.dart;
  const dartx = dart_sdk.dartx;
  const test_core = packages__test_core__test_core.test_core;
  const main = packages__sample__main.main;
  const expect = packages__test_api__src__backend__closed_exception.src__frontend__expect;
  const core_matchers = packages__matcher__src__core_matchers.src__core_matchers;
  const main_test = Object.create(dart.library);
  let FutureOfNull = () => (FutureOfNull = dart.constFn(async.Future$(core.Null)))();
  let VoidToFutureOfNull = () => (VoidToFutureOfNull = dart.constFn(dart.fnType(FutureOfNull(), [])))();
  let VoidToNull = () => (VoidToNull = dart.constFn(dart.fnType(core.Null, [])))();
  const CT = Object.create(null);
  main_test.main = function main$() {
    test_core.group("a group", dart.fn(() => {
      test_core.test("sample test", dart.fn(() => async.async(core.Null, function*() {
        if (1 === false) {
          core.print("won't happen");
        } else {
          main.maybePrint();
          expect.expect(true, core_matchers.isTrue);
        }
      }), VoidToFutureOfNull()));
    }, VoidToNull()));
  };
  dart.trackLibraries("test/main_test", {
    "org-dartlang-app:///test/main_test.dart": main_test
  }, {
  }, '{"version":3,"sourceRoot":"","sources":["main_test.dart"],"names":[],"mappings":";;;;;;;;;;;;;;;;AAaI,IATF,gBAAM,WAAW;AAQb,MAPF,eAAK,eAAe;AAClB,YAAI,AAAE,MAAG;AACc,UAArB,WAAM;;AAEM,UAAZ;AACoB,UAApB,cAAO,MAAM;;MAEhB;;EAEL","file":"main_test.ddc.js"}');
  // Exports:
  return {
    test__main_test: main_test
  };
});

//# sourceMappingURL=main_test.ddc.js.map
