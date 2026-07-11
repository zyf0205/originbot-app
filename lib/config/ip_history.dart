import 'package:shared_preferences/shared_preferences.dart';

class IpHistory {
  static final List<String> _history = [];
  static String _lastIp = '';
  static const _maxItems = 5;
  static const _keyHistory = 'ip_history';
  static const _keyLastIp = 'last_ip';

  static List<String> get history => List.unmodifiable(_history);
  static String get lastIp => _lastIp;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _history
      ..clear()
      ..addAll(prefs.getStringList(_keyHistory) ?? <String>[]);
    _lastIp = prefs.getString(_keyLastIp) ?? '';
  }

  static Future<void> add(String ip) async {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return;
    _lastIp = trimmed;
    _history.remove(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > _maxItems) _history.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyHistory, _history);
    await prefs.setString(_keyLastIp, _lastIp);
  }
}
