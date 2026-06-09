import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RawPendingNotification {
  final String id;
  final String packageName;
  final String title;
  final String text;
  final DateTime timestamp;

  RawPendingNotification({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'packageName': packageName,
    'title': title,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RawPendingNotification.fromJson(Map<String, dynamic> json) => RawPendingNotification(
    id: json['id'] as String,
    packageName: json['packageName'] as String,
    title: json['title'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class PendingNotificationManager {
  static const String _key = 'pending_bank_notifications_v1';

  static Future<void> saveNotification(RawPendingNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_key) ?? [];
    current.add(jsonEncode(notification.toJson()));
    await prefs.setStringList(_key, current);
  }

  static Future<List<RawPendingNotification>> getPendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_key) ?? [];
    return current.map((e) => RawPendingNotification.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> removeNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_key) ?? [];
    
    final updated = current.where((element) {
      final decoded = jsonDecode(element);
      return decoded['id'] != id;
    }).toList();
    
    await prefs.setStringList(_key, updated);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
