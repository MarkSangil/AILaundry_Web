import 'package:ailaundry_web/login_page.dart';
import 'package:ailaundry_web/manager_dashboard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Safely converts any error to a string, handling JS objects
String safeErrorToString(dynamic error) {
  try {
    if (error == null) return 'Unknown error';
    if (error is String) return error;
    if (error is Exception) return error.toString();
    // Try toString first
    final str = error.toString();
    // If toString returns something that looks like a JS object, extract message
    if (str.contains('LegacyJavaScriptObject') || str.contains('Instance of')) {
      return 'An error occurred. Please try again.';
    }
    return str;
  } catch (e) {
    // If even toString fails, return a safe message
    return 'An error occurred. Please try again.';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handler to prevent infinite loops
  FlutterError.onError = (FlutterErrorDetails details) {
    // Safely log the error without causing another crash
    debugPrint('Flutter Error: ${safeErrorToString(details.exception)}');
    debugPrint('Stack: ${details.stack}');
    // Don't let Flutter try to render the error widget if it contains JS objects
    FlutterError.presentError(details);
  };
  
  try {
    await Supabase.initialize(
      url: 'https://xeabnvfxnkooljbqhkce.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYWJudmZ4bmtvb2xqYnFoa2NlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NTE1NDAsImV4cCI6MjA2ODQyNzU0MH0.zyc3Cu108kLn_xed5iVeQ2TpZRTyX59RihHpI2O9RQg',
    );
  } catch (e) {
    debugPrint('Supabase init failed: ${safeErrorToString(e)}');
    // Continue anyway - might work on retry
  }
  
  // Store build timestamp to detect hot restart
  const buildTimestamp = '2025-01-27-v2'; // Change this when you want to force refresh
  
  runApp(MyApp(buildTimestamp: buildTimestamp));
}

class MyApp extends StatefulWidget {
  final String buildTimestamp;
  
  const MyApp({super.key, required this.buildTimestamp});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget? _initialRoute;
  bool _isLoading = true;
  int _buildKey = 0; // Force rebuild counter

  @override
  void initState() {
    super.initState();
    // Force route determination on every init (including hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineInitialRoute();
    });
    // Listen to auth state changes - only react to sign in/out, not token refresh
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Only react to sign out events to handle logout
      // Don't re-check route on sign in - navigation is handled by the login page
      if (mounted && data.event == AuthChangeEvent.signedOut) {
        _determineInitialRoute();
      }
      // Ignore signedIn and tokenRefreshed events - they don't require route changes
    });
  }

  Future<void> _determineInitialRoute() async {
    if (!mounted) return;
    
    // Reset and force rebuild
    setState(() {
      _buildKey++;
      _isLoading = true;
      _initialRoute = null; // Clear previous route
    });

    // Small delay to ensure state is cleared
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      if (mounted) {
        setState(() {
          _initialRoute = const LoginPage();
          _isLoading = false;
        });
      }
      return;
    }

    // Check user role to determine which dashboard to show
    // IMPORTANT: Do NOT call signOut() here - just route appropriately
    // signOut() should only be called on explicit user action (logout button)
    try {
      final userRecord = await Supabase.instance.client
          .from('laundry_users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      // Debug logging to identify role issues
      debugPrint('=== Route Determination Debug ===');
      debugPrint('User ID: ${session.user.id}');
      debugPrint('User Email: ${session.user.email}');
      debugPrint('User Record: $userRecord');
      debugPrint('User Metadata: ${session.user.userMetadata}');

      if (userRecord != null) {
        final role = userRecord['role'] as String?;
        debugPrint('User Role: $role');
        setState(() {
          if (role == 'admin') {
            _initialRoute = const ManagerDashboard();
          } else {
            // Non-admin users are not allowed - just route to login
            // DO NOT sign out - user is authenticated, just unauthorized for this app
            debugPrint('User role "$role" is not admin - routing to login');
            _initialRoute = const LoginPage();
          }
          _isLoading = false;
        });
      } else {
        // User exists in auth but not in laundry_users - route to login
        // DO NOT sign out - this could be a race condition or RLS issue
        debugPrint('User record not found in laundry_users - routing to login');
        setState(() {
          _initialRoute = const LoginPage();
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, try to determine from session metadata or default
      if (!mounted) return;
      
      debugPrint('Error checking user role: ${safeErrorToString(e)}');
      
      // Check if user metadata has role info
      final userMetadata = session.user.userMetadata;
      final roleFromMetadata = userMetadata?['role'] as String?;
      
      debugPrint('Role from metadata: $roleFromMetadata');
      
      setState(() {
        if (roleFromMetadata == 'admin') {
          _initialRoute = const ManagerDashboard();
        } else {
          // Non-admin users are not allowed - just route to login
          // DO NOT sign out - user is authenticated, just unauthorized
          debugPrint('Role from metadata "$roleFromMetadata" is not admin - routing to login');
          _initialRoute = const LoginPage();
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use build key + timestamp to force complete rebuild on hot restart
    return MaterialApp(
      key: ValueKey('app_${widget.buildTimestamp}_$_buildKey'),
      title: 'Inventory Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : (_initialRoute ?? const LoginPage()),
    );
  }
}
