import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/no_wallet_account.dart';
import 'package:nmobile/screens/settings/app_upgrade.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, state) {
        Timer(Duration(seconds: 2), () async {
          UpgradeChecker.autoCheckUpgrade(context);
        });
        if (state is WalletsLoaded) {
          if (state.wallets.length > 0) {
            return BlocBuilder<ClientBloc, ClientState>(
              builder: (context, clientState) {
                if (clientState is NoConnect) {
                  return NoConnectScreen();
                } else {
                  Global.isAutoShowPassword = true;
                  return ChatHome();
                }
              },
            );
          } else {
            Global.isAutoShowPassword = true;
            return NoWalletAccount();
          }
        }
        return Container();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
