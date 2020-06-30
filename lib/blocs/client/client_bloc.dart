import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart' as chatEvent;
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:oktoast/oktoast.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  @override
  ClientState get initialState => NoConnect();
  final ChatBloc chatBloc;

  ClientBloc({@required this.chatBloc}) {
    this.listen((state) {
      print('ClientBloc | onData | $state');
    }, onDone: () {
      print('ClientBloc | onDone.');
    }, onError: (e) {
      print('ClientBloc | onError | $e');
    });
  }

  @override
  Stream<ClientState> mapEventToState(ClientEvent event) async* {
    print('ClientBloc | mapEventToState | ChatBloc@${chatBloc.hashCode.toString().substring(0, 3)}');
    if (event is CreateClient) {
      yield* _mapCreateClientToState(event);
    } else if (event is ConnectedClient) {
      yield Connected();
    } else if (event is OnConnect) {
      yield* _mapOnConnectToState(event);
    } else if (event is OnMessage) {
      yield* _mapOnMessageToState(event);
    } else if (event is DisConnected) {
      yield* _mapDisConnect();
    }
  }

  Stream<ClientState> _mapCreateClientToState(CreateClient event) async* {
    yield* _connect(event.wallet, event.password);
  }

  Stream<ClientState> _mapDisConnect() async* {
    yield* _disConnect();
  }

  Stream<ClientState> _disConnect() async* {
    await NknClientPlugin.disConnect();
    yield NoConnect();
  }

  Stream<ClientState> _connect(WalletSchema wallet, String password) async* {
    try {
      var w = await wallet.exportWallet(password);
      var keystore = await wallet.getKeystore();
      var walletAddr = w['address'];
      var publicKey = w['publicKey'];
      Global.currentChatDb = await SqliteStorage.open('${SqliteStorage.CHAT_DATABASE_NAME}_$publicKey', hexEncode(sha256(w['seed'])));
      Global.currentClient = ClientSchema(publicKey: publicKey, address: publicKey);
      Global.currentWalletName = wallet.name;
      Global.currentUser = await ContactSchema.getContactByAddress(publicKey);
      if (Global.currentUser == null) {
        DateTime now = DateTime.now();
        await ContactSchema(
          type: ContactType.me,
          clientAddress: publicKey,
          nknWalletAddress: walletAddr,
          createdTime: now,
          updatedTime: now,
          profileVersion: uuid.v4(),
        ).createContact();
        Global.currentUser = await ContactSchema.getContactByAddress(publicKey);
      }
      yield Connecting();

      for (var i = 0; i < 3; i++) {
        try {
          await NknClientPlugin.createClient('', keystore, password);
          break;
        } catch (e) {
          if (i == 3) {
            yield NoConnect();
          }
          debugPrint(e);
          debugPrintStack();
        }
      }
    } catch (e) {
      if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
        showToast(NMobileLocalizations.of(Global.appContext).tip_password_error);
        yield NoConnect();
      }
    }
  }

  Stream<ClientState> _mapOnConnectToState(OnConnect event) async* {
    if (state is Connected) {
      Global.currentClient = event.client;
      chatBloc.add(chatEvent.Connect());
      yield Connected(client: event.client);
    }
  }

  Stream<ClientState> _mapOnMessageToState(OnMessage event) async* {
    print('ClientBloc | OnMessage | ${event.message}');
    if (state is Connected) {
      print('ClientBloc | OnMessage | Connected -->');
      Connected currentState = (state as Connected);
      currentState.message = event.message;
      chatBloc.add(chatEvent.ReceiveMessage(currentState.message));
    }
  }
}
