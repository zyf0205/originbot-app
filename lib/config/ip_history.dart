class IpHistory {
  static final List<String> _history = [];
  static String _lastIp = '';
  static const _maxItems = 5;

  static List<String> get history => List.unmodifiable(_history);
  static String get lastIp => _lastIp;

  static void add(String ip) {
    if (ip.trim().isEmpty) return;
    _lastIp = ip;
    _history.remove(ip);
    _history.insert(0, ip);
    if (_history.length > _maxItems) _history.removeLast();
  }
}
