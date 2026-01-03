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

    final disputedItem = itemResponse;
    final disputedType = (disputedItem['type'] as String? ?? '').toLowerCase().trim();
    final disputedBrand = (disputedItem['brand'] as String? ?? '').toLowerCase().trim();
    final disputedColor = (disputedItem['color'] as String? ?? '').toLowerCase().trim();
    
    // If no attributes to match, return empty
    if (disputedType.isEmpty && disputedBrand.isEmpty && disputedColor.isEmpty) {
      return [];
    }
    
    // Fetch all items except the disputed one
    final allItemsResponse = await client
        .from('clothes')
        .select()
        .neq('id', disputedItemId)
        .limit(100); // Get more items to score and rank
    
    final allItems = List<Map<String, dynamic>>.from(allItemsResponse);
    
    // Score and rank items based on similarity
    final scoredItems = allItems.map((item) {
      int score = 0;
      final itemType = (item['type'] as String? ?? '').toLowerCase().trim();
      final itemBrand = (item['brand'] as String? ?? '').toLowerCase().trim();
      final itemColor = (item['color'] as String? ?? '').toLowerCase().trim();
      
      // Exact matches get higher scores
      // Brand + Color match (most important) = 100 points
      if (disputedBrand.isNotEmpty && disputedColor.isNotEmpty) {
        if (itemBrand == disputedBrand && itemColor == disputedColor) {
          score += 100;
        }
      }
      
      // Brand + Type match = 80 points
      if (disputedBrand.isNotEmpty && disputedType.isNotEmpty) {
        if (itemBrand == disputedBrand && itemType == disputedType) {
          score += 80;
        }
      }
      
      // Color + Type match = 60 points
      if (disputedColor.isNotEmpty && disputedType.isNotEmpty) {
        if (itemColor == disputedColor && itemType == disputedType) {
          score += 60;
        }
      }
      
      // Single attribute matches (lower priority)
      if (disputedBrand.isNotEmpty && itemBrand == disputedBrand) {
        score += 30; // Brand match
      }
      if (disputedColor.isNotEmpty && itemColor == disputedColor) {
        score += 20; // Color match
      }
      if (disputedType.isNotEmpty && itemType == disputedType) {
        score += 10; // Type match (least specific)
      }
      
      // Partial matches (fuzzy matching for brand/color)
      if (disputedBrand.isNotEmpty && itemBrand.isNotEmpty) {
        if (itemBrand.contains(disputedBrand) || disputedBrand.contains(itemBrand)) {
          if (score < 30) score += 15; // Partial brand match
        }
      }
      
      return {
        'item': item,
        'score': score,
      };
    }).toList();
    
    // Sort by score (highest first) and filter out items with score 0
    scoredItems.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    // Return top 6 items with score > 0, or at least top 3 even if score is low
    final topItems = scoredItems
        .where((scored) => scored['score'] as int > 0)
        .take(6)
        .map((scored) => scored['item'] as Map<String, dynamic>)
        .toList();
    
    // If we have very few high-scoring items, include some lower-scoring ones
    if (topItems.length < 3 && scoredItems.isNotEmpty) {
      final additionalItems = scoredItems
          .take(3)
          .map((scored) => scored['item'] as Map<String, dynamic>)
          .toList();
      topItems.addAll(additionalItems);
      // Remove duplicates
      final seenIds = <String>{};
      return topItems.where((item) {
        final id = item['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();
    }
    
    return topItems;
  }
}

