# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@b40ba84`
* macOS Version 27.0.1 (Build 26A434), Dart 3.12.2

## Correctness

Bug scenarios replayed with `flutter test` on both versions.

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

Release build (AOT), each benchmark in its own process, before and after alternating, 8 rounds. Each cell is the median across rounds, with the range; each round is itself the median of 15 runs after 5 warm-ups. Lower is better; changes within ±3% are reported as equal.

| Benchmark | Selector runs | Before | After | Change |
| --- | --- | --- | --- | --- |
| Notifier with 1 listener(s), per state change |  | 8.07 ns <sub>7.92 ns–8.27 ns</sub> | 8.63 ns <sub>8.49 ns–8.71 ns</sub> | ⚠️ +7% |
| Notifier with 10 listener(s), per state change |  | 24.2 ns <sub>24.0 ns–32.2 ns</sub> | 24.7 ns <sub>24.6 ns–24.9 ns</sub> | = +2% |
| manager.notifier, per access |  | 2.66 ns <sub>2.65 ns–2.69 ns</sub> | 2.66 ns <sub>2.65 ns–2.69 ns</sub> | = -0% |
| 1 selection with 1 listener(s), per state change | 1 → 1 | 21.1 ns <sub>20.8 ns–21.1 ns</sub> | 19.9 ns <sub>19.7 ns–20.9 ns</sub> | ✅ -5% |
| 1 selection with 10 listener(s), per state change | 10 → 1 | 158.9 ns <sub>150.3 ns–181.5 ns</sub> | 36.9 ns <sub>36.7 ns–39.6 ns</sub> | ✅ -77% |
| 1 selection with 100 listener(s), per state change | 100 → 1 | 1.17 µs <sub>1.15 µs–1.25 µs</sub> | 190.2 ns <sub>187.6 ns–193.2 ns</sub> | ✅ -84% |
| 1 selection read by its listener (ValueListenableBuilder), per state change |  | 22.0 ns <sub>21.5 ns–25.4 ns</sub> | 20.7 ns <sub>20.6 ns–21.9 ns</sub> | ✅ -6% |
| Autodispose notifier created, listened, updated and disposed |  | 62.6 ns <sub>61.6 ns–63.3 ns</sub> | 72.2 ns <sub>70.5 ns–72.9 ns</sub> | ⚠️ +15% |
| Autodispose notifier created, listened via select(), updated and disposed |  | 182.5 ns <sub>178.4 ns–185.1 ns</sub> | 157.9 ns <sub>153.9 ns–160.4 ns</sub> | ✅ -13% |
| 100 selections with 1 listener each, per state change |  | 1.65 µs <sub>1.55 µs–1.67 µs</sub> | 1.28 µs <sub>1.27 µs–1.29 µs</sub> | ✅ -22% |
| addListener + removeListener, with 0 other listeners |  | 43.9 ns <sub>43.2 ns–45.6 ns</sub> | 45.0 ns <sub>44.4 ns–45.5 ns</sub> | = +2% |
| addListener + removeListener, with 10 other listeners |  | 431.6 ns <sub>429.1 ns–437.8 ns</sub> | 432.7 ns <sub>431.9 ns–434.2 ns</sub> | = +0% |
| addListener + removeListener, with 100 other listeners |  | 3.87 µs <sub>3.85 µs–3.95 µs</sub> | 3.87 µs <sub>3.85 µs–3.92 µs</sub> | = -0% |
| select() + addListener + removeListener, 10 per event loop turn |  | 213.6 ns <sub>211.6 ns–217.5 ns</sub> | 183.8 ns <sub>181.2 ns–199.4 ns</sub> | ✅ -14% |

**2 of 14 benchmarks slower.**
