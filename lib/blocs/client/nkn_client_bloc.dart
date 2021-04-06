import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:nmobile/blocs/auth/auth_bloc.dart';
import 'package:nmobile/blocs/auth/auth_event.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/entity/wallet.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class NKNClientBloc extends Bloc<NKNClientEvent, NKNClientState> {
  ChatBloc cBloc;
  AuthBloc aBloc;

  WalletSchema rWallet;
  String rPassword;

  NKNClientBloc({@required this.cBloc, this.aBloc}) {
    this.listen((state) {
      NLog.w('ClientBloc | onData | $state');
    }, onDone: () {
      NLog.w('ClientBloc | onDone.');
    }, onError: (e) {
      NLog.w('ClientBloc | onError | $e');
    });
  }

  @override
  NKNClientState get initialState => NKNNoConnectState();

  @override
  Stream<NKNClientState> mapEventToState(NKNClientEvent event) async* {
    if (event is NKNCreateClientEvent) {
      var wallet = event.wallet;
      var password = event.password;

      if (event.wallet == null || event.password == null) {
        showToast('wallet or password is null Exception!');
        NLog.w('wallet or password is null Exception');
      }

      rWallet = wallet;
      rPassword = password;
      var eWallet = await wallet.exportWallet(password);
      var walletAddress = eWallet['address'];
      var publicKey = eWallet['publicKey'];

      Uint8List seedList = Uint8List.fromList(hexDecode(eWallet['seed']));
      if (seedList != null && seedList.isEmpty) {
        NLog.w('Wrong!!! seedList.isEmpty');
      }
      String _seedKey =
          hexEncode(sha256(hexEncode(seedList.toList(growable: false))));

      if (NKNClientCaller.currentChatId == null ||
          publicKey == NKNClientCaller.currentChatId ||
          NKNClientCaller.currentChatId.length == 0) {
        await NKNDataManager.instance.initDataBase(publicKey, _seedKey);
      } else {
        await NKNDataManager.instance.changeDatabase(publicKey, _seedKey);
      }
      NKNClientCaller.instance.setChatId(publicKey);

      aBloc.add(AuthToUserEvent(publicKey, walletAddress));

      NKNClientCaller.instance.createClient(seedList, null, publicKey);

      yield NKNConnectingState();
    } else if (event is NKNRecreateClientEvent) {
      this.add(NKNCreateClientEvent(rWallet, rPassword));
      yield NKNConnectingState();
    } else if (event is NKNConnectedClientEvent) {
      yield NKNConnectedState();
    } else if (event is NKNDisConnectClientEvent) {
      NKNClientCaller.disConnect();
      yield NKNNoConnectState();
    } else if (event is NKNOnMessageEvent) {
      cBloc.add(ReceiveMessageEvent(event.message));
      yield NKNConnectedState();
    }
  }
}
