import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemSettingsService {
  final SupabaseClient client;

  SystemSettingsService(this.client);

  // Philippine Time is UTC+8
  static const int philippineTimeOffsetHours = 8;

  /// Get current time in Philippine Time (UTC+8)
  static DateTime getPhilippineTime() {
    final now = DateTime.now().toUtc();
    return now.add(Duration(hours: philippineTimeOffsetHours));
  }

  /// Convert a DateTime to Philippine Time
  static DateTime toPhilippineTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return utc.add(Duration(hours: philippineTimeOffsetHours));
  }

  // Get daily cut-off time for washer edits (defaults to 6pm)
  Future<TimeOfDay> getDailyCutOffTime() async {
    try {
      final response = await client
          .from('system_settings')
          .select('value, updated_at')
          .eq('key', 'washer_edit_cutoff_time')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final timeString = response['value'] as String;
        // Handle both "HH:MM" and "HH:MM:SS" formats
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    } catch (e) {
    }
    return const TimeOfDay(hour: 18, minute: 0);
  }

  Future<void> setDailyCutOffTime(TimeOfDay time) async {
    final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    try {
      final existing = await client
          .from('system_settings')
          .select('id, value')
          .eq('key', 'washer_edit_cutoff_time')
          .maybeSingle();
      
      Map<String, dynamic> result;
      
      if (existing != null) {
        // Record exists, update it
        result = await client
            .from('system_settings')
            .update({
              'value': timeString,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('key', 'washer_edit_cutoff_time')
            .select('value')
            .single();
      } else {
        // Record doesn't exist, insert it
        result = await client
            .from('system_settings')
            .insert({
              'key': 'washer_edit_cutoff_time',
              'value': timeString,
            })
            .select('value')
            .single();
      }
      
      // Verify the save worked immediately
      final savedValue = result['value'] as String;
      final savedParts = savedValue.split(':');
      final savedHour = int.parse(savedParts[0]);
      final savedMinute = int.parse(savedParts.length > 1 ? savedParts[1] : '0');
      
      if (savedHour != time.hour || savedMinute != time.minute) {
        throw Exception('Save verification failed: saved value ($savedValue) does not match input (${time.hour}:${time.minute})');
      }
      
      // Double-check by reading it back after a small delay to ensure database consistency
      await Future.delayed(const Duration(milliseconds: 200));
      final verification = await getDailyCutOffTime();
      if (verification.hour != time.hour || verification.minute != time.minute) {
        throw Exception('Save verification failed: read back value (${verification.hour}:${verification.minute}) does not match saved value ($savedValue)');
      }
    } catch (e) {
      throw Exception('Failed to save cut-off time: $e');
    }
  }

  // Check if washer can edit clothes based on current time and cut-off time
  // Uses Philippine Time (UTC+8) for comparison
  Future<bool> canWasherEditClothes() async {
    try {
      final cutOffTime = await getDailyCutOffTime();
      // Get current time in Philippine Time
      final nowPH = getPhilippineTime();
      final currentTime = TimeOfDay.fromDateTime(nowPH);
      
      // Convert to minutes for comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final cutOffMinutes = cutOffTime.hour * 60 + cutOffTime.minute;
      
      return currentMinutes < cutOffMinutes;
    } catch (e) {
      // On error, allow editing (fail open)
      return true;
    }
  }

  // Get formatted cut-off time message
  Future<String> getCutOffTimeMessage() async {
    final cutOffTime = await getDailyCutOffTime();
    return 'Washers can edit clothes until ${_formatTime(cutOffTime)} daily';
  }

  // Helper method to format TimeOfDay
  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

// Extension to format TimeOfDay (using different name to avoid conflict with Flutter's format method)
extension TimeOfDayExtension on TimeOfDay {
  String format12Hour() {
    final hour = this.hour == 0 ? 12 : (this.hour > 12 ? this.hour - 12 : this.hour);
    final minute = this.minute.toString().padLeft(2, '0');
    final period = this.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  String format24Hour() {
    return '${this.hour.toString().padLeft(2, '0')}:${this.minute.toString().padLeft(2, '0')}';
  }
}

