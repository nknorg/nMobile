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

  WalletSchema({this.address, this.type, this.name, this.balance = 0, this.balanceEth = 0});

  WalletSchema.fromCacheMap(Map map) {
    this.address = map['address'];
    this.type = map['type'];
    this.name = map['name'];
    this.balance = map['balance'];
    this.balanceEth = map['balanceEth'];
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'address': address,
      'type': type,
      'name': name,
      'balance': balance,
      'balanceEth': balanceEth,
    };
  }

  @override
  String toString() {
    return 'WalletSchema{address: $address, type: $type, name: $name, balance: $balance, balanceEth: $balanceEth}';
  }
}
