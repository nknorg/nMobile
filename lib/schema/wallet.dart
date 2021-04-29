import 'package:equatable/equatable.dart';

class WalletSchema extends Equatable {
  static const String TYPE_NKN = 'nkn';
  static const String TYPE_ETH = 'eth';

  final String address;
  final String type;

  String name = "";
  double balance = 0;
  double balanceEth = 0;
  bool isBackedUp = false;

  WalletSchema(this.type, this.address, {this.name = "", this.balance = 0, this.balanceEth = 0, this.isBackedUp = false});

  @override
  List<Object> get props => [address, type, name];

  @override
  String toString() {
    return 'WalletSchema{type: $type, address: $address, name: $name, balance: $balance, balanceEth: $balanceEth, isBackedUp: $isBackedUp}';
  }
}
