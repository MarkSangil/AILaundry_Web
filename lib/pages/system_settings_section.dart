import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/system_settings_service.dart';
import '../utils/error_utils.dart';
// System Settings Section
class SystemSettingsSection extends StatefulWidget {
  const SystemSettingsSection({super.key});

  @override
  State<SystemSettingsSection> createState() => _SystemSettingsSectionState();
}

class _SystemSettingsSectionState extends State<SystemSettingsSection> {
  final supabase = Supabase.instance.client;
  final SystemSettingsService _settingsService = SystemSettingsService(Supabase.instance.client);
  
  TimeOfDay _cutOffTime = const TimeOfDay(hour: 18, minute: 0);
  String _reportFormat = 'PDF';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final cutOffTime = await _settingsService.getDailyCutOffTime();
      setState(() {
        _cutOffTime = cutOffTime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Use default if loading fails
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      // Save the cut-off time
      await _settingsService.setDailyCutOffTime(_cutOffTime);
      
      // Wait a moment for the database to commit
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Reload settings to verify the save worked and get the actual saved value
      await _loadSettings();
      
      if (mounted) {
        // Show success message with the actual loaded value (not the local state)
        final loadedTime = await _settingsService.getDailyCutOffTime();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved! Washers can edit clothes until ${_formatTime(loadedTime)} (Philippine Time) daily.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // Reload to show the actual saved value from database
        await _loadSettings();
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Settings',
                style: theme.textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSettings,
                tooltip: 'Refresh settings',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Parameters',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListTile(
                      title: const Text('Daily Cut-off Time for Washer Edits'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current: ${_formatTime(_cutOffTime)} (Philippine Time)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Washers can only edit clothes before this time each day (Philippine Time, UTC+8)',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          // Show dialog explaining Philippine Time
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Set Cut-off Time'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Philippine Time: ${_formatTime(TimeOfDay.fromDateTime(SystemSettingsService.getPhilippineTime()))}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'The time you set will be interpreted as Philippine Time (UTC+8).',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );
                          
                          if (proceed == true) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _cutOffTime,
                              helpText: 'Set cut-off time (Philippine Time)',
                            );
                            if (time != null) {
                              setState(() => _cutOffTime = time);
                            }
                          }
                        },
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('Default Report Format'),
                    subtitle: Text(_reportFormat),
                    trailing: DropdownButton<String>(
                      value: _reportFormat,
                      items: const [
                        DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                        DropdownMenuItem(value: 'CSV', child: Text('CSV')),
                        DropdownMenuItem(value: 'XLSX', child: Text('XLSX')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reportFormat = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical Archive & Recovery',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Manage deleted or voided entries with one-click restore'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to archive
                    },
                    child: const Text('View Archive'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Login History Section