import 'dart:async';

import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The minimal router surface [MicNavigationBinding] needs (design §19.6,
/// D28): a [Listenable] that notifies on every navigation event (push, pop,
/// redirect, or a shell branch switch), plus the current location to
/// compare against. Matches `GoRouter.routerDelegate` exactly — production
/// code wraps the real router ([GoRouterLocationSource]) while a test
/// substitutes a lightweight fake without building a whole [GoRouter].
abstract interface class MicRouterLocationSource {
  Listenable get listenable;
  Uri get location;
}

/// Adapts a real [GoRouter] to [MicRouterLocationSource].
final class GoRouterLocationSource implements MicRouterLocationSource {
  const new(this._router);

  final GoRouter _router;

  @override
  Listenable get listenable => _router.routerDelegate;

  @override
  Uri get location => _router.routerDelegate.currentConfiguration.uri;
}

/// Cancels an in-progress mic capture — [MicController.cancelActiveCapture]
/// only ever acts on `RequestingPermission`/`Recording`, so an in-flight
/// delivery is NEVER cancelled here (design D28) — on:
///
/// - any router path change (tab switch, push, pop, redirect);
/// - the bound registration being disposed, or no longer the top
///   [MicTargetRegistry.resolve] returns (`MicController.boundToken`
///   mismatch) — e.g. another `MicTargetScope` registering above it with no
///   router navigation at all;
/// - the app being hidden/paused — `cancelledByBackground` is emitted only
///   once the app is visible again, never while backgrounded (there is no
///   UI to show it to); `inactive` (a transient system dialog) never
///   triggers anything, since no callback is registered for it.
///
/// `cancelActiveCapture`/`emitNotice` are the two primitives this composes;
/// both are idempotent no-ops once the mic is already idle, so a repeat
/// trigger (e.g. `MicTargetRegistry.setActiveBranch`'s own idempotent
/// same-index guard, or `onHide` immediately followed by `onPause` for one
/// real transition) never double-cancels or double-notifies.
final class MicNavigationBinding {
  new({
    required this.registry,
    required MicController? Function() controllerOf,
    required this.routerSource,
    this.onLocationChanged,
    this.onRegistryEvent,
    // Named `controllerOf` (not `_controllerOf`) so external callers (the
    // shell, tests) can pass it — an initializing formal would force the
    // private field name onto the public constructor signature (same
    // reasoning as `MicController`'s own `registry`/`clock` params).
    // ignore: prefer_initializing_formals
  }) : _controllerOf = controllerOf {
    _location = routerSource.location;
    routerSource.listenable.addListener(_onRouterChanged);
    _registrySubscription = registry.changes.listen(
      (_) => _onRegistryChanged(),
    );
    _lifecycleListener = AppLifecycleListener(
      onHide: _onBackgrounded,
      onPause: _onBackgrounded,
      onResume: _onResumed,
    );
  }

  final MicTargetRegistry registry;
  final MicController? Function() _controllerOf;
  final MicRouterLocationSource routerSource;

  /// Fires on every REAL router path change (never on a same-uri
  /// notification) — `QuickPracticeTarget.onRouterLocationChanged` (U23e,
  /// design §19.13) is this binding's intended consumer: any navigation
  /// invalidates a prepared-but-not-yet-recorded quick-practice session,
  /// independent of whether the resolved mic target itself changes.
  final VoidCallback? onLocationChanged;

  /// Fires on every [MicTargetRegistry.changes] event, independent of
  /// whether a capture happens to be bound —
  /// `QuickPracticeTarget.onRegistryChanged` (U23e) is this binding's
  /// intended consumer; it decides for itself whether the event actually
  /// changed who `resolve()` returns.
  final VoidCallback? onRegistryEvent;

  late final AppLifecycleListener _lifecycleListener;
  late final StreamSubscription<void> _registrySubscription;
  late Uri _location;
  bool _backgroundNoticePending = false;

  void _onRouterChanged() {
    final next = routerSource.location;
    if (next == _location) return;
    _location = next;
    _cancel(MicNotice.cancelledByNavigation);
    onLocationChanged?.call();
  }

  void _onRegistryChanged() {
    final controller = _controllerOf();
    if (controller != null) {
      final boundToken = controller.boundToken;
      if (boundToken != null) {
        final (_, token) = registry.resolve();
        if (!identical(token, boundToken)) {
          _cancel(MicNotice.cancelledByNavigation);
        }
      }
    }
    onRegistryEvent?.call();
  }

  void _onBackgrounded() {
    if (_controllerOf()?.cancelActiveCapture() ?? false) {
      _backgroundNoticePending = true;
    }
  }

  void _onResumed() {
    if (!_backgroundNoticePending) return;
    _backgroundNoticePending = false;
    _controllerOf()?.emitNotice(MicNotice.cancelledByBackground);
  }

  void _cancel(MicNotice notice) {
    final controller = _controllerOf();
    if (controller == null) return;
    if (controller.cancelActiveCapture()) controller.emitNotice(notice);
  }

  /// Detaches from [routerSource]/[registry] and disposes the underlying
  /// [AppLifecycleListener]. Safe to call from a widget's `dispose()`.
  void dispose() {
    routerSource.listenable.removeListener(_onRouterChanged);
    unawaited(_registrySubscription.cancel());
    _lifecycleListener.dispose();
  }
}
