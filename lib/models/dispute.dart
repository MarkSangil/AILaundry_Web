class Dispute {
  final String? id;
  final String type; // missing, duplicate, wrong
  final String notes;
  final String status; // pending, resolved, rejected
  final String? customerId;
  final String? itemId;
  final String? matchedItemId; // The item matched by admin to resolve the dispute
  final String? resolutionNotes;
  final String? createdAt;
  final String? updatedAt;

  Dispute({
    this.id,
    required this.type,
    required this.notes,
    this.status = 'pending',
    this.customerId,
    this.itemId,
    this.matchedItemId,
    this.resolutionNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory Dispute.fromMap(Map<String, dynamic> map) {
    return Dispute(
      id: map['id'],
      type: map['type'] ?? '',
      // Map 'description' from database to 'notes' in model
      notes: map['description'] ?? map['notes'] ?? '',
      status: map['status'] ?? 'pending',
      customerId: map['customer_id'],
      itemId: map['item_id'],
      matchedItemId: map['matched_item_id'],
      resolutionNotes: map['resolution_notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      // Map 'notes' from model to 'description' in database
      'description': notes,
      'status': status,
      if (customerId != null) 'customer_id': customerId,
      if (itemId != null) 'item_id': itemId,
      if (matchedItemId != null) 'matched_item_id': matchedItemId,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
    };
  }
}

