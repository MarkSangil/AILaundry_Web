import 'dart:html' as html;

import 'package:ailaundry_web/admin_register_page.dart';
import 'package:ailaundry_web/complete_profile_page.dart';
import 'package:ailaundry_web/manager_dashboard.dart';
import 'package:ailaundry_web/services/login_history_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _adminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    setState(() => _error = null);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = response.user;
      if (user == null) {
        if (mounted) {
          setState(() => _error = "Invalid login credentials. Please check your email and password.");
        }
        return;
      }

      if (user.emailConfirmedAt == null) {
        if (mounted) {
          setState(() => _error = "Please confirm your email before logging in.");
        }
        return;
      }

      // Check if user has manager role in laundry_users table
      try {
        // Try matching by id first (if id matches auth.users.id)
        var userRecord = await Supabase.instance.client
            .from('laundry_users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        // If not found, try matching by email
        if (userRecord == null) {
          userRecord = await Supabase.instance.client
              .from('laundry_users')
              .select('role')
              .eq('email', user.email!)
              .maybeSingle();
        }

        if (userRecord == null) {
          // User exists in auth but not in laundry_users
          // Only allow admin registration through the registration page
          if (mounted) {
            setState(() => _error = "Access denied. Admin account required. Please register as admin first.");
          }
          // DO NOT sign out - just show error and let user try again or navigate away
          // The session will remain but they can't access the dashboard
          return;
        }

        final userRole = userRecord['role'] as String;
        if (userRole != 'admin') {
          if (mounted) {
            setState(() => _error = "Access denied. Admin role required. Your account role is: ${userRole.toUpperCase()}. Only administrators can access this page.");
          }
          // DO NOT sign out - just show error and let user try again
          // The session will remain but they can't access the dashboard
          return;
        }

        // Log login activity
        try {
          final loginHistoryService = LoginHistoryService(Supabase.instance.client);
          // Get IP address and user agent from browser
          final ipAddress = html.window.location.hostname; // Note: Client-side IP detection is limited
          final userAgent = html.window.navigator.userAgent;
          
          await loginHistoryService.logLogin(
            userId: user.id,
            ipAddress: ipAddress,
            userAgent: userAgent,
          );
        } catch (e) {
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = "Error verifying user role. Please try again.";
          final errorString = e.toString().toLowerCase();
          
          if (errorString.contains('network') || errorString.contains('connection')) {
            errorMessage = "Network error while verifying your account. Please check your connection and try again.";
          } else if (errorString.contains('permission') || errorString.contains('rls')) {
            errorMessage = "Permission error. Please contact an administrator.";
          } else {
          }
          
          setState(() => _error = errorMessage);
        }
        // DO NOT sign out on role verification errors - just show the error
        return;
      }

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
        // Return early after navigation to avoid executing finally block
        return;
      }
    } catch (e) {
      // Handle authentication errors with user-friendly messages
      if (mounted) {
        String errorMessage = "An error occurred during login. Please try again.";
        
        // Extract user-friendly error message from Supabase exceptions
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('invalid login credentials') || 
            errorString.contains('invalid_credentials') ||
            errorString.contains('email not confirmed') ||
            errorString.contains('wrong password') ||
            errorString.contains('user not found')) {
          errorMessage = "Invalid email or password. Please check your credentials and try again.";
        } else if (errorString.contains('email not confirmed') || 
                   errorString.contains('email_not_confirmed')) {
          errorMessage = "Please confirm your email address before logging in.";
        } else if (errorString.contains('too many requests') || 
                   errorString.contains('rate limit')) {
          errorMessage = "Too many login attempts. Please wait a moment and try again.";
        } else if (errorString.contains('network') || 
                   errorString.contains('connection')) {
          errorMessage = "Network error. Please check your connection and try again.";
        } else {
          errorMessage = "Login failed. Please check your credentials and try again.";
        }
        
        setState(() => _error = errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
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
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: size.width > 600 ? 400 : size.width * 0.9,
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
                                    Icons.admin_panel_settings_rounded,
                                    size: 40,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),

                                Text(
                                  "Admin Access",
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Sign in with your admin credentials",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                TextFormField(
                                  controller: _emailController,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: "Admin Email",
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _passwordController,
                                  validator: _validatePassword,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _adminLogin(),
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    prefixIcon: const Icon(Icons.lock_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                  ),
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
                                    onPressed: _loading ? null : _adminLogin,
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
                                            "Sign In as Admin",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Temporary registration link
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange[700],
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'TEMPORARY',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation, secondaryAnimation) =>
                                                  const AdminRegisterPage(),
                                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                return SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(1.0, 0.0),
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: child,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Register New Admin Account",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

