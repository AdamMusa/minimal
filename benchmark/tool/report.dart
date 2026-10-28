// Compares two benchmark result files as Markdown tables
//
//   dart run tool/report.dart results/before.json results/after.json
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _ns(num value) =>
    value >= 1000 ? '${(value / 1000).toStringAsFixed(2)} µs' : '${value.toStringAsFixed(0)} ns';

String _runs(num value) => value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

void main(List<String> args) {
  final before = _read(args[0]);
  final after = _read(args[1]);
  final out = StringBuffer()
    ..writeln('# minimal_mvn: before vs after')
    ..writeln()
    ..writeln('* **Before**: `${before['ref']}`')
    ..writeln('* **After**: `${after['ref']}`')
    ..writeln('* Dart ${(after['dart'] as String).split(' ').first}, '
        '${after['os']}, `flutter test` (JIT, asserts on)')
    ..writeln()
    ..writeln('## Correctness')
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
    if (b['ok'] != true && a['ok'] == true) fixed++;
    out.writeln('| ${a['title']} | ${cell(b)} | ${cell(a)} |');
  }
  out
    ..writeln()
    ..writeln('$fixed of ${afterChecks.length} scenarios fixed.')
    ..writeln()
    ..writeln('## Performance')
    ..writeln()
    ..writeln('Median of 9 runs after a warm-up. Lower is better.')
    ..writeln()
    ..writeln('| Benchmark | Before | After | Change |')
    ..writeln('| --- | --- | --- | --- |');

  final beforePerf = before['performance'] as Map<String, dynamic>;
  final afterPerf = after['performance'] as Map<String, dynamic>;
  for (final id in afterPerf.keys) {
    final b = beforePerf[id] as Map<String, dynamic>;
    final a = afterPerf[id] as Map<String, dynamic>;
    final bNs = b['ns'] as num;
    final aNs = a['ns'] as num;
    final change = (aNs - bNs) / bNs * 100;
    final sign = change > 0 ? '+' : '';
    var title = a['title'] as String;
    var beforeCell = _ns(bNs);
    var afterCell = _ns(aNs);
    if (a.containsKey('selector_runs')) {
      title = '$title (selector runs)';
      beforeCell = '$beforeCell (${_runs(b['selector_runs'] as num)})';
      afterCell = '$afterCell (${_runs(a['selector_runs'] as num)})';
    }
    out.writeln(
      '| $title | $beforeCell | $afterCell | $sign${change.toStringAsFixed(0)}% |',
    );
  }
  stdout.write(out);
}
