import 'package:flutter/material.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xeabnvfxnkooljbqhkce.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYWJudmZ4bmtvb2xqYnFoa2NlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NTE1NDAsImV4cCI6MjA2ODQyNzU0MH0.zyc3Cu108kLn_xed5iVeQ2TpZRTyX59RihHpI2O9RQg',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginPage()
          : const DashboardPage(),
    );
  }
}
