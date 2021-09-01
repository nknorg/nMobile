class WalletType {
  static const String nkn = 'nkn';
  static const String eth = 'eth';
}

class WalletSchema {
  String type;
  String address;
  String publicKey;
  double? balance = 0;
  double? balanceEth = 0;

  String? name;
  bool isBackedUp = false;

  WalletSchema({
    required this.type,
    required this.address,
    required this.publicKey,
    this.balance = 0,
    this.balanceEth = 0,
    this.name,
    this.isBackedUp = false,
  });

  static WalletSchema fromMap(Map<String, dynamic> map) {
    return WalletSchema(
      type: map['type'] ?? "",
      address: map['address'] ?? "",
      publicKey: map['public_key'] ?? "",
      balance: map['balance'] ?? 0,
      balanceEth: map['balanceEth'] ?? 0,
      name: map['name'],
      isBackedUp: map['is_backed_up'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'address': address,
      'public_key': publicKey,
      'balance': balance ?? 0,
      'balanceEth': balanceEth ?? 0,
      'name': name,
      'is_backed_up': isBackedUp,
    };
  }

  @override
  String toString() {
    return 'WalletSchema{type: $type, address: $address, publicKey: $publicKey, balance: $balance, balanceEth: $balanceEth, name: $name, isBackedUp: $isBackedUp}';
  }
}
