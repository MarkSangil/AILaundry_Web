class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'info', 'dispute', 'status_update', etc.
  final String? relatedId; // ID of related record (e.g., dispute_id)
  final String? relatedType; // Type of related record (e.g., 'dispute', 'item')
  final bool isRead;
  final String? createdAt;
  final String? readAt;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    this.relatedType,
    this.isRead = false,
    this.createdAt,
    this.readAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      relatedId: map['related_id'],
      relatedType: map['related_type'],
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'],
      readAt: map['read_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      if (relatedId != null) 'related_id': relatedId,
      if (relatedType != null) 'related_type': relatedType,
      'is_read': isRead,
      if (createdAt != null) 'created_at': createdAt,
      if (readAt != null) 'read_at': readAt,
    };
  }
}

