class WalletType {
  static const nkn = 'nkn';
  static const eth = 'eth';
}

class WalletSchema {
  String type;
  String address;
  String publicKey;
  double balance = 0;
  double balanceEth = 0;

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
    WalletSchema schema = WalletSchema(
      type: map['type'] ?? "",
      address: map['address'] ?? "",
      publicKey: map['publicKey'] ?? "",
      balance: map['balance'] ?? 0,
      balanceEth: map['balanceEth'] ?? 0,
      name: map['name'],
      isBackedUp: map['isBackedUp'] ?? false,
    );
    schema.address = schema.address.replaceAll("\n", "").trim();
    schema.publicKey = schema.publicKey.replaceAll("\n", "").trim();
    return schema;
  }

  Map<String, dynamic> toMap() {
    address = address.replaceAll("\n", "").trim();
    publicKey = publicKey.replaceAll("\n", "").trim();
    return {
      'type': type,
      'address': address,
      'publicKey': publicKey,
      'balance': balance,
      'balanceEth': balanceEth,
      'name': name,
      'isBackedUp': isBackedUp,
    };
  }

  @override
  String toString() {
    return 'WalletSchema{type: $type, address: $address, publicKey: $publicKey, balance: $balance, balanceEth: $balanceEth, name: $name, isBackedUp: $isBackedUp}';
  }
}
