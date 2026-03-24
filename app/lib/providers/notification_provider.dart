import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_item.dart';
import '../services/api/api_client.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

class NotificationApi {
  final ApiClient _client;
  NotificationApi(this._client);

  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    final response = await _client.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.patch('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _client.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _client.delete('/notifications/$id');
  }

  Future<void> registerFcmToken(String token) async {
    await _client.post(
      '/notifications/fcm-token',
      data: {'token': token},
    );
  }
}

final notificationApiProvider = Provider<NotificationApi>(
  (ref) => NotificationApi(ref.watch(apiClientProvider)),
);

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  final NotificationApi _api;

  NotificationNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await _api.getNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      AppLogger.error('Load notifications failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.markAsRead(id);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
      );
    } catch (e) {
      AppLogger.error('Mark read failed: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.markAllAsRead();
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (e) {
      AppLogger.error('Mark all read failed: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.deleteNotification(id);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((n) => n.id != id).toList());
    } catch (e) {
      AppLogger.error('Delete notification failed: $e');
    }
  }

  void addLocalNotification(NotificationItem notification) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([notification, ...current]);
  }

  Future<void> refresh() => _load();
}

final notificationProvider = StateNotifierProvider<NotificationNotifier,
    AsyncValue<List<NotificationItem>>>(
  (ref) => NotificationNotifier(ref.watch(notificationApiProvider)),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationProvider)
      .valueOrNull
      ?.where((n) => !n.isRead)
      .length ?? 0;
});
