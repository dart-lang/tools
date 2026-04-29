import 'package:benchmark_harness/benchmark_harness.dart';

void main(List<String> args) async {
  final benchmark = Benchmark(
    title: 'List Comparison',
    variants: [
      BenchmarkVariant(
        name: 'Growable',
        run: () => <int>[]..addAll(Iterable.generate(100)),
      ),
      BenchmarkVariant(name: 'Fixed', run: () => List<int>.filled(100, 0)),
    ],
  );

  const jsonDefine = bool.fromEnvironment('json');
  if (args.contains('--json') || jsonDefine) {
    final emitter = JsonEmitter();
    await benchmark.report(emitter: emitter);
    print(emitter.toString());
  } else {
    final results = await benchmark.run();
    print(BenchmarkReport.formatTable(results));
  }
}
