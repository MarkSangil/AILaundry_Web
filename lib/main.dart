import 'package:ailaundry_web/login_page.dart';
import 'package:ailaundry_web/manager_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xeabnvfxnkooljbqhkce.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYWJudmZ4bmtvb2xqYnFoa2NlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NTE1NDAsImV4cCI6MjA2ODQyNzU0MH0.zyc3Cu108kLn_xed5iVeQ2TpZRTyX59RihHpI2O9RQg',
  );
  
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
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _determineInitialRoute();
      }
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
          if (role == 'admin' || role == 'manager') {
            _initialRoute = const ManagerDashboard();
          } else {
            // Non-admin users are not allowed - sign them out and show login
            Supabase.instance.client.auth.signOut();
            _initialRoute = const LoginPage();
          }
          _isLoading = false;
        });
      } else {
        // User exists in auth but not in laundry_users - not allowed
        Supabase.instance.client.auth.signOut();
        setState(() {
          _initialRoute = const LoginPage();
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, try to determine from session metadata or default
      if (!mounted) return;
      
      // Check if user metadata has role info
      final userMetadata = session.user.userMetadata;
      final roleFromMetadata = userMetadata?['role'] as String?;
      
      setState(() {
        if (roleFromMetadata == 'admin' || roleFromMetadata == 'manager') {
          _initialRoute = const ManagerDashboard();
        } else {
          // Non-admin users are not allowed - sign them out
          Supabase.instance.client.auth.signOut();
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
