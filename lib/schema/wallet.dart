class WalletType {
  static const String nkn = 'nkn';
  static const String eth = 'eth';
}

class WalletSchema {
  String address;
  String type;
  String name;
  double balance = 0;
  double balanceEth = 0;

  // DEPRECATED:GG
  // bool isBackedUp = false;

  WalletSchema({
    this.address,
    this.type,
    this.name,
    this.balance = 0,
    this.balanceEth = 0,
  });

  WalletSchema.fromMap(Map map) {
    this.address = map['address'];
    this.type = map['type'];
    this.name = map['name'];
    this.balance = map['balance'] ?? 0;
    this.balanceEth = map['balanceEth'] ?? 0;
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
    return 'WalletSchema{address: $address, type: $type, name: $name, balance: $balance, balanceEth: $balanceEth}';
  }
}
