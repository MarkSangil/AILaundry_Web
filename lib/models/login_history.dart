class LoginHistory {
  final String id;
  final String userId;
  final String? loginAt;
  final String? ipAddress;
  final String? userAgent;
  final String? logoutAt;
  final String? sessionDuration;
  final String? createdAt;
  final String? userName;
  final String? userEmail;
  final String? userRole;

  LoginHistory({
    required this.id,
    required this.userId,
    this.loginAt,
    this.ipAddress,
    this.userAgent,
    this.logoutAt,
    this.sessionDuration,
    this.createdAt,
    this.userName,
    this.userEmail,
    this.userRole,
  });

  factory LoginHistory.fromMap(Map<String, dynamic> map) {
    return LoginHistory(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      loginAt: map['login_at'],
      ipAddress: map['ip_address'],
      userAgent: map['user_agent'],
      logoutAt: map['logout_at'],
      sessionDuration: map['session_duration'],
      createdAt: map['created_at'],
      userName: map['user_name'],
      userEmail: map['user_email'],
      userRole: map['user_role'],
    );
  }

  String get formattedLoginAt {
    if (loginAt == null) return 'N/A';
    try {
      final date = DateTime.parse(loginAt!);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return loginAt!;
    }
  }

  String get formattedLogoutAt {
    if (logoutAt == null) return 'N/A';
    try {
      final date = DateTime.parse(logoutAt!);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return logoutAt!;
    }
  }

  String get formattedSessionDuration {
    if (sessionDuration == null || logoutAt == null) return 'Active';
    try {
      // Parse PostgreSQL interval format (e.g., "01:30:45")
      final parts = sessionDuration!.split(':');
      if (parts.length >= 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        } else if (minutes > 0) {
          return '${minutes}m';
        } else {
          return '< 1m';
        }
      }
      return sessionDuration!;
    } catch (e) {
      return sessionDuration!;
    }
  }
}

