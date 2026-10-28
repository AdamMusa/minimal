# minimal_mvn: before vs after

* **Before**: `upstream/main@599b2ae`
* **After**: `benchmark/before-after@c3f7716`
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

Release builds (AOT), 3 per version, each with a different code layout, since nanosecond benchmarks depend on code alignment. Each benchmark runs in its own process, before and after alternating, 4 rounds per build; a round is the median of 15 runs after 5 warm-ups. Each cell is the median across builds of their fastest round (other processes can only slow a round down), with the range across builds. Lower is better; changes within ±3% are reported as equal.

| Benchmark | Selector runs | Before | After | Change |
| --- | --- | --- | --- | --- |
| Notifier with 1 listener(s), per state change |  | 7.84 ns <sub>7.83 ns–7.84 ns</sub> | 7.95 ns <sub>7.92 ns–7.99 ns</sub> | = +1% |
| Notifier with 10 listener(s), per state change |  | 23.8 ns <sub>23.8 ns–23.9 ns</sub> | 23.8 ns <sub>23.8 ns–23.9 ns</sub> | = -0% |
| manager.notifier, per access |  | 4.05 ns <sub>4.05 ns–4.06 ns</sub> | 4.06 ns <sub>4.05 ns–4.06 ns</sub> | = +0% |
| 1 selection with 1 listener(s), per state change | 1 → 1 | 20.8 ns <sub>20.8 ns–20.8 ns</sub> | 18.9 ns <sub>18.8 ns–19.0 ns</sub> | ✅ -9% |
| 1 selection with 10 listener(s), per state change | 10 → 1 | 145.1 ns <sub>141.9 ns–148.9 ns</sub> | 35.8 ns <sub>35.6 ns–35.8 ns</sub> | ✅ -75% |
| 1 selection with 100 listener(s), per state change | 100 → 1 | 1.15 µs <sub>1.15 µs–1.16 µs</sub> | 184.9 ns <sub>184.8 ns–185.3 ns</sub> | ✅ -84% |
| 1 selection read by its listener (ValueListenableBuilder), per state change |  | 20.3 ns <sub>20.2 ns–20.4 ns</sub> | 19.8 ns <sub>19.6 ns–19.8 ns</sub> | = -2% |
| Autodispose notifier created, listened, updated and disposed |  | 61.3 ns <sub>60.8 ns–61.6 ns</sub> | 62.3 ns <sub>62.0 ns–62.9 ns</sub> | = +2% |
| Autodispose notifier created, listened via select(), updated and disposed |  | 184.2 ns <sub>180.9 ns–184.2 ns</sub> | 144.7 ns <sub>143.9 ns–145.1 ns</sub> | ✅ -21% |
| 100 selections with 1 listener each, per state change |  | 1.63 µs <sub>1.59 µs–1.64 µs</sub> | 1.26 µs <sub>1.25 µs–1.26 µs</sub> | ✅ -23% |
| addListener + removeListener, with 0 other listeners |  | 43.2 ns <sub>43.0 ns–43.3 ns</sub> | 42.9 ns <sub>42.9 ns–43.2 ns</sub> | = -1% |
| addListener + removeListener, with 10 other listeners |  | 426.6 ns <sub>425.5 ns–426.8 ns</sub> | 425.9 ns <sub>425.2 ns–426.0 ns</sub> | = -0% |
| addListener + removeListener, with 100 other listeners |  | 3.83 µs <sub>3.82 µs–3.83 µs</sub> | 3.82 µs <sub>3.81 µs–3.82 µs</sub> | = -0% |
| select() + addListener + removeListener, 10 per event loop turn |  | 209.7 ns <sub>209.4 ns–210.2 ns</sub> | 182.2 ns <sub>181.3 ns–182.6 ns</sub> | ✅ -13% |
| select() in build(): a widget swapping its selection, 10 per event loop turn |  | 161.4 ns <sub>161.0 ns–161.8 ns</sub> | 134.0 ns <sub>133.3 ns–134.1 ns</sub> | ✅ -17% |

**No benchmark is slower.**
