import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/no_wallet_account.dart';
import 'package:nmobile/utils/log_tag.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final ActivePage activePage;

  ChatScreen(this.activePage);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, Tag {
  bool firstShow = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, state) {
        if (state is WalletsLoaded) {
          if (state.wallets.length > 0) {
            return BlocBuilder<ClientBloc, ClientState>(
              builder: (context, clientState) {
                if (clientState is NoConnect) {
                  LOG(tag).w('firstShow:$firstShow');
                  firstShow = false;
                  return NoConnectScreen(widget.activePage);
                } else {
                  return ChatHome(widget.activePage);
                }
              },
            );
          } else {
            return NoWalletAccount(widget.activePage);
          }
        }
        return Container();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
