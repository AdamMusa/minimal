# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@a691422`
* Dart 3.12.2, Version 27.0.1 (Build 26A434), `flutter test` (JIT, asserts on)

## Correctness

| Scenario | Before | After |
| --- | --- | --- |
| Removing a never-added listener keeps an autodispose notifier alive | ❌ disposed, while 1 listener is attached | ✅ alive |
| Removing a listener twice keeps an autodispose notifier alive | ❌ disposed, while 1 listener is attached | ✅ alive |
| onUnsubscribed fires once when the last listener leaves | ❌ fired 3 time(s) | ✅ fired 1 time(s) |
| A selection ignores removing a listener it does not have | ❌ notifier disposed, selection still listened | ✅ alive |
| A replaced instance cannot dispose the current one | ❌ current disposed, while 1 listener is attached | ✅ alive |
| A selection without listeners reports the current value | ❌ read "", state is "new" | ✅ read "new", state is "new" |
| select() in build(): state survives 100 rebuilds | ❌ 50 errors ("A BNotifier was used after being disposed.") + 1 on unmount, 51 notifier instances, shows "1" (expected "100") | ✅ 0 errors, 1 notifier instances, shows "100" (expected "100") |
| A selection in a hidden tab shows the current state (#10) | ❌ shows "b:" (expected "b:moved") | ✅ shows "b:moved" (expected "b:moved") |

8 of 8 scenarios fixed.

## Performance

Median of 9 runs after a warm-up. Lower is better.

| Benchmark | Before | After | Change |
| --- | --- | --- | --- |
| 1 selection with 1 listener(s), per state change (selector runs) | 47 ns (1) | 54 ns (1) | +15% |
| 1 selection with 10 listener(s), per state change (selector runs) | 212 ns (10) | 132 ns (1) | -38% |
| 1 selection with 100 listener(s), per state change (selector runs) | 1.88 µs (100) | 1.47 µs (1) | -22% |
| 100 selections with 1 listener each, per state change | 3.10 µs | 5.65 µs | +82% |
| addListener + removeListener, with 0 other listeners | 51 ns | 206 ns | +302% |
| addListener + removeListener, with 10 other listeners | 676 ns | 1.03 µs | +52% |
| addListener + removeListener, with 100 other listeners | 4.51 µs | 9.90 µs | +119% |
| select() + addListener + removeListener, 10 per event loop turn | 1.58 µs | 5.07 µs | +221% |
