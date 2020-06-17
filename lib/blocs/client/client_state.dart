import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/message.dart';

abstract class ClientState extends Equatable {
  const ClientState();
  @override
  List<Object> get props => [];
}

class NoConnect extends ClientState {}

class Connecting extends ClientState {}

class Connected extends ClientState {
  final ClientSchema client;
  MessageSchema message;
  Connected({this.client, this.message});
}
