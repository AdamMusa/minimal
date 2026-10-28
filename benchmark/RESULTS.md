# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@3eb490f`
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
| A one-shot listener (removing itself when notified) leaves the notifier usable | ❌ 1 error(s) ("The "dispose()" method on Instance of 'BNotifier' was called during the call to "notifyListeners()". This is likely to cause errors since it modifies the list of listeners while the list is being used.") | ✅ no error, disposed with the next unsubscription |
| A selection without listeners reports the current value | ❌ read "", state is "new" | ✅ read "new", state is "new" |
| select() in build(): state survives 100 rebuilds | ❌ 50 errors ("A BNotifier was used after being disposed.") + 1 on unmount, 51 notifier instances, shows "1" (expected "100") | ✅ 0 errors, 1 notifier instances, shows "100" (expected "100") |
| A selection in a hidden tab shows the current state (#10) | ❌ shows "b:" (expected "b:moved") | ✅ shows "b:moved" (expected "b:moved") |

**9 of 9 scenarios fixed.**

## Performance

Release build (AOT), each benchmark in its own process, before and after alternating, 8 rounds. Each cell is the median across rounds, with the range; each round is itself the median of 15 runs after 5 warm-ups. Lower is better; changes within ±3% are reported as equal.

| Benchmark | Selector runs | Before | After | Change |
| --- | --- | --- | --- | --- |
| Notifier with 1 listener(s), per state change |  | 7.97 ns <sub>7.86 ns–8.14 ns</sub> | 8.20 ns <sub>8.07 ns–8.37 ns</sub> | = +3% |
| Notifier with 10 listener(s), per state change |  | 24.0 ns <sub>23.9 ns–24.3 ns</sub> | 24.4 ns <sub>24.1 ns–24.6 ns</sub> | = +1% |
| manager.notifier, per access |  | 2.66 ns <sub>2.66 ns–2.67 ns</sub> | 2.67 ns <sub>2.66 ns–2.68 ns</sub> | = +0% |
| 1 selection with 1 listener(s), per state change | 1 → 1 | 20.9 ns <sub>20.6 ns–21.2 ns</sub> | 19.6 ns <sub>19.4 ns–19.9 ns</sub> | ✅ -6% |
| 1 selection with 10 listener(s), per state change | 10 → 1 | 145.5 ns <sub>140.8 ns–159.1 ns</sub> | 36.5 ns <sub>36.2 ns–36.7 ns</sub> | ✅ -75% |
| 1 selection with 100 listener(s), per state change | 100 → 1 | 1.22 µs <sub>1.17 µs–1.26 µs</sub> | 189.3 ns <sub>184.9 ns–190.0 ns</sub> | ✅ -84% |
| 1 selection read by its listener (ValueListenableBuilder), per state change |  | 20.6 ns <sub>20.5 ns–20.9 ns</sub> | 20.6 ns <sub>20.4 ns–20.6 ns</sub> | = -0% |
| Autodispose notifier created, listened, updated and disposed |  | 60.5 ns <sub>60.1 ns–61.4 ns</sub> | 61.3 ns <sub>60.5 ns–62.1 ns</sub> | = +1% |
| Autodispose notifier created, listened via select(), updated and disposed |  | 183.5 ns <sub>177.2 ns–185.9 ns</sub> | 143.8 ns <sub>143.5 ns–146.3 ns</sub> | ✅ -22% |
| 100 selections with 1 listener each, per state change |  | 1.59 µs <sub>1.53 µs–1.60 µs</sub> | 1.27 µs <sub>1.25 µs–1.28 µs</sub> | ✅ -20% |
| addListener + removeListener, with 0 other listeners |  | 43.2 ns <sub>43.0 ns–45.4 ns</sub> | 43.1 ns <sub>42.8 ns–43.2 ns</sub> | = -0% |
| addListener + removeListener, with 10 other listeners |  | 430.6 ns <sub>428.3 ns–453.5 ns</sub> | 429.0 ns <sub>426.3 ns–446.8 ns</sub> | = -0% |
| addListener + removeListener, with 100 other listeners |  | 3.86 µs <sub>3.83 µs–4.06 µs</sub> | 3.84 µs <sub>3.82 µs–3.98 µs</sub> | = -1% |
| select() + addListener + removeListener, 10 per event loop turn |  | 211.4 ns <sub>208.8 ns–222.8 ns</sub> | 181.5 ns <sub>180.0 ns–183.2 ns</sub> | ✅ -14% |

**No benchmark is slower.**
