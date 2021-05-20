import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
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

  close({result}) {
    Navigator.of(context).pop(result);
  }

  Future<T> show<T>({
    @required WidgetBuilder builder,
    Widget action,
    double height,
    bool animated = true,
  }) {
    this.builder = builder;
    this.action = action;
    this.height = height;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      backgroundColor: application.theme.backgroundLightColor,
      builder: (BuildContext context) {
        return animated
            ? AnimatedPadding(
                padding: MediaQuery.of(context).viewInsets,
                duration: const Duration(milliseconds: 100),
                child: this,
              )
            : this;
      },
    );
  }

  Future<T> showWithTitle<T>({
    @required Widget child,
    @required String title,
    Widget action,
    String desc = "",
    double height = 300,
    bool animated = true,
  }) {
    return show<T>(
      height: height,
      action: action,
      animated: animated,
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
              child: Label(
                title,
                type: LabelType.h2,
              ),
            ),
            Builder(builder: (BuildContext context) {
              if (desc == null || desc.isEmpty) {
                return SizedBox(height: 12);
              }
              return Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 12),
                child: Label(
                  desc,
                  type: LabelType.bodyLarge,
                  maxLines: 10,
                ),
              );
            }),
            Expanded(
              flex: 1,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Future<String> showWalletTypeSelect({
    @required String title,
    String desc,
    Widget action,
  }) {
    S _localizations = S.of(context);
    final walletTypeNkn = WalletType.nkn;
    final walletTypeEth = WalletType.eth;

    return showWithTitle<String>(
      title: title,
      desc: desc,
      action: action,
      height: 330,
      child: Column(
        children: [
          InkWell(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 0,
                    child: WalletAvatar(
                      width: 48,
                      height: 48,
                      walletType: WalletType.nkn,
                      padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
                      ethBig: true,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Label(
                      _localizations.nkn_mainnet,
                      type: LabelType.h3,
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(9)),
                            color: application.theme.successColor.withAlpha(25),
                          ),
                          child: Text(
                            _localizations.mainnet,
                            style: TextStyle(
                              color: application.theme.successColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            onTap: () {
              close(result: walletTypeNkn);
            },
          ),
          Divider(height: 1, indent: 64),
          InkWell(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 0,
                    child: WalletAvatar(
                      width: 48,
                      height: 48,
                      walletType: WalletType.eth,
                      padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
                      ethBig: true,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Label(
                      _localizations.ethereum,
                      type: LabelType.h3,
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(9)),
                            color: application.theme.ethLogoBackground.withAlpha(25),
                          ),
                          child: Text(
                            _localizations.ERC_20,
                            style: TextStyle(
                              color: application.theme.ethLogoBackground,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            onTap: () {
              close(result: walletTypeEth);
            },
          ),
          Divider(height: 1, indent: 64),
        ],
      ),
    );
  }

  Future<WalletSchema> showWalletSelect({
    @required String title,
    String desc,
    Widget action,
    bool onlyNKN = false,
  }) {
    return showWithTitle<WalletSchema>(
      title: title,
      desc: desc,
      action: action,
      height: 330,
      child: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoaded) {
            final wallets = onlyNKN ? state.wallets.where((w) => w.type == WalletType.nkn).toList() : state.wallets;
            return ListView.builder(
              itemCount: wallets?.length ?? 0,
              itemBuilder: (BuildContext context, int index) {
                WalletSchema wallet = wallets[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WalletItem(
                      walletType: wallet?.type,
                      wallet: wallet,
                      bgColor: application.theme.backgroundLightColor,
                      radius: BorderRadius.circular(0),
                      onTap: () {
                        close(result: wallet);
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 84,
                      endIndent: 20,
                    ),
                  ],
                );
              },
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  Future<String> showInput({
    @required String title,
    String desc,
    String inputTip,
    String inputHint,
    String actionText,
    bool password = false,
    int maxLength = 10000,
  }) async {
    S _localizations = S.of(context);
    TextEditingController _passwordController = TextEditingController();

    return showWithTitle<String>(
      title: title,
      desc: desc,
      height: 300,
      animated: false,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: actionText ?? _localizations.continue_text,
          width: double.infinity,
          onPressed: () {
            Navigator.pop(context, _passwordController.text);
          },
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Label(
              inputTip ?? "",
              type: LabelType.h4,
              textAlign: TextAlign.start,
            ),
            FormText(
              controller: _passwordController,
              hintText: inputHint ?? "",
              validator: Validator.of(context).password(),
              password: password,
              maxLength: maxLength,
            ),
          ],
        ),
      ),
    );
  }

  showQrcode({@required String title, String desc, String data}) {
    S _localizations = S.of(context);

    return showWithTitle<String>(
      title: title,
      desc: desc,
      height: 530,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: _localizations.close,
          width: double.infinity,
          backgroundColor: application.theme.primaryColor.withAlpha(20),
          fontColor: application.theme.primaryColor,
          onPressed: () {
            close();
          },
        ),
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Center(
          child: QrImage(
            data: data,
            version: QrVersions.auto,
            size: 240.0,
          ),
        ),
      ),
    );
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
  Color _dragColor = application.theme.backgroundColor2;
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
      _dragColor = application.theme.backgroundColor2;
    });
  }

  void _handleDragDown(DragDownDetails details) {
    setState(() {
      _dragColor = application.theme.backgroundColor2;
    });
  }

  void _handleDragCancel() {
    setState(() {
      _dragColor = application.theme.backgroundColor2;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _dragColor = application.theme.backgroundColor3;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _dragColor = application.theme.backgroundColor2;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maxHeight = MediaQuery.of(context).size.height - 86 - 38;

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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // logger.i("---> ${constraints}");
                return Container(
                  width: constraints.maxWidth - 32 * 2,
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
                );
              },
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
        height: _currentHeight + _dragHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content,
        ),
      ),
    );
  }
}
