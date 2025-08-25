class ClothesItem {
  final String id;
  final String brand;
  final String type;
  final String color;
  final String? imageUrl;
  final String? createdAt;

  ClothesItem({
    required this.id,
    required this.brand,
    required this.type,
    required this.color,
    this.imageUrl,
    this.createdAt,
  });

  factory ClothesItem.fromMap(Map<String, dynamic> map) {
    return ClothesItem(
      id: map['id'] ?? '',
      brand: map['brand'] ?? '',
      type: map['type'] ?? '',
      color: map['color'] ?? '',
      imageUrl: map['image_url'],
      createdAt: map['created_at'],
    );
  }
}
