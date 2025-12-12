import 'package:ailaundry_web/admin_login_page.dart';
import 'package:ailaundry_web/manager_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteProfilePage extends StatefulWidget {
  final String userId;
  final String email;

  const CompleteProfilePage({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _isInitializing = true;
  String? _error;
  String _selectedRole = 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserMetadata();
  }

  Future<void> _loadUserMetadata() async {
    try {
      // Get current user to retrieve metadata
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final metadata = user.userMetadata!;
        
        // Pre-fill form with data from registration
        if (metadata['name'] != null) {
          _nameController.text = metadata['name'] as String;
        }
        if (metadata['role'] != null) {
          String role = metadata['role'] as String;
          // Convert 'manager' to 'admin' if needed (for backward compatibility)
          if (role == 'manager') {
            role = 'admin';
          }
          _selectedRole = role;
        }
      }
    } catch (e) {
      // If metadata retrieval fails, continue with defaults
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Create user record in laundry_users table
      // Try using database function first (bypasses RLS), then fall back to direct insert
      bool recordCreated = false;
      
      try {
        // Try calling the database function first (if it exists)
        await Supabase.instance.client.rpc('create_laundry_user', params: {
          'p_user_id': widget.userId,
          'p_name': _nameController.text.trim(),
          'p_email': widget.email,
          'p_role': _selectedRole,
        });
        recordCreated = true;
      } catch (rpcError) {
        // Function might not exist, try direct insert
        if (rpcError.toString().contains('function') || 
            rpcError.toString().contains('does not exist')) {
          // Function doesn't exist, try direct insert
          try {
            await Supabase.instance.client.from('laundry_users').insert({
              'id': widget.userId,
              'name': _nameController.text.trim(),
              'email': widget.email,
              'role': _selectedRole,
            });
            recordCreated = true;
          } catch (insertError) {
            throw Exception("Failed to create user record: ${insertError.toString()}");
          }
        } else {
          throw Exception("Failed to create user record: ${rpcError.toString()}");
        }
      }
      
      if (!recordCreated) {
        throw Exception("Failed to create user record");
      }

      // Verify role - only admin/manager allowed
      if (_selectedRole != 'admin' && _selectedRole != 'manager') {
        setState(() => _error = "Only admin/manager roles are allowed. Please select admin.");
        return;
      }

      // Navigate to manager dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ManagerDashboard(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      String errorMessage = "Failed to complete profile: ${e.toString()}";
      
      // Check for role constraint violation
      if (e.toString().contains('role_check') || e.toString().contains('check constraint')) {
        errorMessage = "The 'admin' role is not allowed in the database yet. Please run the SQL migration to add 'admin' to the allowed roles, or select 'checker' or 'washer' instead.";
      }
      
      setState(() => _error = errorMessage);
    } finally {
      setState(() => _loading = false);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: size.width > 600 ? 500 : size.width * 0.9,
              ),
              child: Card(
                elevation: 12,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_outlined,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),

                        Text(
                          "Complete Your Profile",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your account exists but needs profile information",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.email, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.email,
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        TextFormField(
                          controller: _nameController,
                          validator: _validateName,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: "Full Name *",
                            prefixIcon: const Icon(Icons.person_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: "Phone (Optional)",
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: "Role *",
                            prefixIcon: const Icon(Icons.work_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin (Manager)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _completeProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Complete Profile",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

