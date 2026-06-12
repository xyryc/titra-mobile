/// Prevents overlapping calls (incoming UI vs active session).
class ActiveCallGuard {
  ActiveCallGuard._();

  static String? currentCallSessionId;

  static bool get hasActiveCall =>
      currentCallSessionId != null && currentCallSessionId!.isNotEmpty;

  static void enter(String callSessionId) {
    currentCallSessionId = callSessionId;
  }

  static void clearIfMatches(String callSessionId) {
    if (currentCallSessionId == callSessionId) {
      currentCallSessionId = null;
    }
  }

  static void clear() {
    currentCallSessionId = null;
  }
}
