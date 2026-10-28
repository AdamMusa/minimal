// Let's make the tests more readable and explicit
// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_mvn/minimal_mvn.dart';

class TRepository {
  String read() => 'real';
}

class TFakeRepository implements TRepository {
  @override
  String read() => 'fake';
}

class TRepositoryNotifier extends MMNotifier<String> {
  TRepositoryNotifier(this._repository) : super('');

  final TRepository _repository;

  void load() => notify(_repository.read());
}

void main() {
  group('MMLocator', () {
    test('creates instance lazily', () {
      var created = 0;
      final locator = MMLocator(() {
        created++;
        return 42;
      });
      expect(created, 0);
      locator.instance;
      expect(created, 1);
      locator.instance;
      expect(created, 1);
    });

    test('returns same instance', () {
      final locator = MMLocator(() => <String>[]);
      final first = locator.instance;
      final second = locator.instance;
      expect(second, same(first));
    });

    test('overrides the instance lazily', () {
      var created = 0;
      final locator = MMLocator<num>(() => 42);
      final original = locator.instance;

      locator.override(() {
        created++;
        return 7;
      });
      expect(created, 0);
      expect(locator.instance, 7);
      expect(locator.instance, isNot(original));
      locator.instance;
      expect(created, 1);
    });

    test('injects the override into notifiers', () {
      final locator = MMLocator<TRepository>(TRepository.new);
      final manager = MMManager(() => TRepositoryNotifier(locator.instance));

      // the notifier is created lazily, so it gets the overridden repository
      locator.override(TFakeRepository.new);
      manager.notifier.load();

      expect(manager.notifier.state, 'fake');
    });

    test('resets to the original factory', () {
      final locator = MMLocator<num>(() => 42);
      locator.override(() => 7);
      expect(locator.instance, 7);

      locator.reset();
      expect(locator.instance, 42);
    });
  });
}
