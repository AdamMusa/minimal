// Runs one performance benchmark, built in release mode (AOT) by
// tool/run.sh, then prints its result as JSON and exits:
//
//   BENCH_ONLY=<id> minimal_benchmark.app/Contents/MacOS/minimal_benchmark
//
// Each benchmark runs in its own process, so that none affects another
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'performance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
