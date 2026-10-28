// Runs one performance benchmark, built in release mode (AOT) by
// tool/run.sh, then prints its result as JSON and exits:
//
//   BENCH_ONLY=<id> minimal_benchmark.app/Contents/MacOS/minimal_benchmark
//
// Each benchmark runs in its own process, so that none affects another.
// Builds differ by their padding, see padding.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'padding.dart';
import 'performance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // keeps the padding in the build, without ever running it
  if (Platform.environment['BENCH_PADDING'] == 'run') {
    stdout.writeln(padding.fold<int>(0, (sum, pad) => pad(sum)));
  }
  final only = Platform.environment['BENCH_ONLY'];
  if (only == null) {
    stdout.writeln(jsonEncode(benchmarks.keys.toList()));
    exit(0);
  }
  final benchmark = benchmarks[only]!;
  final result = await benchmark.run();
  stdout.writeln(jsonEncode({'id': only, 'title': benchmark.title, ...result}));
  await stdout.flush();
  exit(0);
}
