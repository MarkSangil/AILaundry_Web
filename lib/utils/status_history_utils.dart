import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class for logging status changes using RPC function
/// This makes it easy to integrate status history logging in any method
class StatusHistoryUtils {
  /// Log a status change using the RPC function
  /// This can be called from any service or method easily
  /// 
  /// Example usage:
  /// ```dart
  /// await StatusHistoryUtils.logStatusChange(
  ///   client: supabase.client,
  ///   clothesId: itemId,
  ///   oldStatus: 'pending',
  ///   newStatus: 'approved',
  ///   notes: 'Approved by admin',
  /// );
  /// ```
  static Future<void> logStatusChange({
    required SupabaseClient client,
    required String clothesId,
    String? oldStatus,
    required String newStatus,
    String? changedBy,
    String? notes,
  }) async {
    try {
      await client.rpc('log_status_change_rpc', params: {
        'p_clothes_id': clothesId,
        'p_old_status': oldStatus,
        'p_new_status': newStatus,
        'p_changed_by': changedBy,
        'p_notes': notes,
      });
    } catch (e) {
      // Silently fail - the database trigger should handle logging
      // This is just a backup
    }
  }

  /// Get the current user ID from the client
  /// Helper method to get the user ID for changed_by parameter
  static String? getCurrentUserId(SupabaseClient client) {
    return client.auth.currentUser?.id;
  }
}
