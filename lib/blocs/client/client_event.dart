import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/wallet.dart';

typedef OnConnectFunc = void Function();
typedef OnMessageFunc = void Function(String src, String data, Uint8List pid);

abstract class ClientEvent extends Equatable {
  const ClientEvent();

  @override
  List<Object> get props => [];
}

class CreateClient extends ClientEvent {
  final WalletSchema wallet;
  final String password;
  const CreateClient(this.wallet, this.password);
}

class DisConnected extends ClientEvent {}

class ConnectedClient extends ClientEvent {}

class Listen extends ClientEvent {
  final OnConnectFunc onConnect;
  final OnMessageFunc onMessage;

  const Listen({this.onConnect, this.onMessage});
}

class OnConnect extends ClientEvent {
  final ClientSchema client;
  const OnConnect(this.client);
}

class OnMessage extends ClientEvent {
  final MessageSchema message;
  const OnMessage(this.message);
}
