import 'package:ailaundry_web/models/washer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WasherService {
  final SupabaseClient client;

  WasherService(this.client);

  Future<List<Washer>> fetchWashers({String? role}) async {
    var query = client.from('laundry_users').select();
    
    if (role != null) {
      query = query.eq('role', role);
    }
    
    final response = await query.order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Washer.fromMap(e))
        .toList();
  }

  Future<List<Washer>> fetchAllUsers() async {
    final response = await client
        .from('laundry_users')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Washer.fromMap(e))
        .toList();
  }

  /// Create a washer by directly inserting into laundry_users (legacy method)
  /// Note: This doesn't create an auth user. Use createWasherWithAuth instead.
  Future<Washer> createWasher(Washer washer) async {
    final response = await client
        .from('laundry_users')
        .insert(washer.toMap(includeIsActive: false))
        .select()
        .single();

    return Washer.fromMap(response);
  }

  /// Create a user with Supabase Auth and send invitation email
  /// This method:
  /// 1. Calls the invite-user Edge Function (uses service role key server-side)
  /// 2. Edge Function creates auth user via inviteUserByEmail
  /// 3. Sends invitation email automatically
  /// 4. SQL trigger automatically creates laundry_users record
  /// 
  /// Returns the created Washer object
  Future<Washer> createWasherWithAuth({
    required String name,
    required String email,
    required String role,
    String? redirectTo,
  }) async {
    try {
      // Call the Edge Function to invite user
      // The Edge Function uses service role key and handles admin privileges
      final response = await client.functions.invoke(
        'invite-user',
        body: {
          'name': name,
          'email': email,
          'role': role,
          if (redirectTo != null) 'redirectTo': redirectTo,
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        final errorMessage = errorData is Map
            ? (errorData['error'] as String? ?? 'Failed to create user')
            : 'Failed to create user';
        throw Exception(errorMessage);
      }

      final responseData = response.data as Map<String, dynamic>;
      final userData = responseData['user'] as Map<String, dynamic>?;

      if (userData == null) {
        throw Exception('Failed to create user: No user data returned');
      }

      return Washer.fromMap(userData);
    } catch (e) {
      throw Exception('Failed to create user with auth: $e');
    }
  }

  Future<Washer> updateWasher(String id, Map<String, dynamic> updates) async {
    final response = await client
        .from('laundry_users')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Washer.fromMap(response);
  }

  Future<void> deleteWasher(String id) async {
    await client.from('laundry_users').delete().eq('id', id);
  }

  Future<void> toggleUserStatus(String id, bool isActive) async {
    try {
      // Update the status
      final updateResponse = await client
          .from('laundry_users')
          .update({'is_active': isActive})
          .eq('id', id);
      
      // Verify the update worked by fetching the record
      final verifyResponse = await client
          .from('laundry_users')
          .select('is_active')
          .eq('id', id)
          .maybeSingle();
      
      if (verifyResponse == null) {
        throw Exception('User not found');
      }
      
      if (verifyResponse['is_active'] != isActive) {
        throw Exception('Failed to update user status: database value does not match');
      }
    } catch (e) {
      // If is_active column doesn't exist, throw a helpful error
      if (e.toString().contains('is_active') || 
          e.toString().contains('PGRST204') ||
          (e.toString().contains('column') && e.toString().contains('does not exist'))) {
        throw Exception('The is_active column does not exist in the database. Please run the migration to add it.');
      }
      rethrow;
    }
  }
}

