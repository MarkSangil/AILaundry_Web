import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

import 'package:ailaundry_web/login_page.dart';
import 'package:ailaundry_web/models/login_history.dart';
import 'package:ailaundry_web/pages/data_management_section.dart';
import 'package:ailaundry_web/pages/dispute_resolution_center.dart';
import 'package:ailaundry_web/pages/login_history_section.dart';
import 'package:ailaundry_web/pages/reports_section.dart';
import 'package:ailaundry_web/pages/system_settings_section.dart';
import 'package:ailaundry_web/pages/user_management_section.dart';
import 'package:ailaundry_web/services/login_history_service.dart';
import 'package:ailaundry_web/services/report_service.dart';
import 'package:ailaundry_web/utils/error_utils.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  int _selectedIndex = 0;
  Map<String, dynamic>? _metrics;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    try {
      final reportService = ReportService(supabase);
      final metrics = await reportService.getTodayMetrics();
      setState(() {
        _metrics = metrics;
        _isLoadingMetrics = false;
      });
    } catch (e) {
      setState(() => _isLoadingMetrics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading metrics: ${safeErrorToString(e)}')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Log logout activity - find most recent login without logout
        try {
          final loginHistoryService = LoginHistoryService(supabase);
          final recentLogins = await loginHistoryService.fetchAllLoginHistory(
            userId: currentUser.id,
            limit: 1,
          );
          if (recentLogins.isNotEmpty && recentLogins.first.logoutAt == null) {
            // Find the login record ID from the database
            // Get all logins and filter for null logout_at in code
            final allLogins = await supabase
                .from('login_history')
                .select('id, logout_at')
                .eq('user_id', currentUser.id)
                .order('login_at', ascending: false)
                .limit(10);
            
            final activeLogin = List<Map<String, dynamic>>.from(allLogins)
                .firstWhere(
                  (login) => login['logout_at'] == null,
                  orElse: () => <String, dynamic>{},
                );
            
            if (activeLogin.isNotEmpty && activeLogin['id'] != null) {
              await loginHistoryService.logLogout(activeLogin['id'] as String);
            }
          }
        } catch (e) {
          // Silently fail - logout logging shouldn't block logout
          debugPrint('Failed to log logout activity: ${safeErrorToString(e)}');
        }
      }
      
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${safeErrorToString(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Manager Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 2,
        shadowColor: colorScheme.primary.withOpacity(0.3),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMetrics,
              tooltip: 'Refresh Metrics',
              color: Colors.white,
              iconSize: 22,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, left: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
              tooltip: 'Logout',
              color: Colors.white,
              iconSize: 22,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              tabs: const [
                Tab(
                  height: 56,
                  icon: Icon(Icons.dashboard_rounded, size: 22),
                  text: 'Overview',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.gavel_rounded, size: 22),
                  text: 'Disputes',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.inventory_2_rounded, size: 22),
                  text: 'Data Management',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.people_rounded, size: 22),
                  text: 'Users',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.analytics_rounded, size: 22),
                  text: 'Reports',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.settings_rounded, size: 22),
                  text: 'Settings',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme, colorScheme),
          _buildDisputesTab(theme, colorScheme),
          _buildDataManagementTab(theme, colorScheme),
          _buildUsersTab(theme, colorScheme),
          _buildReportsTab(theme, colorScheme),
          _buildSettingsTab(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-Time Metrics',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingMetrics)
            const Center(child: CircularProgressIndicator())
          else if (_metrics != null)
            _buildMetricsGrid(theme, colorScheme, _metrics!)
          else
            const Center(child: Text('No metrics available')),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActions(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, ColorScheme colorScheme, Map<String, dynamic> metrics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildMetricCard(
          theme,
          colorScheme,
          'Items Scanned Today',
          metrics['itemsScannedToday'].toString(),
          Icons.scanner,
          Colors.blue,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Approval Rate',
          '${metrics['approvalRate']}%',
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Open Disputes',
          metrics['disputesOpen'].toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Resolved Disputes',
          metrics['disputesResolved'].toString(),
          Icons.verified,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildMetricCard(ThemeData theme, ColorScheme colorScheme, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, ColorScheme colorScheme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(theme, colorScheme, 'View Disputes', Icons.gavel, () {
          _tabController.animateTo(1);
        }),
        _buildActionCard(theme, colorScheme, 'Manage Items', Icons.inventory, () {
          _tabController.animateTo(2); // Data Management is now index 2
        }),
        _buildActionCard(theme, colorScheme, 'View Reports', Icons.analytics, () {
          _tabController.animateTo(4); // Reports is now index 4
        }),
      ],
    );
  }

  Widget _buildActionCard(ThemeData theme, ColorScheme colorScheme, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisputesTab(ThemeData theme, ColorScheme colorScheme) {
    return const DisputeResolutionCenter();
  }

  Widget _buildDataManagementTab(ThemeData theme, ColorScheme colorScheme) {
    return const DataManagementSection();
  }

  Widget _buildUsersTab(ThemeData theme, ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'User Management', icon: Icon(Icons.people)),
              Tab(text: 'Login History', icon: Icon(Icons.history)),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                UserManagementSection(),
                LoginHistorySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(ThemeData theme, ColorScheme colorScheme) {
    return const ReportsSection();
  }

  Widget _buildSettingsTab(ThemeData theme, ColorScheme colorScheme) {
    return const SystemSettingsSection();
  }
}
