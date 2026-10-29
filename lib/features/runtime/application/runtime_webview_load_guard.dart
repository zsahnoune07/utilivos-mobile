import 'dart:async';

/// Fires [onTimeout] if [arm] is not matched by [clear] within [timeout]
/// (covers WebView hangs where [loadFile] never reaches [onPageStarted]).
final class RuntimeWebViewLoadGuard {
  RuntimeWebViewLoadGuard({
    required this.onTimeout,
    this.timeout = const Duration(seconds: 15),
  });

  final void Function() onTimeout;
  final Duration timeout;
  Timer? _timer;

  void arm() {
    _timer?.cancel();
    _timer = Timer(timeout, onTimeout);
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    clear();
  }
}
