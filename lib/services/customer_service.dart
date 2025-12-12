import 'package:ailaundry_web/models/washer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerService {
  final SupabaseClient client;

  CustomerService(this.client);

  /// Fetch all users with role 'customer' from laundry_users table
  Future<List<Washer>> fetchCustomers() async {
    final response = await client
        .from('laundry_users')
        .select()
        .eq('role', 'customer')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Washer.fromMap(e))
        .toList();
  }

  /// Update customer (user with role 'customer')
  Future<Washer> updateCustomer(String id, Map<String, dynamic> updates) async {
    // Update the customer
    await client
        .from('laundry_users')
        .update(updates)
        .eq('id', id)
        .eq('role', 'customer'); // Ensure we're only updating customers

    // Fetch the updated record
    final response = await client
        .from('laundry_users')
        .select()
        .eq('id', id)
        .eq('role', 'customer')
        .maybeSingle();

    if (response == null) {
      throw Exception('Customer not found after update');
    }

    return Washer.fromMap(response);
  }

  /// Delete customer (user with role 'customer')
  Future<void> deleteCustomer(String id) async {
    await client
        .from('laundry_users')
        .delete()
        .eq('id', id)
        .eq('role', 'customer'); // Ensure we're only deleting customers
  }
}

