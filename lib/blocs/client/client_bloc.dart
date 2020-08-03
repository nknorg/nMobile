import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart' as chatEvent;
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/ncdn/miner_data.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> with AccountDependsBloc, Tag {
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
    print('ClientBloc | mapEventToState | $tag');
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
    account?.client.disConnect();
    yield NoConnect();
  }

  Stream<ClientState> _connect(WalletSchema wallet, String password) async* {
    try {
      var w = await wallet.exportWallet(password);
      var keystore = await wallet.getKeystore();
      var walletAddr = w['address'];
      var publicKey = w['publicKey'];

      var minerData = MinerData();
      minerData.ads = walletAddr;
      minerData.pub = publicKey;
      minerData.se = w['seed'];
      minerData.key = keystore;
      minerData.psd = password;
      Global.minerData = minerData;

      final currUser = DChatAccount(
        walletAddr,
        publicKey,
        Uint8List.fromList(hexDecode(w['seed'])),
        ClientEventListener(this),
      );
      changeAccount(currUser, force: true);

      final currentUser = await ContactSchema.getContactByAddress(db, publicKey);
      if (currentUser == null) {
        DateTime now = DateTime.now();
        await ContactSchema(
          type: ContactType.me,
          clientAddress: publicKey,
          nknWalletAddress: walletAddr,
          createdTime: now,
          updatedTime: now,
          profileVersion: uuid.v4(),
        ).createContact(db);
      }
      yield Connecting();

      currUser.client.connect();
    } catch (e) {
      if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
        showToast(NMobileLocalizations.of(Global.appContext).tip_password_error);
        yield NoConnect();
      }
    }
  }

  Stream<ClientState> _mapOnConnectToState(OnConnect event) async* {
    if (state is Connected) {
//      Global.currentClient = event.client;
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

class ClientEventListener extends ClientEventDispatcher {
  final ClientBloc _clientBloc;

  ClientEventListener(this._clientBloc);

  @override
  void onConnect(String myChatId) {
    // To avoid confusion, since multi-account uses same `_clientBloc`.
    if (myChatId == _clientBloc.accountChatId) {
      _clientBloc.add(ConnectedClient());
    }
  }

  @override
  void onDisConnect(String myChatId) {
    // To avoid confusion, since multi-account uses same `_clientBloc`.
    if (myChatId == _clientBloc.accountChatId) {
      _clientBloc.add(DisConnected());
    }
  }

  @override
  void onMessage(String myChatId, Map data) {
    // To avoid confusion, since multi-account uses same `_clientBloc`.
    if (myChatId == _clientBloc.accountChatId) {
      _clientBloc.add(
        OnMessage(
          MessageSchema(from: data['src'], to: myChatId, data: data['data'], pid: data['pid']),
        ),
      );
    }
  }
}
