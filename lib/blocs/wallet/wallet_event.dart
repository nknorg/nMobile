part of 'wallet_bloc.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object> get props => [];
}

// load
class WalletEventLoad extends WalletEvent {
  @override
  String toString() {
    return 'WalletEventLoad{}';
  }
}

// reload
class WalletEventReload extends WalletEvent {
  @override
  String toString() {
    return 'WalletEventReload{}';
  }
}

// add
class WalletEventAdd extends WalletEvent {
  final WalletSchema wallet;
  final String keystore; // TODO:GG 不是seed吗？必须的？

  WalletEventAdd(this.wallet, this.keystore);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() {
    return 'WalletEventAdd{wallet: $wallet, keystore: $keystore}';
  }
}

// delete
class WalletEventDel extends WalletEvent {
  final WalletSchema wallet;

  WalletEventDel(this.wallet);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() {
    return 'WalletEventDel{wallet: $wallet}';
  }
}

// update
class WalletEventUpd extends WalletEvent {
  final WalletSchema wallet;

  WalletEventUpd(this.wallet);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() {
    return 'WalletEventUpd{wallet: $wallet}';
  }
}

// update_balance
class WalletEventUpdBalance extends WalletEvent {
  @override
  List<Object> get props => [];

  @override
  String toString() {
    return 'WalletEventUpdBalance{}';
  }
}

// update_backed_up
class WalletEventUpdBackedUp extends WalletEvent {
  final String address;

  WalletEventUpdBackedUp(this.address);

  @override
  List<Object> get props => [address];

  @override
  String toString() {
    return 'WalletEventUpdBackedUp{address: $address}';
  }
}
