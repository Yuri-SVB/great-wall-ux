import 'dart:async';

import 'package:flutter/widgets.dart';

/// Drives pause/resume callbacks across a Flutter app lifecycle.
///
/// The training flow's "don't lose an in-progress practice session on app
/// switch" requirement (`SCOPE.md`) lives here. Consumers register
/// callbacks; the manager wires up a `WidgetsBindingObserver` and dispatches
/// them. The manager carries no session state itself — it is glue.
class SessionLifecycleManager with WidgetsBindingObserver {
  SessionLifecycleManager({
    this.onPause,
    this.onResume,
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;
  final FutureOr<void> Function()? onPause;
  final FutureOr<void> Function()? onResume;

  bool _paused = false;
  bool get isPaused => _paused;

  void dispose() {
    _binding.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_paused) {
          _paused = true;
          if (onPause != null) {
            // Fire-and-forget: lifecycle callbacks should not block the
            // framework. Errors are the consumer's to handle.
            Future<void>.sync(onPause!);
          }
        }
      case AppLifecycleState.resumed:
        if (_paused) {
          _paused = false;
          if (onResume != null) {
            Future<void>.sync(onResume!);
          }
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}
