// Replays the bug scenarios. Run it through tool/run.sh, which runs it once
// against the version before the fixes and once against the version after,
// then compares the two.
//
// It only uses the public API shared by both versions. Scenarios never fail:
// they record what happened, so that both versions can be compared.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_benchmark/model.dart';
import 'package:minimal_mvn/minimal_mvn.dart';

typedef Outcome = ({bool ok, String detail});

final _correctness = <String, Map<String, Object>>{};

void _check(String id, String title, Outcome outcome) =>
    _correctness[id] = {'title': title, 'ok': outcome.ok, 'detail': outcome.detail};

/// Lets a deferred unsubscription (if any) happen
Future<void> _flush() => Future<void>.delayed(Duration.zero);


void main() {
  tearDownAll(() {
    final label = Platform.environment['BENCH_LABEL'] ?? 'local';
    File(Platform.environment['BENCH_OUT'] ?? 'results/$label.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'label': label,
          'ref': Platform.environment['BENCH_REF'] ?? '',
          'dart': Platform.version,
          'os': Platform.operatingSystemVersion,
          'correctness': _correctness,
        }),
      );
  });

  group('correctness', () {
    test('unknown listener', () async {
      final manager = MMManager(BNotifier.new, autodispose: true);
      final notifier = manager.notifier;
      void l1() {}
      void l2() {}
      notifier.addListener(l1);
      notifier.removeListener(l2); // never added
      await _flush();
      _check(
        'unknown_listener',
        'Removing a never-added listener keeps an autodispose notifier alive',
        (
          ok: !notifier.isDisposed,
          detail: notifier.isDisposed ? 'disposed, while 1 listener is attached' : 'alive',
        ),
      );
    });

    test('double removal', () async {
      final manager = MMManager(BNotifier.new, autodispose: true);
      final notifier = manager.notifier;
      void l1() {}
      void l2() {}
      notifier
        ..addListener(l1)
        ..addListener(l2)
        ..removeListener(l1)
        ..removeListener(l1);
      await _flush();
      _check(
        'double_removal',
        'Removing a listener twice keeps an autodispose notifier alive',
        (
          ok: !notifier.isDisposed,
          detail: notifier.isDisposed ? 'disposed, while 1 listener is attached' : 'alive',
        ),
      );
    });

    test('onUnsubscribed repeats', () {
      var calls = 0;
      final notifier = BNotifier()..onUnsubscribed = () => calls++;
      void l() {}
      notifier
        ..addListener(l)
        ..removeListener(l)
        ..removeListener(l)
        ..removeListener(l);
      _check(
        'unsubscribed_once',
        'onUnsubscribed fires once when the last listener leaves',
        (ok: calls == 1, detail: 'fired $calls time(s)'),
      );
    });

    test('selection unknown listener', () async {
      final manager = MMManager(BNotifier.new, autodispose: true);
      final notifier = manager.notifier;
      void l1() {}
      void l2() {}
      final selected = notifier.select((state) => state.text);
      selected.addListener(l1);
      selected.removeListener(l2); // never added
      await _flush();
      _check(
        'selection_unknown_listener',
        'A selection ignores removing a listener it does not have',
        (
          ok: !notifier.isDisposed,
          detail: notifier.isDisposed ? 'notifier disposed, selection still listened' : 'alive',
        ),
      );
    });

    test('stale instance', () {
      final manager = MMManager(BNotifier.new, autodispose: true);
      final stale = manager.notifier;
      void l1() {}
      stale.addListener(l1);
      manager.override(BNotifier.new);
      final current = manager.notifier;
      void l2() {}
      current.addListener(l2);
      stale.removeListener(l1);
      _check(
        'stale_instance',
        'A replaced instance cannot dispose the current one',
        (
          ok: !current.isDisposed,
          detail: current.isDisposed ? 'current disposed, while 1 listener is attached' : 'alive',
        ),
      );
    });

    test('listener removing itself while notified', () {
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString().split('\n').first);
      final manager = MMManager(BNotifier.new, autodispose: true);
      final notifier = manager.notifier;
      late VoidCallback once;
      once = () => notifier.removeListener(once);
      notifier.addListener(once);
      notifier.increment();
      FlutterError.onError = onError;
      _check(
        'self_removal',
        'A one-shot listener (removing itself when notified) autodisposes cleanly',
        (
          ok: errors.isEmpty && notifier.isDisposed,
          detail: errors.isEmpty
              ? (notifier.isDisposed ? 'disposed after notifying' : 'not disposed')
              : '${errors.length} error ("${errors.first}")',
        ),
      );
    });

    test('stale selection value', () async {
      final notifier = BNotifier();
      final selected = notifier.select((state) => state.text);
      void l() {}
      selected
        ..addListener(l)
        ..removeListener(l);
      await _flush();
      notifier.append('new');
      // ValueListenableBuilder reads value before subscribing
      final read = selected.value;
      _check(
        'stale_selection_value',
        'A selection without listeners reports the current value',
        (ok: read == 'new', detail: 'read "$read", state is "new"'),
      );
    });

    testWidgets('select() in build + rebuilds', (tester) async {
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString().split('\n').first);
      BNotifier.created = 0;
      final manager = MMManager(BNotifier.new, autodispose: true);
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              final notifier = manager.notifier;
              return ListenableBuilder(
                listenable: notifier.select((state) => state.value),
                builder: (_, _) => Text('${notifier.state.value}'),
              );
            },
          ),
        ),
      );
      const rounds = 100;
      for (var i = 0; i < rounds; i++) {
        manager.notifier.increment();
        rebuild(() {});
        await tester.pump();
      }
      final shown = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join();
      final buildErrors = errors.length;
      // the crash can leave the element tree inconsistent: unmount it while
      // errors are still captured
      await tester.pumpWidget(const SizedBox());
      final teardownErrors = errors.length - buildErrors;
      FlutterError.onError = onError;
      _check(
        'select_in_build',
        'select() in build(): state survives $rounds rebuilds',
        (
          ok: errors.isEmpty && shown == '$rounds' && BNotifier.created == 1,
          detail:
              '$buildErrors errors${errors.isEmpty ? '' : ' ("${errors.first}")'}'
              '${teardownErrors > 0 ? ' + $teardownErrors on unmount' : ''}, '
              '${BNotifier.created} notifier instances, shows "$shown" (expected "$rounds")',
        ),
      );
    });

    testWidgets('selections in TabBarView (issue #10)', (tester) async {
      final manager = MMManager(BNotifier.new);
      final notifier = manager.notifier;
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
              ),
              body: TabBarView(
                children: [
                  ValueListenableBuilder(
                    valueListenable: notifier.select((state) => state.value),
                    builder: (_, value, _) => Text('a:$value'),
                  ),
                  ValueListenableBuilder(
                    valueListenable: notifier.select((state) => state.text),
                    builder: (_, text, _) => Text('b:$text'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // change tab B's selection while it's hidden, then show it
      notifier.append('moved');
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      final shown = tester.widgetList<Text>(find.textContaining('b:')).map((t) => t.data).join();
      _check(
        'tabbarview_issue10',
        'A selection in a hidden tab shows the current state (#10)',
        (ok: shown == 'b:moved', detail: 'shows "$shown" (expected "b:moved")'),
      );
    });
  });
}
