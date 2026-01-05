import 'package:ailaundry_web/models/status_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatusHistoryService {
  final SupabaseClient client;

  StatusHistoryService(this.client);

  /// Log a status change to status_history table using RPC function
  /// This is a backup to the database trigger, ensuring status changes are always logged
  /// Can be called from any service/method easily
  /// 
  /// Note: You can also use StatusHistoryUtils.logStatusChange() for a simpler API
  Future<void> logStatusChange({
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

  /// Fetch status history for a specific clothes item
  Future<List<StatusHistory>> getStatusHistory(String clothesId) async {
    try {
      final response = await client
          .from('status_history')
          .select()
          .eq('clothes_id', clothesId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((e) => StatusHistory.fromMap(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch all status history with optional filters
  Future<List<StatusHistory>> getAllStatusHistory({
    String? clothesId,
    String? status,
    String? changedBy,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      var query = client.from('status_history').select();

      if (clothesId != null) {
        query = query.eq('clothes_id', clothesId);
      }
      if (status != null) {
        query = query.eq('new_status', status);
      }
      if (changedBy != null) {
        query = query.eq('changed_by', changedBy);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      // Apply order and limit - need to handle type changes
      dynamic orderedQuery = query.order('created_at', ascending: false);
      
      if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }

      final response = await orderedQuery;
      return List<Map<String, dynamic>>.from(response)
          .map((e) => StatusHistory.fromMap(e))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
