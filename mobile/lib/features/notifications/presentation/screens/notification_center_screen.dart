import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/theme/app_colors.dart';

/// Stores and retrieves notification history from SharedPreferences.
class NotificationStore {
  static const _key = 'notification_history';
  static const _maxItems = 50;

  static Future<List<NotificationItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((json) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return NotificationItem.fromJson(map);
    }).toList();
  }

  static Future<void> add(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    if (raw.length > _maxItems) raw.removeRange(_maxItems, raw.length);
    await prefs.setStringList(_key, raw);

    final count = prefs.getInt('notif_unread_count') ?? 0;
    await prefs.setInt('notif_unread_count', count + 1);
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_unread_count', 0);
  }

  static Future<int> get unreadCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notif_unread_count') ?? 0;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.setInt('notif_unread_count', 0);
  }
}

class NotificationItem {
  final String title;
  final String body;
  final String timestamp;
  final String? type;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    this.type,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    timestamp: json['timestamp'] ?? '',
    type: json['type'],
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'timestamp': timestamp,
    'type': type,
  };

  IconData get icon {
    switch (type) {
      case 'prediction': return Icons.sports_soccer;
      case 'result': return Icons.emoji_events;
      case 'combo': return Icons.layers;
      case 'live': return Icons.bolt;
      case 'promo': return Icons.local_offer;
      default: return Icons.notifications;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'prediction': return AppColors.gold;
      case 'result': return AppColors.emerald;
      case 'combo': return Colors.deepPurple;
      case 'live': return Colors.orange;
      case 'promo': return Colors.pinkAccent;
      default: return AppColors.textSecondary;
    }
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<NotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationStore.getAll();
    await NotificationStore.markAllRead();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();
    await NotificationStore.clear();
    if (mounted) setState(() => _items = []);
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
      if (diff.inDays < 7) return "Il y a ${diff.inDays}j";
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 22),
              onPressed: _clearAll,
              tooltip: "Tout effacer",
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        "Aucune notification",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Vos notifications apparaîtront ici",
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  separatorBuilder: (c, i) => Divider(
                    color: AppColors.surfaceLight.withValues(alpha: 0.3),
                    height: 1,
                    indent: 60,
                  ),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 20),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatTime(item.timestamp),
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
