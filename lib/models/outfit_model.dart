class Outfit {
  final int? id;
  final String name;
  final String? note;
  final String? occasion; // dịp mặc: 'Công sở', 'Đi chơi', 'Đi tiệc', v.v.
  final DateTime createdAt;

  Outfit({
    this.id,
    required this.name,
    this.note,
    this.occasion,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'note': note,
      'occasion': occasion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Outfit.fromMap(Map<String, dynamic> map) {
    return Outfit(
      id: map['id'],
      name: map['name'],
      note: map['note'],
      occasion: map['occasion'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

// Bảng trung gian Many-to-Many: Outfit <-> Item
class OutfitItem {
  final int? id;
  final int outfitId;
  final int itemId;
  final String? position; // 'top', 'bottom', 'shoes', 'accessory', etc.

  OutfitItem({
    this.id,
    required this.outfitId,
    required this.itemId,
    this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outfitId': outfitId,
      'itemId': itemId,
      'position': position,
    };
  }

  factory OutfitItem.fromMap(Map<String, dynamic> map) {
    return OutfitItem(
      id: map['id'],
      outfitId: map['outfitId'],
      itemId: map['itemId'],
      position: map['position'],
    );
  }
}