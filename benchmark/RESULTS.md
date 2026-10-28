# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@a181c07`
* Dart 3.12.2, macOS Version 27.0.1 (Build 26A434), `flutter test` (JIT, asserts on), 5 alternating rounds

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

**8 of 8 scenarios fixed.**

## Performance

Each cell is the median across rounds of each round's median (11 runs after 3 warm-ups), with the range across rounds. Lower is better.

| Benchmark | Selector runs before → after | Before | After | Change |
| --- | --- | --- | --- | --- |
| 1 selection with 1 listener(s), per state change | 1 → 1 | 45 ns <sub>(43 ns–51 ns)</sub> | 55 ns <sub>(51 ns–62 ns)</sub> | +22% |
| 1 selection with 10 listener(s), per state change | 10 → 1 | 220 ns <sub>(215 ns–227 ns)</sub> | 140 ns <sub>(132 ns–145 ns)</sub> | -36% |
| 1 selection with 100 listener(s), per state change | 100 → 1 | 2.13 µs <sub>(1.92 µs–2.40 µs)</sub> | 939 ns <sub>(910 ns–1.03 µs)</sub> | -56% |
| 100 selections with 1 listener each, per state change |  | 3.13 µs <sub>(3.03 µs–4.11 µs)</sub> | 3.43 µs <sub>(3.25 µs–3.49 µs)</sub> | +10% |
| addListener + removeListener, with 0 other listeners |  | 59 ns <sub>(51 ns–82 ns)</sub> | 212 ns <sub>(199 ns–226 ns)</sub> | +261% |
| addListener + removeListener, with 10 other listeners |  | 508 ns <sub>(497 ns–778 ns)</sub> | 687 ns <sub>(661 ns–747 ns)</sub> | +35% |
| addListener + removeListener, with 100 other listeners |  | 4.67 µs <sub>(4.62 µs–5.63 µs)</sub> | 4.98 µs <sub>(4.66 µs–5.41 µs)</sub> | +7% |
| select() + addListener + removeListener, 10 per event loop turn |  | 779 ns <sub>(754 ns–823 ns)</sub> | 1.40 µs <sub>(1.38 µs–1.76 µs)</sub> | +79% |
