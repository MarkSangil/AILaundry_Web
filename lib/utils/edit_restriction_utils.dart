import 'package:ailaundry_web/services/system_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class to check if washers can edit clothes based on daily cut-off time
class EditRestrictionUtils {
  static final SystemSettingsService _settingsService = 
      SystemSettingsService(Supabase.instance.client);
  
  /// Get current time in Philippine Time (UTC+8)
  static DateTime getPhilippineTime() {
    return SystemSettingsService.getPhilippineTime();
  }

  /// Check if the current user (washer) can edit clothes
  /// Returns true if editing is allowed, false if cut-off time has passed
  static Future<bool> canEditClothes() async {
    try {
      // Get current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Check user role
      final userRecord = await Supabase.instance.client
          .from('laundry_users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (userRecord == null) return false;

      final role = userRecord['role'] as String?;
      
      // Admin/Manager/Checker can always edit (override)
      if (role == 'admin' || role == 'manager' || role == 'checker') {
        return true;
      }

      // Washers are subject to cut-off time restriction
      if (role == 'washer') {
        return await _settingsService.canWasherEditClothes();
      }

      return false;
    } catch (e) {
      // On error, allow editing (fail open)
      return true;
    }
  }

  /// Get a user-friendly message about edit restrictions
  static Future<String> getEditRestrictionMessage() async {
    try {
      final cutOffTime = await _settingsService.getDailyCutOffTime();
      final canEdit = await canEditClothes();
      
      if (canEdit) {
        // Get current time in Philippine Time
        final nowPH = getPhilippineTime();
        final currentTime = TimeOfDay.fromDateTime(nowPH);
        final currentMinutes = currentTime.hour * 60 + currentTime.minute;
        final cutOffMinutes = cutOffTime.hour * 60 + cutOffTime.minute;
        final remainingMinutes = cutOffMinutes - currentMinutes;
        final remainingHours = remainingMinutes ~/ 60;
        final remainingMins = remainingMinutes % 60;
        
        return 'You can edit clothes for ${remainingHours}h ${remainingMins}m more today (until ${_formatTime(cutOffTime)} Philippine Time)';
      } else {
        return 'Editing is locked. Washers can only edit clothes before ${_formatTime(cutOffTime)} (Philippine Time) daily.';
      }
    } catch (e) {
      return 'Edit restrictions are active. Contact administrator for details.';
    }
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

