class Customer {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Customer({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      address: map['address'],
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      'is_active': isActive,
    };
  }
}

