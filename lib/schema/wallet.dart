class WalletType {
  static const String nkn = 'nkn';
  static const String eth = 'eth';
}

class WalletSchema {
  final String address;
  final String type;
  String name;
  double balance = 0;
  String keystore;
  double balanceEth = 0;

  WalletSchema({this.address, this.type, this.name, this.balance = 0, this.balanceEth = 0});
}
