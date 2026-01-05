import 'package:ailaundry_web/models/login_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginHistoryService {
  final SupabaseClient client;

  LoginHistoryService(this.client);

  /// Log a user login
  /// Only creates a new entry if there's no active session (previous session was logged out)
  Future<String?> logLogin({
    required String userId,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Check if there's an active session (no logout_at)
      // Get recent logins and filter for active sessions in code
      final recentLogins = await client
          .from('login_history')
          .select('id, logout_at')
          .eq('user_id', userId)
          .order('login_at', ascending: false)
          .limit(10);
      
      final activeSession = List<Map<String, dynamic>>.from(recentLogins)
          .firstWhere(
            (login) => login['logout_at'] == null,
            orElse: () => <String, dynamic>{},
          );

      // If there's an active session, don't create a new entry
      if (activeSession.isNotEmpty && activeSession['id'] != null) {
        // Return the existing active session ID
        return activeSession['id'] as String;
      }

      // No active session found, create a new login entry
      try {
        final response = await client.rpc('log_user_login', params: {
          'p_user_id': userId,
          'p_ip_address': ipAddress,
          'p_user_agent': userAgent,
        });
        return response.toString();
      } catch (e) {
        // If RPC fails, try direct insert
        try {
          final response = await client
              .from('login_history')
              .insert({
                'user_id': userId,
                'ip_address': ipAddress,
                'user_agent': userAgent,
              })
              .select('id')
              .single();
          return response['id'] as String;
        } catch (e2) {
          throw Exception('Failed to log login: $e2');
        }
      }
    } catch (e) {
      return null;
    }
  }

  /// Log a user logout
  Future<void> logLogout(String loginId) async {
    try {
      await client.rpc('log_user_logout', params: {
        'p_login_id': loginId,
      });
    } catch (e) {
      // If RPC fails, try direct update
      try {
        final loginRecord = await client
            .from('login_history')
            .select('login_at')
            .eq('id', loginId)
            .single();

        if (loginRecord['login_at'] != null) {
          final loginAt = DateTime.parse(loginRecord['login_at']);
          final now = DateTime.now();
          final duration = now.difference(loginAt);

          await client
              .from('login_history')
              .update({
                'logout_at': now.toIso8601String(),
                'session_duration': '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
              })
              .eq('id', loginId);
        }
      } catch (e2) {
      }
    }
  }

  /// Fetch login history for all users (admin only)
  Future<List<LoginHistory>> fetchAllLoginHistory({
    int? limit,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = client
        .from('login_history')
        .select('''
          *,
          laundry_users:user_id (
            name,
            email,
            role
          )
        ''');

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    if (startDate != null) {
      query = query.gte('login_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('login_at', endDate.toIso8601String());
    }

    // Chain order and limit in a single call
    final response = limit != null
        ? await query.order('login_at', ascending: false).limit(limit)
        : await query.order('login_at', ascending: false);

    return List<Map<String, dynamic>>.from(response).map((map) {
      // Flatten the nested user data
      final userData = map['laundry_users'];
      if (userData != null && userData is Map) {
        map['user_name'] = userData['name'];
        map['user_email'] = userData['email'];
        map['user_role'] = userData['role'];
      }
      return LoginHistory.fromMap(map);
    }).toList();
  }

  /// Get login statistics
  Future<Map<String, dynamic>> getLoginStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = client.from('login_history').select('id, login_at, logout_at');

    if (startDate != null) {
      query = query.gte('login_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('login_at', endDate.toIso8601String());
    }

    final response = await query;
    final records = List<Map<String, dynamic>>.from(response);

    final totalLogins = records.length;
    final activeSessions = records.where((r) => r['logout_at'] == null).length;
    final uniqueUsers = records.map((r) => r['user_id']).toSet().length;

    return {
      'totalLogins': totalLogins,
      'activeSessions': activeSessions,
      'uniqueUsers': uniqueUsers,
    };
  }
}

