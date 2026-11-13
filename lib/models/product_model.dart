class Product {
  final String id;
  final String name;
  final String category;
  final double costPrice;
  final double sellingPrice;
  int stock;
  final int reorderLevel;

  Product({required this.id, required this.name, required this.category,
    required this.costPrice, required this.sellingPrice, required this.stock,
    this.reorderLevel = 10});

  String get stockStatus => stock == 0 ? 'Out of Stock' : stock <= reorderLevel ? 'Low Stock' : 'In Stock';
}
