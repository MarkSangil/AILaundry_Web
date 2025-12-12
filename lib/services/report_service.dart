import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient client;

  ReportService(this.client);

  Future<Map<String, dynamic>> getTodayMetrics() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // Items scanned today
    final scannedResponse = await client
        .from('clothes')
        .select('id')
        .gte('created_at', startOfDay.toIso8601String());

    final scannedCount = List<Map<String, dynamic>>.from(scannedResponse).length;

    // Approved items
    final approvedResponse = await client
        .from('clothes')
        .select('id')
        .eq('status', 'approved')
        .gte('created_at', startOfDay.toIso8601String());

    final approvedCount = List<Map<String, dynamic>>.from(approvedResponse).length;

    // Disputes
    final disputesResponse = await client
        .from('disputes')
        .select('id, status');

    final disputesList = List<Map<String, dynamic>>.from(disputesResponse);
    final totalDisputes = disputesList.length;
    final openDisputes = disputesList
        .where((d) => d['status'] == 'pending')
        .length;
    final resolvedDisputes = disputesList
        .where((d) => d['status'] == 'resolved')
        .length;

    // Approval rate
    final approvalRate = scannedCount > 0
        ? (approvedCount / scannedCount * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'itemsScannedToday': scannedCount,
      'approvalRate': approvalRate,
      'disputesOpen': openDisputes,
      'disputesResolved': resolvedDisputes,
      'totalDisputes': totalDisputes,
    };
  }

  Future<Map<String, dynamic>> getDailyReport(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final itemsResponse = await client
        .from('clothes')
        .select()
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String());

    final items = List<Map<String, dynamic>>.from(itemsResponse);

    return {
      'date': date.toIso8601String(),
      'scanned': items.length,
      'approved': items.where((i) => i['status'] == 'approved').length,
      'pending': items.where((i) => i['status'] == 'pending').length,
      'voided': items.where((i) => i['status'] == 'voided').length,
      'items': items,
    };
  }

  Future<List<Map<String, dynamic>>> getWasherPerformance() async {
    final washersResponse = await client
        .from('laundry_users')
        .select()
        .eq('role', 'washer');
    final washers = List<Map<String, dynamic>>.from(washersResponse);

    final performance = <Map<String, dynamic>>[];

    for (var washer in washers) {
      final itemsResponse = await client
          .from('clothes')
          .select('id, status')
          .eq('washer_id', washer['id']);

      final itemsList = List<Map<String, dynamic>>.from(itemsResponse);
      final totalItems = itemsList.length;
      final approvedItems = itemsList
          .where((i) => i['status'] == 'approved')
          .length;

      performance.add({
        'washer': washer,
        'totalItems': totalItems,
        'approvedItems': approvedItems,
        'approvalRate': totalItems > 0
            ? (approvedItems / totalItems * 100).toStringAsFixed(1)
            : '0.0',
      });
    }

    return performance;
  }
}

