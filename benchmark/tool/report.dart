// Compares benchmark result files as Markdown tables, grouping them by their
// label ("before" and "after"), one file per round
//
//   dart run tool/report.dart results/*.json
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _ns(num value) =>
    value >= 1000 ? '${(value / 1000).toStringAsFixed(2)} µs' : '${value.toStringAsFixed(0)} ns';

num _median(List<num> values) => (values.toList()..sort())[values.length ~/ 2];

/// Median across rounds, with the range in brackets
String _cell(List<num> values) {
  final sorted = values.toList()..sort();
  return '${_ns(_median(sorted))} <sub>(${_ns(sorted.first)}–${_ns(sorted.last)})</sub>';
}

void main(List<String> args) {
  final rounds = <String, List<Map<String, dynamic>>>{};
  for (final path in args) {
    final result = _read(path);
    rounds.putIfAbsent(result['label'] as String, () => []).add(result);
  }
  final before = rounds['before']!;
  final after = rounds['after']!;

  final out = StringBuffer()
    ..writeln('# minimal_mvn: before vs after')
    ..writeln()
    ..writeln('* **Before**: `${before.first['ref']}`')
    ..writeln('* **After**: `${after.first['ref']}`')
    ..writeln(
      '* Dart ${(after.first['dart'] as String).split(' ').first}, '
      'macOS ${after.first['os']}, `flutter test` (JIT, asserts on), '
      '${after.length} alternating rounds',
    )
    ..writeln()
    ..writeln('## Correctness')
    ..writeln()
    ..writeln('| Scenario | Before | After |')
    ..writeln('| --- | --- | --- |');

  final beforeChecks = before.first['correctness'] as Map<String, dynamic>;
  final afterChecks = after.first['correctness'] as Map<String, dynamic>;
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
  out
    ..writeln()
    ..writeln('**$fixed of ${afterChecks.length} scenarios fixed.**')
    ..writeln()
    ..writeln('## Performance')
    ..writeln()
    ..writeln(
      'Each cell is the median across rounds of each round\'s median (11 runs '
      'after 3 warm-ups), with the range across rounds. Lower is better.',
    )
    ..writeln()
    ..writeln('| Benchmark | Selector runs before → after | Before | After | Change |')
    ..writeln('| --- | --- | --- | --- | --- |');

  List<num> values(List<Map<String, dynamic>> results, String id, String key) => [
    for (final result in results)
      ((result['performance'] as Map<String, dynamic>)[id] as Map<String, dynamic>)[key] as num,
  ];

  final ids = (after.first['performance'] as Map<String, dynamic>).keys;
  for (final id in ids) {
    final a = (after.first['performance'] as Map<String, dynamic>)[id] as Map<String, dynamic>;
    final bNs = values(before, id, 'ns');
    final aNs = values(after, id, 'ns');
    final change = (_median(aNs) - _median(bNs)) / _median(bNs) * 100;
    final runs = a.containsKey('selector_runs')
        ? '${_median(values(before, id, 'selector_runs')).round()} → '
              '${_median(values(after, id, 'selector_runs')).round()}'
        : '';
    out.writeln(
      '| ${a['title']} | $runs | ${_cell(bNs)} | ${_cell(aNs)} | '
      '${change > 0 ? '+' : ''}${change.toStringAsFixed(0)}% |',
    );
  }
  stdout.write(out);
}
