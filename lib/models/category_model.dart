class Category{
  int? categoryId;
  String categoryName;

  Category({this.categoryId, required this.categoryName});

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
    };
  }
}