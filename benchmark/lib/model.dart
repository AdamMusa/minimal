import 'package:flutter/foundation.dart';
import 'package:minimal_mvn/minimal_mvn.dart';

@immutable
class BState {
  const BState(this.value, this.text);

  final int value;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is BState && value == other.value && text == other.text;

  @override
  int get hashCode => Object.hash(value, text);
}

class BNotifier extends MMNotifier<BState> {
  BNotifier() : super(const BState(0, '')) {
    created++;
  }

  static var created = 0;

  void increment() => notify(BState(state.value + 1, state.text));

  void append(String suffix) => notify(BState(state.value, '${state.text}$suffix'));

  bool get isDisposed => disposed;
}
