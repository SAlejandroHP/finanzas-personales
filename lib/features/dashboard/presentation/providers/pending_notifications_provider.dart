import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/pending_notification_manager.dart';
import '../../../../core/services/notification_extraction_service.dart';
import '../../../../core/services/notification_service.dart';

final pendingNotificationsProvider = StateNotifierProvider<PendingNotificationsNotifier, List<RawPendingNotification>>((ref) {
  return PendingNotificationsNotifier();
});

class PendingNotificationsNotifier extends StateNotifier<List<RawPendingNotification>> {
  StreamSubscription? _sub;

  PendingNotificationsNotifier() : super([]) {
    loadPending();
    _sub = NotificationService.onNotification.stream.listen((_) {
      loadPending();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> loadPending() async {
    final pending = await PendingNotificationManager.getPendingNotifications();
    if (mounted) {
      state = pending;
    }
  }

  Future<void> removePending(String id) async {
    await PendingNotificationManager.removeNotification(id);
    await loadPending();
  }

  void addPending(RawPendingNotification notification) {
    state = [...state, notification];
  }
}

final notificationExtractionServiceProvider = Provider<NotificationExtractionService>((ref) {
  return NotificationExtractionService();
});
