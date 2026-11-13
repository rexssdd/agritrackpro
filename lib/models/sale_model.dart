class Sale {
  final String id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final String paymentMethod;
  final DateTime createdAt;

  Sale({required this.id, required this.productName, required this.quantity,
    required this.unitPrice, required this.unitCost, required this.paymentMethod,
    required this.createdAt});

  double get total => quantity * unitPrice;
  double get costOfGoods => quantity * unitCost;
}
