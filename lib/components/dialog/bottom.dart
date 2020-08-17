import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/input_channel.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BottomDialog extends StatefulWidget {
  @override
  _BottomDialogState createState() => _BottomDialogState();

  BuildContext context;

  BottomDialog();

  BottomDialog.of(this.context);

  WidgetBuilder builder;
  Widget action;
  double height;
  Function updateHeight;

  show<T>({@required WidgetBuilder builder, Widget action, double height}) {
    this.builder = builder;
    this.action = action;
    this.height = height;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      backgroundColor: DefaultTheme.backgroundLightColor,
      builder: (BuildContext context) {
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          child: this,
        );
      },
    );
  }

  Future<String> showInputPasswordDialog({@required String title}) {
    TextEditingController _passwordController = TextEditingController();
    double height = 280;
    return show<String>(
      height: height,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).continue_text,
          width: double.infinity,
          onPressed: () {
            Navigator.of(context).pop(_passwordController.text);
          },
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                child: Label(
                  title,
                  type: LabelType.h2,
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Label(
                    NL10ns.of(context).wallet_password,
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                  Textbox(
                    controller: _passwordController,
                    hintText: NL10ns.of(context).input_password,
                    validator: Validator.of(context).password(),
                    password: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  showAcceptDialog({@required String title, String subTitle, String content, @required VoidCallback onPressed}) {
    double height = 300;
    return show<String>(
      height: height,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).accept_invitation,
          width: double.infinity,
          onPressed: onPressed,
        ),
      ),
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Container(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Flex(
            direction: Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Label(
                    title,
                    type: LabelType.h2,
                  ),
                ),
              ),
              Expanded(
                flex: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Label(
                      subTitle,
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
              Textbox(
                value: content,
                enabled: false,
                hintText: NL10ns.of(context).enter_users_address,
              ),
            ],
          ),
        ),
      ),
    );
  }

  showInputAddressDialog({@required String title, String hint}) {
    TextEditingController _addressController = TextEditingController();
    double height = 300;
    GlobalKey formKey = new GlobalKey<FormState>();
    bool formValid = false;

    if (hint == null) {
      hint = NL10ns.of(context).enter_users_address;
    }

    return show<String>(
      height: height,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).continue_text,
          width: double.infinity,
          onPressed: () {
            if (formValid) {
              Navigator.of(context).pop(_addressController.text);
            }
          },
        ),
      ),
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Container(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Form(
            key: formKey,
            autovalidate: true,
            onChanged: () {
              formValid = (formKey.currentState as FormState).validate();
            },
            child: Flex(
              direction: Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    child: Label(
                      title,
                      type: LabelType.h3,
                    ),
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Label(
                        NL10ns.of(context).send_to,
                        type: LabelType.bodyRegular,
                        color: DefaultTheme.fontColor1,
                        textAlign: TextAlign.start,
                      ),
                      Textbox(
                        controller: _addressController,
                        validator: Validator.of(context).nknIdentifier(),
                        hintText: hint,
                        suffixIcon: GestureDetector(
                          onTap: () async {
                            var contact = await Navigator.of(context).pushNamed(ContactHome.routeName, arguments: true);
                            if (contact is ContactSchema) {
                              _addressController.text = contact.clientAddress;
                            }
                          },
                          child: Container(
                            width: 20,
                            alignment: Alignment.centerRight,
                            child: Icon(FontAwesomeIcons.solidAddressBook),
                          ),
                        ),
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

//  showInputChannelDialog({@required String title}) {
//    return show<String>(
//      builder: (context) => GestureDetector(
//        onTap: () {
//          FocusScope.of(context).requestFocus(FocusNode());
//        },
//        child: InputChannelDialog(
//          title: title,
//          updateHeight: updateHeight,
//        ),
//      ),
//    );
//  }

  showQrcodeDialog({@required String title, String data}) {
    double height = 500;
    return show<String>(
      height: height,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).close,
          width: double.infinity,
          backgroundColor: DefaultTheme.primaryColor.withAlpha(20),
          fontColor: DefaultTheme.primaryColor,
          onPressed: () {
            close();
          },
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                child: Label(
                  title,
                  type: LabelType.h2,
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Label(
                    NL10ns.of(context).seed_qrcode_dec,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: QrImage(
                        data: data,
                        version: QrVersions.auto,
                        size: 240.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  showSelectWalletDialog({@required String title, bool onlyNkn = false, void callback(WalletSchema wallet)}) {
    FilteredWalletsBloc _filteredWalletsBloc = BlocProvider.of<FilteredWalletsBloc>(context);
    double height = 300;
    return show<String>(
      height: height,
      builder: (context) => Container(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                child: Label(
                  title,
                  type: LabelType.h2,
                ),
              ),
            ),
            Expanded(
                flex: 1,
                child: BlocBuilder<WalletsBloc, WalletsState>(
                  builder: (context, state) {
                    if (state is WalletsLoaded) {
                      final wallets = onlyNkn ? state.wallets.where((w) => w.type == WalletSchema.NKN_WALLET).toList() : state.wallets;
                      return ListView.builder(
                        itemCount: wallets.length,
                        itemExtent: 74,
                        padding: const EdgeInsets.all(0),
                        itemBuilder: (BuildContext context, int index) {
                          var wallet = wallets[index];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (callback != null) {
                                callback(wallet);
                              }
                              _filteredWalletsBloc.add(LoadWalletFilter((x) => x.address == wallet.address));
                              close();
                            },
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 0,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colours.light_ff,
                                              borderRadius: BorderRadius.all(Radius.circular(8)),
                                            ),
                                            child: SvgPicture.asset('assets/logo.svg', color: Colours.purple_2e),
                                          ).pad(r: 16, t: 12, b: 12),
                                          wallet.type == WalletSchema.NKN_WALLET
                                              ? Space.empty
                                              : Positioned(
                                                  top: 8,
                                                  left: 32,
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(color: Colours.purple_53, shape: BoxShape.circle),
                                                    child: SvgPicture.asset('assets/ethereum-logo.svg'),
                                                  ),
                                                )
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Label(wallet.name, type: LabelType.h3).pad(b: 4),
                                          BlocBuilder<WalletsBloc, WalletsState>(
                                            builder: (context, state) {
                                              if (state is WalletsLoaded) {
                                                var w = state.wallets.firstWhere((x) => x == wallet);
                                                if (w != null) {
                                                  return Label(
                                                    Format.nknFormat(w.balance, decimalDigits: 4, symbol: 'NKN'),
                                                    type: LabelType.bodySmall,
                                                  );
                                                }
                                              }
                                              return Label('-- NKN', type: LabelType.bodySmall);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 0,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          wallet.type == WalletSchema.NKN_WALLET
                                              ? Container(
                                                  alignment: Alignment.center,
                                                  padding: 2.pad(l: 8, r: 8),
                                                  decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: Colours.green_06_a1p),
                                                  child: Text(
                                                    NL10ns.of(context).mainnet,
                                                    style: TextStyle(color: Colours.green_06, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                )
                                              : Container(
                                                  alignment: Alignment.center,
                                                  padding: 2.pad(l: 8, r: 8),
                                                  decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: Colours.purple_53_a1p),
                                                  child: Text(
                                                    NL10ns.of(context).ERC_20,
                                                    style: TextStyle(color: Colours.purple_53, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                          (wallet.type == WalletSchema.NKN_WALLET
                                                  ? Space.empty
                                                  : BlocBuilder<WalletsBloc, WalletsState>(builder: (context, state) {
                                                      return Label(
                                                        Format.nknFormat(wallet.balanceEth, symbol: 'ETH'),
                                                        type: LabelType.bodySmall,
                                                      );
                                                    }))
                                              .pad(t: 8),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(height: 1, color: Colours.light_e9).pad(l: 64),
                              ],
                            ),
                          );
                        },
                      );
                    }
                    return ListView();
                  },
                )),
          ],
        ),
      ),
    );
  }

  showBottomDialog({@required String title, @required Widget child, Widget action, double height = 300}) {
    return show<String>(
      height: height,
      action: action,
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Container(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Flex(
            direction: Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Label(
                    title,
                    type: LabelType.h2,
                  ),
                ),
              ),
              Expanded(
                flex: 0,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  close() {
    Navigator.of(context).pop();
  }
}

class _BottomDialogState extends State<BottomDialog> with SingleTickerProviderStateMixin {
  double _dy = 0;
  double _height = 300;
  double _dragHeight = 24;
  double _currentHeight;
  double _minHeight;
  double _maxHeight = 686;
  double _tweenHeight = 0;
  double _minFlingVelocity = 700;
  AnimationController _animationController;
  Color _dragColor = DefaultTheme.backgroundColor2;
  GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.updateHeight = (height) {
      _height = _minHeight = height;
      _animationController.reset();
      _animationController.forward();
    };
    _currentHeight = _minHeight = widget.height ?? _height;
    _animationController = new AnimationController(duration: const Duration(milliseconds: 200), vsync: this)
      ..addListener(() {
        setState(() {
          _tweenHeight = (_height - _currentHeight) * _animationController.value;
          _currentHeight = _currentHeight + _tweenHeight;
        });
      });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dy = details.globalPosition.dy;

    setState(() {
      _currentHeight = MediaQuery.of(context).size.height - _dy;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dy > _minFlingVelocity) {
      if (_currentHeight < _minHeight) {
        widget.close();
        return;
      }
      _height = _minHeight;
    } else if (details.velocity.pixelsPerSecond.dy < -_minFlingVelocity) {
      _height = _maxHeight;
    } else {
      if (_currentHeight > (_maxHeight - _minHeight + _currentHeight) / 2) {
        _height = _maxHeight;
      } else {
        _height = _minHeight;
      }
    }
    _animationController.reset();
    _animationController.forward();
    setState(() {
      _dragColor = DefaultTheme.backgroundColor2;
    });
  }

  void _handleDragDown(DragDownDetails details) {
    setState(() {
      _dragColor = DefaultTheme.backgroundColor2;
    });
  }

  void _handleDragCancel() {
    setState(() {
      _dragColor = DefaultTheme.backgroundColor2;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _dragColor = DefaultTheme.backgroundColor3;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _dragColor = DefaultTheme.backgroundColor2;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> body = <Widget>[
      Expanded(
        flex: 1,
        child: widget.builder(widget.context),
      ),
    ];
    if (widget.action != null) {
      body.add(Expanded(
        flex: 0,
        child: widget.action,
      ));
    }
    List<Widget> content = <Widget>[
      Expanded(
        flex: 0,
        child: Center(
          child: GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            child: Container(
              width: MediaQuery.of(context).size.width - 88,
              height: _dragHeight,
              decoration: BoxDecoration(),
              child: UnconstrainedBox(
                child: Container(
                  width: 80,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    color: _dragColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        key: _contentKey,
        flex: 1,
        child: Container(
          height: _currentHeight,
          child: body.length > 1
              ? Flex(
                  direction: Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: body,
                )
              : widget.builder(widget.context),
        ),
      ),
    ];

    return GestureDetector(
      onVerticalDragUpdate: (details) {},
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Container(
        decoration: BoxDecoration(),
        height: _currentHeight + _dragHeight,
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: content,
        ),
      ),
    );
  }
}
