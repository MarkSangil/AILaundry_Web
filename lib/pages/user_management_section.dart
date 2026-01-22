import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clothes_item.dart';
import '../models/washer.dart';
import '../services/clothes_services.dart';
import '../services/customer_service.dart';
import '../services/washer_service.dart';
import '../utils/error_utils.dart';
// User Management Section
class UserManagementSection extends StatefulWidget {
  const UserManagementSection({super.key});

  @override
  State<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends State<UserManagementSection> {
  final supabase = Supabase.instance.client;
  final WasherService _userService = WasherService(Supabase.instance.client);
  
  List<Washer> _users = [];
  List<Washer> _filteredUsers = [];
  bool _isLoading = true;
  String _roleFilter = 'all'; // all, washer, checker, admin
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.fetchAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _applyFilters();
          _isLoading = false;
        });
        
        // Show debug info if no users found
        if (users.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users found in database. Users will appear here after registration.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _users;

    // Filter by role
    if (_roleFilter != 'all') {
      filtered = filtered.where((u) => u.role == _roleFilter).toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((u) {
        return u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = filtered);
  }

  Future<void> _toggleUserStatus(Washer user) async {
    // Prevent user from disabling themselves
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && user.id == currentUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot disable your own account'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await _userService.toggleUserStatus(user.id!, !user.isActive);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.isActive ? "disabled" : "enabled"} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error updating user status';
        final errorStr = safeErrorToString(e).toLowerCase();
        if (errorStr.contains('not found')) {
          errorMessage = 'User not found. The user may have been deleted.';
        } else if (errorStr.contains('permission') || errorStr.contains('rls')) {
          errorMessage = 'Permission denied. You may not have permission to update this user.';
        } else if (e.toString().contains('is_active column does not exist')) {
          errorMessage = 'Database configuration error. The is_active column does not exist. Please contact the administrator.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showEditUserDialog(Washer? user, {String? defaultRole}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    // Normalize role: convert 'manager' to 'admin' for consistency
    // Use defaultRole if provided, otherwise use user's role, otherwise default to 'washer'
    String initialRole = defaultRole ?? user?.role ?? 'washer';
    if (initialRole == 'manager') {
      initialRole = 'admin';
    }

    showDialog(
      context: context,
      builder: (context) {
        // Use a ValueNotifier to properly track the selected role
        final selectedRoleNotifier = ValueNotifier<String>(initialRole);
        
        return ValueListenableBuilder<String>(
          valueListenable: selectedRoleNotifier,
          builder: (context, selectedRole, _) {
            return AlertDialog(
              title: Text(user == null ? 'Add New User' : 'Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: user == null, // Can't change email for existing users
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone (Optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'washer', child: Text('Washer')),
                        DropdownMenuItem(value: 'checker', child: Text('Checker')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin (Manager)')),
                        DropdownMenuItem(value: 'customer', child: Text('Customer')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedRoleNotifier.value = value;
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selectedRoleNotifier.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final roleToSave = selectedRoleNotifier.value;
                    try {
                      if (user == null) {
                        // Create user with Supabase Auth and send invitation email
                        // SQL trigger will automatically create laundry_users record
                        await _userService.createWasherWithAuth(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          role: roleToSave,
                          redirectTo: null, // Optional: set redirect URL if needed
                        );
                      } else {
                        // Validate user ID exists
                        if (user.id == null || user.id!.isEmpty) {
                          throw Exception('Invalid user ID. Cannot update user.');
                        }
                        
                        final updates = <String, dynamic>{
                          'name': nameController.text.trim(),
                          'role': roleToSave,
                        };
                        // Only update email if it changed and user is new
                        if (emailController.text.trim() != user.email) {
                          updates['email'] = emailController.text.trim();
                        }
                        // Update phone number (can be empty/null)
                        final phoneValue = phoneController.text.trim();
                        updates['phone'] = phoneValue.isEmpty ? null : phoneValue;
                        await _userService.updateWasher(user.id!, updates);
                      }
                      selectedRoleNotifier.dispose();
                      Navigator.pop(context);
                      await _loadUsers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              user == null 
                                ? 'User created successfully! Invitation email sent to ${emailController.text.trim()}'
                                : 'User role updated successfully'
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        String errorMessage = 'Error updating user';
                        final errorString = safeErrorToString(e).toLowerCase();
                        
                        if (errorString.contains('not found') || 
                            errorString.contains('pgrst116') ||
                            errorString.contains('0 rows')) {
                          errorMessage = 'User not found or update failed. The user may have been deleted.';
                        } else if (errorString.contains('permission') || 
                                   errorString.contains('rls') ||
                                   errorString.contains('create_update_functions')) {
                          errorMessage = 'Permission denied. Please run the SQL in create_update_functions.sql in your Supabase SQL Editor to create the RPC function that bypasses RLS.';
                        } else if (errorString.contains('function') || 
                                   errorString.contains('does not exist')) {
                          errorMessage = 'Database function missing. Please run create_update_functions.sql in your Supabase SQL Editor.';
                        } else {
                          errorMessage = 'Error: ${e.toString()}';
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(user == null ? 'Create' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header with filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Management',
                    style: theme.textTheme.headlineSmall,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showEditUserDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add User'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search users',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'washer', child: Text('Washers')),
                        DropdownMenuItem(value: 'checker', child: Text('Checkers')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'customer', child: Text('Customers')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _roleFilter = value;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Users List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _users.isEmpty 
                                ? 'No users found in database' 
                                : 'No users match your filters',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _users.isEmpty
                                ? 'Users will appear here after they register and complete their profile'
                                : 'Try adjusting your search or role filter',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_users.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (user.role == 'admin' || user.role == 'manager')
                                  ? Colors.purple
                                  : user.role == 'checker'
                                      ? Colors.blue
                                      : Colors.green,
                              child: Text(
                                user.name.isNotEmpty 
                                    ? user.name[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(user.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                if (user.phone != null) Text(user.phone!),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(user.role.toUpperCase()),
                                  backgroundColor: (user.role == 'admin' || user.role == 'manager')
                                      ? Colors.purple.withOpacity(0.2)
                                      : user.role == 'checker'
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: user.isActive,
                                  onChanged: (supabase.auth.currentUser?.id == user.id)
                                      ? null // Disable switch for current user
                                      : (_) => _toggleUserStatus(user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditUserDialog(user),
                                ),
                              ],
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