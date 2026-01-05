class StatusHistory {
  final String? id;
  final String clothesId;
  final String? oldStatus;
  final String newStatus;
  final String? changedBy;
  final String? notes;
  final String? createdAt;

  StatusHistory({
    this.id,
    required this.clothesId,
    this.oldStatus,
    required this.newStatus,
    this.changedBy,
    this.notes,
    this.createdAt,
  });

  factory StatusHistory.fromMap(Map<String, dynamic> map) {
    return StatusHistory(
      id: map['id'],
      clothesId: map['clothes_id'] ?? '',
      oldStatus: map['old_status'],
      newStatus: map['new_status'] ?? '',
      changedBy: map['changed_by'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clothes_id': clothesId,
      if (oldStatus != null) 'old_status': oldStatus,
      'new_status': newStatus,
      if (changedBy != null) 'changed_by': changedBy,
      if (notes != null) 'notes': notes,
    };
  }
}
