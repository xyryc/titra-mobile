import 'dart:async';

/// Global bridge for native call UI actions that need to reach the active call screen.
abstract final class CallControlBus {
  static final StreamController<String> _hangUpRequests =
      StreamController<String>.broadcast();

  static Stream<String> get onHangUpRequested => _hangUpRequests.stream;

  static void requestHangUp(String callSessionId) {
    if (callSessionId.isEmpty || _hangUpRequests.isClosed) {
      return;
    }
    _hangUpRequests.add(callSessionId);
  }
}
