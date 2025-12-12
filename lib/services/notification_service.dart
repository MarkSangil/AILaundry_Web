import 'package:ailaundry_web/models/notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient client;

  NotificationService(this.client);

  /// Fetch all notifications for the current user
  Future<List<Notification>> fetchNotifications({bool? unreadOnly}) async {
    var query = client
        .from('notifications')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .order('created_at', ascending: false);

    if (unreadOnly == true) {
      query = query.eq('is_read', false);
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Notification.fromMap(e))
        .toList();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('user_id', client.auth.currentUser!.id);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', client.auth.currentUser!.id)
        .eq('is_read', false);
  }

  /// Get count of unread notifications
  Future<int> getUnreadCount() async {
    final response = await client
        .from('notifications')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('user_id', client.auth.currentUser!.id)
        .eq('is_read', false);

    return response.count ?? 0;
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await client
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('user_id', client.auth.currentUser!.id);
  }
}

