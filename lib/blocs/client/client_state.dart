import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/message.dart';

abstract class NKNClientState extends Equatable {
  const NKNClientState();

  @override
  List<Object> get props => [];
}

class NKNNoConnectState extends NKNClientState {}

class NKNConnectingState extends NKNClientState {}

class NKNConnectedState extends NKNClientState {
  // NKNConnectedState();
  final ClientSchema client;
  MessageSchema message;

  NKNConnectedState({this.client, this.message});
}