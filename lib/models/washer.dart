class Washer {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String role; // washer, checker, manager
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Washer({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'washer',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Washer.fromMap(Map<String, dynamic> map) {
    return Washer(
      id: map['id'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'washer',
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap({bool includeIsActive = false, bool includePhone = false}) {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (includePhone && phone != null) 'phone': phone,
      'role': role,
      if (includeIsActive) 'is_active': isActive,
    };
  }
}

