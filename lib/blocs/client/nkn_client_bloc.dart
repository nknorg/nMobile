import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';

class NKNClientBloc extends Bloc<NKNClientEvent, NKNClientState>{
  ChatBloc cBloc;
  AuthBloc aBloc;

  NKNClientBloc({@required this.cBloc,this.aBloc}) {
    this.listen((state) {
      print('ClientBloc | onData | $state');
    }, onDone: () {
      print('ClientBloc | onDone.');
    }, onError: (e) {
      print('ClientBloc | onError | $e');
    });
  }

  @override
  NKNClientState get initialState => NKNNoConnectState();

  @override
  Stream<NKNClientState> mapEventToState(NKNClientEvent event) async* {
    if (event is NKNCreateClientEvent) {
      print('Create Client begin');
      var wallet = event.wallet;
      var password = event.password;
      var eWallet = await wallet.exportWallet(password);
      var walletAddress = eWallet['address'];
      var publicKey = eWallet['publicKey'];

      Uint8List seedList = Uint8List.fromList(hexDecode(eWallet['seed']));
      if (seedList.isEmpty){
        Global.debugLog('seedList.isEmpty');
      }
      String _seedKey = hexEncode(sha256(hexEncode(seedList.toList(growable: false))));

      NKNClientCaller.instance.createClient(seedList, null, null);
      if (NKNClientCaller.currentChatId == null || publicKey == NKNClientCaller.currentChatId || NKNClientCaller.currentChatId.length == 0){
        NKNDataManager.instance.initDataBase(publicKey, _seedKey);
      }
      else{
        await NKNDataManager.instance.changeDatabase(publicKey, _seedKey);
      }
      NKNClientCaller.instance.setPubkeyAndChatId(publicKey, publicKey);

      aBloc.add(AuthToUserEvent(publicKey,walletAddress));

      print('Create Client End');
      yield NKNConnectingState();
    }
    else if (event is NKNConnectedClientEvent){
      print('Connected on Connected');
      yield NKNConnectedState();
    }
    else if (event is NKNDisConnectClientEvent) {
      print('Client Disconnect called');
      NKNClientCaller.disConnect();
      yield NKNNoConnectState();
    }
    else if (event is NKNOnMessageEvent){
      print('Client Connected');
      NKNConnectedState currentState = (state as NKNConnectedState);
      currentState.message = event.message;
      cBloc.add(ReceiveMessageEvent(currentState.message));
      cBloc.add(RefreshMessageListEvent());
      yield NKNConnectedState();
    }
  }
}

