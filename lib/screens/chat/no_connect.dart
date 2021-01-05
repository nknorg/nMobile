import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/utils/extensions.dart';

class NoConnectScreen extends StatefulWidget {
//  static const String routeName = '/chat/no_connect';

  final VoidCallback onConnectClick;

  const NoConnectScreen(this.onConnectClick);

  @override
  _NoConnectScreenState createState() => _NoConnectScreenState();
}

class _NoConnectScreenState extends State<NoConnectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Label(NL10ns.of(context).menu_chat.toUpperCase(), type: LabelType.h2).pad(l: 20.w.d),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        leading: null,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(left: 20.w, right: 20.w),
          color: DefaultTheme.backgroundColor1,
          child: Container(
            child: Flex(
              direction: Axis.vertical,
              children: [
                Expanded(
                  flex: 0,
                  child: Image(image: AssetImage("assets/chat/messages.png"), width: 198.w, height: 144.h).pad(t: 80.h.d),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: [
                      Label(
                        NL10ns.of(context).chat_no_wallet_title,
                        type: LabelType.h2,
                        textAlign: TextAlign.center,
                      ).pad(t: 32.h.d),
                      Label(
                        NL10ns.of(context).click_connect,
                        type: LabelType.bodyRegular,
                        textAlign: TextAlign.center,
                      ).pad(t: 8.h.d)
                    ],
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: BlocBuilder<WalletsBloc, WalletsState>(builder: (context, state) {
                          if (state is WalletsLoaded) {
                            return Button(
                              width: double.infinity,
                              text: NL10ns.of(context).connect,
                              onPressed: widget.onConnectClick,
                            );
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
