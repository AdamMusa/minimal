# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@75a86a3`
* Dart 3.12.2, macOS Version 27.0.1 (Build 26A434), `flutter test` (JIT, asserts on), 5 alternating rounds

## Correctness

| Scenario | Before | After |
| --- | --- | --- |
| Removing a never-added listener keeps an autodispose notifier alive | ❌ disposed, while 1 listener is attached | ✅ alive |
| Removing a listener twice keeps an autodispose notifier alive | ❌ disposed, while 1 listener is attached | ✅ alive |
| onUnsubscribed fires once when the last listener leaves | ❌ fired 3 time(s) | ✅ fired 1 time(s) |
| A selection ignores removing a listener it does not have | ❌ notifier disposed, selection still listened | ✅ alive |
| A replaced instance cannot dispose the current one | ❌ current disposed, while 1 listener is attached | ✅ alive |
| A one-shot listener (removing itself when notified) autodisposes cleanly | ❌ 1 error ("The "dispose()" method on Instance of 'BNotifier' was called during the call to "notifyListeners()". This is likely to cause errors since it modifies the list of listeners while the list is being used.") | ✅ disposed after notifying |
| A selection without listeners reports the current value | ❌ read "", state is "new" | ✅ read "new", state is "new" |
| select() in build(): state survives 100 rebuilds | ❌ 50 errors ("A BNotifier was used after being disposed.") + 1 on unmount, 51 notifier instances, shows "1" (expected "100") | ✅ 0 errors, 1 notifier instances, shows "100" (expected "100") |
| A selection in a hidden tab shows the current state (#10) | ❌ shows "b:" (expected "b:moved") | ✅ shows "b:moved" (expected "b:moved") |

**9 of 9 scenarios fixed.**

## Performance

Each cell is the median across rounds of each round's median (11 runs after 3 warm-ups), with the range across rounds. Lower is better.

| Benchmark | Selector runs before → after | Before | After | Change |
| --- | --- | --- | --- | --- |
| Notifier with 1 listener(s), per state change |  | 24 ns <sub>(20 ns–51 ns)</sub> | 31 ns <sub>(21 ns–44 ns)</sub> | +29% |
| Notifier with 10 listener(s), per state change |  | 50 ns <sub>(48 ns–60 ns)</sub> | 52 ns <sub>(50 ns–63 ns)</sub> | +4% |
| manager.notifier, per access |  | 2 ns <sub>(2 ns–2 ns)</sub> | 1 ns <sub>(1 ns–1 ns)</sub> | -50% |
| 1 selection with 1 listener(s), per state change | 1 → 1 | 43 ns <sub>(41 ns–45 ns)</sub> | 53 ns <sub>(48 ns–83 ns)</sub> | +24% |
| 1 selection with 10 listener(s), per state change | 10 → 1 | 229 ns <sub>(224 ns–276 ns)</sub> | 132 ns <sub>(127 ns–142 ns)</sub> | -42% |
| 1 selection with 100 listener(s), per state change | 100 → 1 | 2.08 µs <sub>(1.97 µs–2.75 µs)</sub> | 756 ns <sub>(718 ns–852 ns)</sub> | -64% |
| 1 selection read by its listener (ValueListenableBuilder), per state change |  | 43 ns <sub>(42 ns–56 ns)</sub> | 51 ns <sub>(50 ns–53 ns)</sub> | +20% |
| Autodispose notifier created, listened, updated and disposed |  | 110 ns <sub>(105 ns–118 ns)</sub> | 140 ns <sub>(137 ns–142 ns)</sub> | +28% |
| Autodispose notifier created, listened via select(), updated and disposed |  | 289 ns <sub>(288 ns–480 ns)</sub> | 306 ns <sub>(304 ns–332 ns)</sub> | +6% |
| 100 selections with 1 listener each, per state change |  | 3.14 µs <sub>(2.99 µs–3.55 µs)</sub> | 3.18 µs <sub>(2.93 µs–3.49 µs)</sub> | +1% |
| addListener + removeListener, with 0 other listeners |  | 51 ns <sub>(50 ns–56 ns)</sub> | 59 ns <sub>(58 ns–59 ns)</sub> | +16% |
| addListener + removeListener, with 10 other listeners |  | 536 ns <sub>(502 ns–786 ns)</sub> | 517 ns <sub>(513 ns–659 ns)</sub> | -3% |
| addListener + removeListener, with 100 other listeners |  | 4.85 µs <sub>(4.65 µs–4.96 µs)</sub> | 4.64 µs <sub>(4.53 µs–5.26 µs)</sub> | -4% |
| select() + addListener + removeListener, 10 per event loop turn |  | 754 ns <sub>(734 ns–1.34 µs)</sub> | 769 ns <sub>(725 ns–821 ns)</sub> | +2% |
