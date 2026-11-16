enum StoreRole {
  owner,
  cashier,
  inventory,
  customer,
  staff;

  static StoreRole? parse(Object? value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }

  bool get canSell => this == owner || this == cashier || this == staff;
  bool get canManageInventory =>
      this == owner || this == inventory || this == staff;
  bool get canEditProducts => this == owner || this == inventory;
  bool get canRecordExpenses => this == owner || this == inventory;
  bool get canViewProfit => this == owner;
  String get label => switch (this) {
        owner => 'Owner',
        cashier => 'Cashier',
        inventory => 'Inventory personnel',
        customer => 'Customer',
        staff => 'Staff',
      };
}
