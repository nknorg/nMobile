import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/model/entity/wallet.dart';

typedef OnConnectFunc = void Function();
typedef OnMessageFunc = void Function(String src, String data, Uint8List pid);

abstract class NKNClientEvent extends Equatable {
  const NKNClientEvent();

  @override
  List<Object> get props => [];
}

class NKNCreateClientEvent extends NKNClientEvent {
  final WalletSchema wallet;
  final String password;

  const NKNCreateClientEvent(this.wallet, this.password);
}

class NKNConnectingClientEvent extends NKNClientEvent {
  final Uint8List seedList;
  final String clientAddress;

  const NKNConnectingClientEvent(this.seedList, this.clientAddress);
}

class NKNRecreateClientEvent extends NKNClientEvent {}

class NKNDisConnectClientEvent extends NKNClientEvent {}

class NKNConnectedClientEvent extends NKNClientEvent {}

class NKNOnMessageEvent extends NKNClientEvent {
  final MessageSchema message;

  const NKNOnMessageEvent(this.message);
}
