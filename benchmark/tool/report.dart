// Compares the before and after results written by tool/run.sh
//
//   dart run tool/report.dart results
import 'dart:convert';
import 'dart:io';

/// Changes within this many percent are reported as equal
const _equalWithin = 3;

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Performance results by benchmark id, one per round
Map<String, List<Map<String, dynamic>>> _rounds(String path) {
  final rounds = <String, List<Map<String, dynamic>>>{};
  for (final line in File(path).readAsLinesSync()) {
    final result = jsonDecode(line) as Map<String, dynamic>;
    rounds.putIfAbsent(result['id'] as String, () => []).add(result);
  }
  return rounds;
}

num _median(Iterable<num> values) {
  final sorted = values.toList()..sort();
  return sorted[sorted.length ~/ 2];
}

String _ns(num value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(2)} µs'
    : '${value.toStringAsFixed(value < 10 ? 2 : 1)} ns';

String _cell(List<num> values) {
  final sorted = values.toList()..sort();
  return '${_ns(_median(sorted))} <sub>${_ns(sorted.first)}–${_ns(sorted.last)}</sub>';
}

void main(List<String> args) {
  final dir = args.single;
  final before = _json('$dir/before_correctness.json');
  final after = _json('$dir/after_correctness.json');

  final out = StringBuffer()
    ..writeln('# minimal_mvn: before vs after')
    ..writeln()
    ..writeln('* **Before**: `${before['ref']}`')
    ..writeln('* **After**: `${after['ref']}`')
    ..writeln('* macOS ${after['os']}, Dart ${(after['dart'] as String).split(' ').first}')
    ..writeln()
    ..writeln('## Correctness')
    ..writeln()
    ..writeln('Bug scenarios replayed with `flutter test` on both versions.')
    ..writeln()
    ..writeln('| Scenario | Before | After |')
    ..writeln('| --- | --- | --- |');

  final beforeChecks = before['correctness'] as Map<String, dynamic>;
  final afterChecks = after['correctness'] as Map<String, dynamic>;
  var fixed = 0;
  for (final id in afterChecks.keys) {
    final b = beforeChecks[id] as Map<String, dynamic>;
    final a = afterChecks[id] as Map<String, dynamic>;
    String cell(Map<String, dynamic> check) =>
        '${check['ok'] == true ? '✅' : '❌'} ${check['detail']}';
    if (b['ok'] != true && a['ok'] == true) {
      fixed++;
    }
    out.writeln('| ${a['title']} | ${cell(b)} | ${cell(a)} |');
  }

  final beforePerf = _rounds('$dir/before_performance.jsonl');
  final afterPerf = _rounds('$dir/after_performance.jsonl');
  final rounds = afterPerf.values.first.length;
  out
    ..writeln()
    ..writeln('**$fixed of ${afterChecks.length} scenarios fixed.**')
    ..writeln()
    ..writeln('## Performance')
    ..writeln()
    ..writeln(
      'Release build (AOT), each benchmark in its own process, before and after '
      'alternating, $rounds rounds. Each cell is the median across rounds, with '
      'the range; each round is itself the median of 15 runs after 5 warm-ups. '
      'Lower is better; changes within ±$_equalWithin% are reported as equal.',
    )
    ..writeln()
    ..writeln('| Benchmark | Selector runs | Before | After | Change |')
    ..writeln('| --- | --- | --- | --- | --- |');

  var slower = 0;
  for (final MapEntry(key: id, value: a) in afterPerf.entries) {
    final b = beforePerf[id]!;
    final bNs = [for (final r in b) r['ns'] as num];
    final aNs = [for (final r in a) r['ns'] as num];
    final change = (_median(aNs) - _median(bNs)) / _median(bNs) * 100;
    final String verdict;
    if (change <= -_equalWithin) {
      verdict = '✅ ${change.toStringAsFixed(0)}%';
    } else if (change < _equalWithin) {
      verdict = '= ${change > 0 ? '+' : ''}${change.toStringAsFixed(0)}%';
    } else {
      slower++;
      verdict = '⚠️ +${change.toStringAsFixed(0)}%';
    }
    final runs = a.first.containsKey('selector_runs')
        ? '${_median([for (final r in b) r['selector_runs'] as num]).round()} → '
              '${_median([for (final r in a) r['selector_runs'] as num]).round()}'
        : '';
    out.writeln('| ${a.first['title']} | $runs | ${_cell(bNs)} | ${_cell(aNs)} | $verdict |');
  }
  out
    ..writeln()
    ..writeln(
      slower == 0
          ? '**No benchmark is slower.**'
          : '**$slower of ${afterPerf.length} benchmarks slower.**',
    );
  stdout.write(out);
}
