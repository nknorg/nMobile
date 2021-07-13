class WalletType {
  static const String nkn = 'nkn';
  static const String eth = 'eth';
}

class WalletSchema {
  String address;
  String type;

  String? name;
  double? balance = 0;
  double? balanceEth = 0;

  // DEPRECATED:GG
  // bool isBackedUp = false;

  WalletSchema({
    required this.address,
    required this.type,
    this.name,
    this.balance = 0,
    this.balanceEth = 0,
  });

  static WalletSchema fromMap(Map<String, dynamic> map) {
    return WalletSchema(
      address: map['address'] ?? "",
      type: map['type'] ?? "",
      name: map['name'],
      balance: map['balance'] ?? 0,
      balanceEth: map['balanceEth'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'type': type,
      'name': name,
      'balance': balance ?? 0,
      'balanceEth': balanceEth ?? 0,
    };
  }

  @override
  String toString() {
    return 'WalletSchema{type: $type, address: $address, name: $name, balance: $balance, balanceEth: $balanceEth}';
  }
}
