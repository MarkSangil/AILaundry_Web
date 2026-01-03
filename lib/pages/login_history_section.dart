import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/login_history.dart';
import '../services/login_history_service.dart';
import '../utils/error_utils.dart';
// Login History Section
class LoginHistorySection extends StatefulWidget {
  const LoginHistorySection({super.key});

  @override
  State<LoginHistorySection> createState() => _LoginHistorySectionState();
}

class _LoginHistorySectionState extends State<LoginHistorySection> {
  final LoginHistoryService _loginHistoryService = LoginHistoryService(Supabase.instance.client);
  List<LoginHistory> _loginHistory = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedUserId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
  }

  Future<void> _loadLoginHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _loginHistoryService.fetchAllLoginHistory(
        userId: _selectedUserId,
        startDate: _startDate,
        endDate: _endDate,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _loginHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = safeErrorToString(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by User ID (optional)',
                    prefixIcon: Icon(Icons.person),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _selectedUserId = value.isEmpty ? null : value;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                      });
                      _loadLoginHistory();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      isDense: true,
                    ),
                    child: Text(_startDate != null
                        ? _startDate!.toString().split(' ')[0]
                        : 'Select date'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                      });
                      _loadLoginHistory();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      isDense: true,
                    ),
                    child: Text(_endDate != null
                        ? _endDate!.toString().split(' ')[0]
                        : 'Select date'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedUserId = null;
                    _startDate = null;
                    _endDate = null;
                  });
                  _loadLoginHistory();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLoginHistory,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Login History List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Error: $_error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadLoginHistory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _loginHistory.isEmpty
                      ? const Center(child: Text('No login history found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _loginHistory.length,
                          itemBuilder: (context, index) {
                            final history = _loginHistory[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: history.logoutAt == null
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Icon(
                                    history.logoutAt == null
                                        ? Icons.check_circle
                                        : Icons.logout,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  history.userName ?? history.userEmail ?? 'Unknown User',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Role: ${history.userRole ?? 'N/A'}'),
                                    Text('Login: ${history.formattedLoginAt}'),
                                    if (history.logoutAt != null)
                                      Text('Logout: ${history.formattedLogoutAt}'),
                                    Text('Duration: ${history.formattedSessionDuration}'),
                                    if (history.ipAddress != null)
                                      Text('IP: ${history.ipAddress}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    history.logoutAt == null ? 'Active' : 'Ended',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                  backgroundColor: history.logoutAt == null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

