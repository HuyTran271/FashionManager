class Item{
  final int? id;
  final String name;
  final String imagePath;
  final int categoryId;
  final String? color;
  final String? style;

  Item({
    this.id,
    required this.name,
    required this.imagePath,
    required this.categoryId,
    this.color,
    this.style,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'categoryId': categoryId,
      'color': color,
      'style': style,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      imagePath: map['imagePath'],
      categoryId: map['categoryId'],
      color: map['color'],
      style: map['style'],
    );
  }
}