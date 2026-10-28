import 'package:flutter/foundation.dart';

/// Minimal locator
///
/// A minimal locator is responsible for holding a singleton instance of any
/// class, usually a repository or a service. It lazily creates the instance,
/// and provides access to it
///
/// Example:
/// ```dart
/// final settingsLocator = MMLocator(
///   () => SettingsRepository(),
/// );
/// ```
class MMLocator<T> {
  /// Creates a minimal locator for the given class type
  MMLocator(this._create);

  T? _instance;
  final T Function() _create;
  T Function()? _override;

  /// Returns the instance managed by this locator
  ///
  /// If no instance exists, a new one will be created. The same instance will
  /// be returned on subsequent calls
  ///
  /// Example:
  /// ```dart
  /// final settings = settingsLocator.instance;
  /// await settings.load();
  /// ```
  T get instance {
    final creator = _override ?? _create;
    _instance ??= creator();
    return _instance!;
  }

  /// Overrides the instance factory for testing purposes
  ///
  /// The current instance is dropped, and the next access to [instance]
  /// lazily creates one through [override]. This method is only available in
  /// tests and should not be used in production
  ///
  /// Example:
  /// ```dart
  /// tasksRepositoryLocator.override(FakeTasksRepository.new);
  /// ```
  @visibleForTesting
  void override(final T Function() override) {
    _override = override;
    _instance = null;
  }

  /// Removes any override, dropping the current instance, so that the next
  /// access to [instance] lazily creates one through the original factory
  ///
  /// Example:
  /// ```dart
  /// tearDown(tasksRepositoryLocator.reset);
  /// ```
  @visibleForTesting
  void reset() {
    _override = null;
    _instance = null;
  }
}
