import 'package:ailaundry_web/models/clothes_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClothesService {
  final SupabaseClient client;

  ClothesService(this.client);

  Future<List<ClothesItem>> fetchClothes({
    int limit = 100,
    bool ascending = true,
    bool? includeArchived,
  }) async {
    var query = client
        .from('clothes')
        .select('id, brand, color, type, image_url, created_at, status, washer_id, checker_id')
        .order('created_at', ascending: ascending);
    
    final response = await query.limit(limit);
    var items = List<Map<String, dynamic>>.from(response)
        .map((e) => ClothesItem.fromMap(e))
        .toList();
    
    // Filter archived items in code
    if (includeArchived != null) {
      if (includeArchived) {
        // Only archived items (status = 'archived', 'voided', or 'deleted')
        items = items.where((item) {
          final status = item.status?.toLowerCase();
          return status == 'archived' || status == 'voided' || status == 'deleted';
        }).toList();
      } else {
        // Only active items - exclude archived/voided/deleted
        items = items.where((item) {
          final status = item.status?.toLowerCase();
          return status != 'archived' && status != 'voided' && status != 'deleted';
        }).toList();
      }
    }

    return items;
  }

  Future<void> archiveItem(String itemId) async {
    await client
        .from('clothes')
        .update({'status': 'archived'})
        .eq('id', itemId);
  }

  Future<void> unarchiveItem(String itemId) async {
    await client
        .from('clothes')
        .update({'status': 'approved'})
        .eq('id', itemId);
  }

  Future<void> restoreItem(String itemId) async {
    // Restore item - same as unarchive, but semantically clearer
    await client
        .from('clothes')
        .update({'status': 'approved'})
        .eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    // Hard delete - permanently remove the item
    await client
        .from('clothes')
        .delete()
        .eq('id', itemId);
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    // Filter out null values to avoid issues with Supabase
    final cleanUpdates = <String, dynamic>{};
    updates.forEach((key, value) {
      if (value != null) {
        cleanUpdates[key] = value;
      }
    });

    if (cleanUpdates.isEmpty) {
      throw Exception('No valid updates provided');
    }

    try {
      // First, verify the item exists
      final existingItem = await client
          .from('clothes')
          .select('id, status')
          .eq('id', itemId)
          .maybeSingle();

      if (existingItem == null) {
        throw Exception('Item not found with id: $itemId');
      }

      // Execute update and get the count of affected rows
      // Use .select() to get a list, which won't throw if 0 rows
      final updateResponse = await client
          .from('clothes')
          .update(cleanUpdates)
          .eq('id', itemId)
          .select('id');

      // Check if any rows were actually updated
      final updatedRows = List<Map<String, dynamic>>.from(updateResponse);
      if (updatedRows.isEmpty) {
        throw Exception(
          'Update failed: No rows were updated. This usually means:\n'
          '1. Row Level Security (RLS) policies are blocking the update\n'
          '2. The item does not exist or was deleted\n'
          '3. Database constraints are preventing the update\n\n'
          'Item ID: $itemId\n'
          'Original status: ${existingItem['status']}\n'
          'Attempted update: $cleanUpdates'
        );
      }

      // Verify the update by fetching the item separately to check the actual values
      final updatedItem = await client
          .from('clothes')
          .select('id, status')
          .eq('id', itemId)
          .maybeSingle();

      // Verify the update was successful
      if (updatedItem == null) {
        throw Exception(
          'Update failed: Item not found after update. This may be due to:\n'
          '1. Row Level Security (RLS) policies blocking the read\n'
          '2. Item was deleted during the update\n'
          'Original status: ${existingItem['status']}, Attempted update: $cleanUpdates'
        );
      }

      // Verify the status was actually updated if status was in the updates
      if (cleanUpdates.containsKey('status') && updatedItem['status'] != cleanUpdates['status']) {
        throw Exception(
          'Update failed: Status mismatch.\n'
          'Expected: ${cleanUpdates['status']}\n'
          'Got: ${updatedItem['status']}\n'
          'Original: ${existingItem['status']}\n\n'
          'This may indicate RLS policies are reverting the change.'
        );
      }

      // Log status change using RPC function (backup to database trigger)
      if (cleanUpdates.containsKey('status')) {
        final currentUser = client.auth.currentUser;
        try {
          await client.rpc('log_status_change_rpc', params: {
            'p_clothes_id': itemId,
            'p_old_status': existingItem['status'],
            'p_new_status': cleanUpdates['status'] as String,
            'p_changed_by': currentUser?.id,
            'p_notes': 'Status updated via admin panel',
          });
        } catch (e) {
          // Silently fail - the database trigger should handle logging
          // This is just a backup
        }
      }
    } catch (e) {
      // Re-throw with more context, preserving the original error type
      if (e.toString().contains('PGRST116') || e.toString().contains('0 rows')) {
        throw Exception(
          'Update failed: Database returned 0 rows. This usually means:\n'
          '1. Row Level Security (RLS) policies are blocking the update\n'
          '2. The item does not exist\n'
          '3. You do not have permission to update this item\n\n'
          'Original error: ${e.toString()}'
        );
      }
      if (e is Exception) {
        throw e;
      }
      throw Exception('Update failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
