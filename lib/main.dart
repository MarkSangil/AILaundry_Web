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
  
  // Set up global error handler to prevent infinite loops from JavaScript objects
  FlutterError.onError = (FlutterErrorDetails details) {
    // Safely convert the error to string to prevent LegacyJavaScriptObject crashes
    final errorString = safeErrorToString(details.exception);
    
    // Check if this is a JavaScript object error that would cause infinite loops
    final exceptionStr = details.exception?.toString() ?? '';
    final isJsObjectError = errorString.contains('LegacyJavaScriptObject') || 
                            errorString.contains('Instance of') ||
                            exceptionStr.contains('LegacyJavaScriptObject') ||
                            exceptionStr.contains('DiagnosticsNode');
    
    // NEVER present JS object errors - they cause infinite loops
    if (isJsObjectError) {
      // For JS object errors, just log safely without rendering to prevent infinite loops
      debugPrint('Flutter Error (JS Object - suppressed): $errorString');
      return; // Exit early - don't try to render
    }
    
    // For non-JS errors, try to present them safely
    try {
      // Double-check the error details don't contain JS objects
      final stackStr = safeErrorToString(details.stack);
      if (stackStr.contains('LegacyJavaScriptObject') || stackStr.contains('DiagnosticsNode')) {
        debugPrint('Flutter Error (JS Object in stack - suppressed): $errorString');
        return;
      }
      
      FlutterError.presentError(details);
    } catch (e) {
      // If presenting the error itself fails, just log it
      debugPrint('Error presenting error: ${safeErrorToString(e)}');
    }
  };
  
  // Also catch platform errors (like JS interop issues)
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorString = safeErrorToString(error);
    debugPrint('Platform Error: $errorString');
    return true; // Handled - prevent default error handling
  };
  
  try {
    await Supabase.initialize(
      url: 'https://xeabnvfxnkooljbqhkce.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYWJudmZ4bmtvb2xqYnFoa2NlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NTE1NDAsImV4cCI6MjA2ODQyNzU0MH0.zyc3Cu108kLn_xed5iVeQ2TpZRTyX59RihHpI2O9RQg',
    );
  } catch (e) {
  }
  const buildTimestamp = '2025-01-27-v2'; 
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
      if (userRecord != null) {
        final role = userRecord['role'] as String?;
        setState(() {
          if (role == 'admin') {
            _initialRoute = const ManagerDashboard();
          } else {
            _initialRoute = const LoginPage();
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _initialRoute = const LoginPage();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final userMetadata = session.user.userMetadata;
      final roleFromMetadata = userMetadata?['role'] as String?;
      setState(() {
        if (roleFromMetadata == 'admin') {
          _initialRoute = const ManagerDashboard();
        } else {
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
