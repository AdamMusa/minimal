import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:minimal_mvn/minimal_mvn.dart';

import 'model.dart';

/// A benchmark measuring nanoseconds per operation
typedef Benchmark = ({String title, Future<Map<String, Object>> Function() run});

const _runs = 15;
const _warmups = 5;

/// Median nanoseconds per operation of [body], which performs [ops]
/// operations, after warming up
Future<double> _measure(int ops, FutureOr<void> Function() body) async {
  for (var i = 0; i < _warmups; i++) {
    await body();
  }
  final samples = <int>[];
  for (var i = 0; i < _runs; i++) {
    final stopwatch = Stopwatch()..start();
    await body();
    samples.add(stopwatch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[_runs ~/ 2] * 1000 / ops;
}

Benchmark _directListeners(int listeners) => (
  title: 'Notifier with $listeners listener(s), per state change',
  run: () async {
    final notifier = BNotifier();
    for (var i = 0; i < listeners; i++) {
      notifier.addListener(() {});
    }
    const updates = 200000;
    return {
      'ns': await _measure(updates, () {
        for (var i = 0; i < updates; i++) {
          notifier.increment();
        }
      }),
    };
  },
);

Benchmark _managerAccess() => (
  title: 'manager.notifier, per access',
  run: () async {
    final manager = MMManager(BNotifier.new);
    const reads = 1000000;
    var sink = 0;
    final ns = await _measure(reads, () {
      for (var i = 0; i < reads; i++) {
        sink += manager.notifier.state.value;
      }
    });
    // keeps the reads from being optimized away
    return {'ns': ns, 'checksum': sink};
  },
);

Benchmark _selectionFanOut(int listeners) => (
  title: '1 selection with $listeners listener(s), per state change',
  run: () async {
    var selections = 0;
    final notifier = BNotifier();
    final selected = notifier.select((state) {
      selections++;
      return state.value;
    });
    for (var i = 0; i < listeners; i++) {
      selected.addListener(() {});
    }
    const updates = 100000;
    selections = 0;
    final ns = await _measure(updates, () {
      for (var i = 0; i < updates; i++) {
        notifier.increment();
      }
    });
    return {'ns': ns, 'selector_runs': selections / ((_runs + _warmups) * updates)};
  },
);

Benchmark _selectionRead() => (
  title: '1 selection read by its listener (ValueListenableBuilder), per state change',
  run: () async {
    final notifier = BNotifier();
    final selected = notifier.select((state) => state.value);
    var sink = 0;
    // as ValueListenableBuilder does on every change
    selected.addListener(() => sink += selected.value);
    const updates = 200000;
    final ns = await _measure(updates, () {
      for (var i = 0; i < updates; i++) {
        notifier.increment();
      }
    });
    return {'ns': ns, 'checksum': sink};
  },
);

Benchmark _screenDirect() => (
  title: 'Autodispose notifier created, listened, updated and disposed',
  run: () async {
    final manager = MMManager(BNotifier.new, autodispose: true);
    void l() {}
    const visits = 100000;
    return {
      'ns': await _measure(visits, () {
        for (var i = 0; i < visits; i++) {
          final notifier = manager.notifier..addListener(l);
          notifier
            ..increment()
            // the notifier is autodisposed here
            ..removeListener(l);
        }
      }),
    };
  },
);

Benchmark _screenSelection() => (
  title: 'Autodispose notifier created, listened via select(), updated and disposed',
  run: () async {
    final manager = MMManager(BNotifier.new, autodispose: true);
    void l() {}
    const visits = 100000;
    return {
      'ns': await _measure(visits, () {
        for (var i = 0; i < visits; i++) {
          final notifier = manager.notifier;
          final selected = notifier.select((state) => state.value)..addListener(l);
          notifier.increment();
          // the notifier is autodisposed here
          selected.removeListener(l);
        }
      }),
    };
  },
);

Benchmark _manySelections() => (
  title: '100 selections with 1 listener each, per state change',
  run: () async {
    final notifier = BNotifier();
    for (var i = 0; i < 100; i++) {
      notifier.select((state) => state.value).addListener(() {});
    }
    const updates = 20000;
    return {
      'ns': await _measure(updates, () {
        for (var i = 0; i < updates; i++) {
          notifier.increment();
        }
      }),
    };
  },
);

Benchmark _listenerChurn(int background) => (
  title: 'addListener + removeListener, with $background other listeners',
  run: () async {
    final notifier = BNotifier();
    for (var i = 0; i < background; i++) {
      notifier.addListener(() {});
    }
    void l() {}
    final ops = background >= 100 ? 50000 : 500000;
    return {
      'ns': await _measure(ops, () {
        for (var i = 0; i < ops; i++) {
          notifier
            ..addListener(l)
            ..removeListener(l);
        }
      }),
    };
  },
);

Benchmark _selectionChurn() => (
  title: 'select() + addListener + removeListener, 10 per event loop turn',
  run: () async {
    final notifier = BNotifier();
    notifier.addListener(() {});
    // 10 widgets swapping their selection per "frame", e.g. select() in
    // build(), then the event loop turns, as it does between frames
    const frames = 10000;
    const perFrame = 10;
    return {
      'ns': await _measure(frames * perFrame, () async {
        for (var f = 0; f < frames; f++) {
          for (var i = 0; i < perFrame; i++) {
            void l() {}
            notifier.select((state) => state.value)
              ..addListener(l)
              ..removeListener(l);
          }
          // pending microtasks, e.g. deferred unsubscriptions, run first
          await Future<void>.microtask(() {});
        }
      }),
    };
  },
);

/// Every benchmark, by id
final benchmarks = <String, Benchmark>{
  'direct_listeners_1': _directListeners(1),
  'direct_listeners_10': _directListeners(10),
  'manager_access': _managerAccess(),
  'selection_fanout_1': _selectionFanOut(1),
  'selection_fanout_10': _selectionFanOut(10),
  'selection_fanout_100': _selectionFanOut(100),
  'selection_read': _selectionRead(),
  'screen_direct': _screenDirect(),
  'screen_selection': _screenSelection(),
  'many_selections': _manySelections(),
  'listener_churn_0': _listenerChurn(0),
  'listener_churn_10': _listenerChurn(10),
  'listener_churn_100': _listenerChurn(100),
  'selection_churn': _selectionChurn(),
};
