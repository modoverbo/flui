import 'dart:async';

import 'package:flui/core/mic/mic_target.dart';

/// Layered registry of [MicTarget]s (design §19.4, D24): one `root` stack
/// for root-navigator screens, plus one stack per shell branch index. The
/// shell's single mic always resolves the top of whichever stack currently
/// applies, never a stale entry lower in it.
final class MicTargetRegistry {
  final _root = <_Entry>[];
  final _branches = <int, List<_Entry>>{};
  int _activeBranch = 0;
  MicTarget _fallback = const ExplainedFallbackTarget();

  final _changesController = StreamController<void>.broadcast();

  /// Fires on registration, disposal, and [MicRegistration.update].
  Stream<void> get changes => _changesController.stream;

  /// Registers [target] on the `root` stack, or on [branch]'s stack
  /// (defaulting to the currently active branch when omitted) when [layer]
  /// is [MicLayer.branch]. Last-registered-wins within that stack.
  MicRegistration register(
    MicTarget target, {
    required MicLayer layer,
    int? branch,
  }) {
    final entry = _Entry(
      this,
      layer,
      layer == MicLayer.root ? null : (branch ?? _activeBranch),
      target,
    );
    _stackFor(entry).add(entry);
    _notifyChanged();
    return entry;
  }

  /// Switches which branch stack [resolve] consults. Does not move any
  /// registration between stacks — each stays attached to the branch it
  /// was registered under. Kept as a method (design §19.4/§19.7 call it
  /// `setActiveBranch(i)`), not a setter, to match the frozen contract
  /// other units wire against.
  // ignore: use_setters_to_change_properties
  void setActiveBranch(int index) => _activeBranch = index;

  /// Replaces the fallback used when nothing else resolves (U23e overrides
  /// this with `QuickPracticeTarget`, design §19.4/D27). Kept as a method
  /// for the same reason as [setActiveBranch].
  // ignore: use_setters_to_change_properties
  void setFallback(MicTarget target) => _fallback = target;

  /// The top `root` entry if any; else the active branch stack's top entry
  /// whose [MicTarget.availability] is not [MicPassThrough]; else the
  /// fallback. Never null. The returned token identifies this exact
  /// resolution so a caller can later tell whether it is still current.
  (MicTarget, Object) resolve() {
    if (_root.isNotEmpty) {
      final top = _root.last;
      return (top.target, top);
    }
    final stack = _branches[_activeBranch];
    if (stack != null) {
      for (final entry in stack.reversed) {
        if (entry.target.availability is! MicPassThrough) {
          return (entry.target, entry);
        }
      }
    }
    return (_fallback, _fallback);
  }

  List<_Entry> _stackFor(_Entry entry) =>
      entry.layer == MicLayer.root ? _root : (_branches[entry.branch!] ??= []);

  void _remove(_Entry entry) {
    _stackFor(entry).remove(entry);
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!_changesController.isClosed) _changesController.add(null);
  }

  /// Closes [changes]. Safe to call from a provider's `ref.onDispose`.
  void dispose() {
    if (!_changesController.isClosed) unawaited(_changesController.close());
  }
}

final class _Entry implements MicRegistration {
  new(this._registry, this.layer, this.branch, this.target);

  final MicTargetRegistry _registry;
  final MicLayer layer;
  final int? branch;
  MicTarget target;
  bool _disposed = false;

  @override
  void update(MicTarget target) {
    if (_disposed) return;
    this.target = target;
    _registry._notifyChanged();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _registry._remove(this);
  }
}
