import 'package:ailaundry_web/models/clothes_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClothesService {
  final SupabaseClient client;

  ClothesService(this.client);

  Future<List<ClothesItem>> fetchClothes({int limit = 100}) async {
    final response = await client
        .from('clothes')
        .select('id, brand, color, type, image_url, created_at')
        .limit(limit);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => ClothesItem.fromMap(e))
        .toList();
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
