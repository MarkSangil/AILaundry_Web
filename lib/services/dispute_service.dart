import 'package:ailaundry_web/models/dispute.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisputeService {
  final SupabaseClient client;

  DisputeService(this.client);

  Future<Dispute> createDispute(Dispute dispute) async {
    // Try using RPC function first (bypasses RLS for unauthenticated users)
    try {
      final disputeMap = dispute.toMap();
      
      // Convert item_id to UUID if provided (database expects UUID type)
      dynamic itemIdParam = disputeMap['item_id'];
      if (itemIdParam != null && itemIdParam is String) {
        // The SQL function will handle the UUID conversion
        itemIdParam = itemIdParam;
      }
      
      final response = await client.rpc('create_dispute', params: {
        'p_type': disputeMap['type'],
        'p_description': disputeMap['description'],
        'p_status': disputeMap['status'] ?? 'pending',
        'p_customer_id': disputeMap['customer_id'],
        'p_item_id': itemIdParam,
      });
      
      // RPC function returns JSONB, convert to Map
      // The response should already be a Map from Supabase
      final responseMap = response as Map<String, dynamic>;
      return Dispute.fromMap(responseMap);
    } catch (rpcError) {
      // If RPC function doesn't exist or fails, try direct insert
      // This will work for authenticated users if RLS allows it
      final errorString = rpcError.toString().toLowerCase();
      if (errorString.contains('function') || 
          errorString.contains('does not exist') ||
          errorString.contains('permission denied') ||
          errorString.contains('42501')) {
        // Function doesn't exist or permission denied, try direct insert
        try {
          final disputeMap = dispute.toMap();
          // Convert item_id string to UUID format for direct insert
          if (disputeMap['item_id'] != null && disputeMap['item_id'] is String) {
            disputeMap['item_id'] = disputeMap['item_id'] as String;
          }
          
          final response = await client
              .from('disputes')
              .insert(disputeMap)
              .select()
              .single();
          
          return Dispute.fromMap(response);
        } catch (insertError) {
          // If direct insert also fails (likely RLS), provide helpful error
          throw Exception(
            'Unable to create dispute. Please run the SQL migration file "supabase_migration_create_dispute_function.sql" '
            'in your Supabase SQL Editor to create the required database function. '
            'Error: ${insertError.toString()}'
          );
        }
      } else {
        // Re-throw other RPC errors
        rethrow;
      }
    }
  }

  Future<List<Dispute>> fetchDisputes({String? status}) async {
    var query = client.from('disputes').select();

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Dispute.fromMap(e))
        .toList();
  }

  Future<Dispute> updateDisputeStatus(String id, String status, {String? resolutionNotes}) async {
    final updates = <String, dynamic>{'status': status};
    if (resolutionNotes != null) {
      updates['resolution_notes'] = resolutionNotes;
    }
    
    final response = await client
        .from('disputes')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Dispute.fromMap(response);
  }

  Future<List<Map<String, dynamic>>> getSimilarItems(String disputeId) async {
    // Get the disputed item first
    final disputeResponse = await client
        .from('disputes')
        .select('item_id')
        .eq('id', disputeId)
        .single();

    final disputedItemId = disputeResponse['item_id'];
    if (disputedItemId == null) return [];

    // Get the disputed item details
    final itemResponse = await client
        .from('clothes')
        .select()
        .eq('id', disputedItemId)
        .single();

    final item = itemResponse;
    
    // Find similar items by type, brand, or color
    final similarResponse = await client
        .from('clothes')
        .select()
        .or('type.eq.${item['type']},brand.eq.${item['brand']},color.eq.${item['color']}')
        .neq('id', disputedItemId)
        .limit(10);

    return List<Map<String, dynamic>>.from(similarResponse);
  }
}

