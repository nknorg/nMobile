import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BottomDialog extends BaseStateFulWidget {
  @override
  _BottomDialogState createState() => _BottomDialogState();

  BuildContext context;

  BottomDialog.of(this.context);

  WidgetBuilder? builder;
  Widget? action;
  double? height;
  Function? updateHeight;

  close({BuildContext? ctx, result}) {
    if (Navigator.of(ctx ?? this.context).canPop()) Navigator.of(this.context).pop(result);
  }

  Future<T?> show<T>({
    required WidgetBuilder builder,
    Widget? action,
    double? height,
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

  Future<T?> showWithTitle<T>({
    Widget? child,
    String? title,
    Widget? action,
    String? desc = "",
    double? height = 300,
  }) {
    return show<T>(
      height: height,
      action: action,
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
              child: Label(
                title ?? "",
                type: LabelType.h2,
                maxLines: 10,
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
              child: child ?? SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> showWalletTypeSelect({
    String? title,
    String? desc,
    Widget? action,
  }) {
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
                  WalletAvatar(
                    width: 48,
                    height: 48,
                    walletType: WalletType.nkn,
                    padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
                    ethBig: true,
                  ),
                  Expanded(
                    child: Label(
                      Global.locale((s) => s.nkn_mainnet, ctx: context),
                      type: LabelType.h3,
                    ),
                  ),
                  Column(
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
                          Global.locale((s) => s.mainnet, ctx: context),
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
                ],
              ),
            ),
            onTap: () {
              close(ctx: context, result: walletTypeNkn);
            },
          ),
          Divider(height: 1, indent: 64),
          InkWell(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  WalletAvatar(
                    width: 48,
                    height: 48,
                    walletType: WalletType.eth,
                    padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
                    ethBig: true,
                  ),
                  Expanded(
                    child: Label(
                      Global.locale((s) => s.ethereum, ctx: context),
                      type: LabelType.h3,
                    ),
                  ),
                  Column(
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
                          Global.locale((s) => s.ERC_20, ctx: context),
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
                ],
              ),
            ),
            onTap: () {
              close(ctx: context, result: walletTypeEth);
            },
          ),
          Divider(height: 1, indent: 64),
        ],
      ),
    );
  }

  Future<WalletSchema?> showWalletSelect({
    String? title,
    String? desc,
    Widget? action,
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
            List<WalletSchema> wallets = onlyNKN ? state.wallets.where((w) => w.type == WalletType.nkn).toList() : state.wallets;
            return ListView.builder(
              itemCount: wallets.length,
              itemBuilder: (BuildContext context, int index) {
                if (index < 0 || index >= wallets.length) return SizedBox.shrink();
                WalletSchema wallet = wallets[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WalletItem(
                      walletType: wallet.type,
                      wallet: wallet,
                      bgColor: application.theme.backgroundLightColor,
                      radius: BorderRadius.circular(0),
                      onTap: () {
                        close(ctx: context, result: wallet);
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

  Future<String?> showInput({
    String? title,
    String? desc,
    String? inputTip,
    String? inputHint,
    String? value,
    FormFieldValidator<String>? validator,
    String? actionText,
    bool password = false,
    double height = 300,
    int maxLength = 10000,
    bool enable = true,
    bool contactSelect = false,
  }) async {
    TextEditingController _inputController = TextEditingController();
    _inputController.text = value ?? "";

    return showWithTitle<String>(
      title: title,
      desc: desc,
      height: height,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: actionText ?? Global.locale((s) => s.continue_text, ctx: context),
          width: double.infinity,
          onPressed: () {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, _inputController.text);
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
              controller: _inputController,
              hintText: inputHint ?? "",
              validator: validator,
              password: password,
              maxLength: maxLength,
              enabled: enable,
              suffixIcon: contactSelect
                  ? GestureDetector(
                      onTap: () async {
                        if (clientCommon.status == ClientConnectStatus.connected) {
                          var contact = await ContactHomeScreen.go(context, isSelect: true);
                          if (contact != null && contact is ContactSchema) {
                            _inputController.text = contact.clientAddress;
                          }
                        } else {
                          Toast.show(Global.locale((s) => s.d_chat_not_login, ctx: context));
                        }
                      },
                      child: Container(
                        width: 20,
                        alignment: Alignment.centerRight,
                        child: Icon(FontAwesomeIcons.solidAddressBook),
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  showQrcode({
    String? title,
    String? desc,
    required String data,
  }) {
    return showWithTitle<String>(
      title: title,
      desc: desc,
      height: 530,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: Global.locale((s) => s.close, ctx: context),
          width: double.infinity,
          backgroundColor: application.theme.primaryColor.withAlpha(20),
          fontColor: application.theme.primaryColor,
          onPressed: () {
            close(ctx: context);
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

  Future<double?> showTransactionSpeedUp({double? fee}) async {
    TextEditingController _inputController = TextEditingController();

    fee = fee ?? double.tryParse((await SettingsStorage.getSettings(SettingsStorage.DEFAULT_FEE)) ?? "0") ?? 0;
    if (fee <= 0) fee = Global.topicSubscribeFeeDefault;
    _inputController.text = fee.toStringAsFixed(8);

    return showWithTitle<double>(
      title: Global.locale((s) => s.transfer_speed_up_enable, ctx: context),
      desc: Global.locale((s) => s.transfer_speed_up_desc, ctx: context),
      height: 350,
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Button(
                text: Global.locale((s) => s.accelerate_no, ctx: context),
                // width: double.infinity,
                onPressed: () {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, 0.0);
                },
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: Button(
                text: Global.locale((s) => s.accelerate, ctx: context),
                width: double.infinity,
                backgroundColor: application.theme.strongColor,
                onPressed: () {
                  double fee = _inputController.text.isNotEmpty ? (double.tryParse(_inputController.text) ?? 0) : 0;
                  if (fee <= 0) fee = 0;
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, fee);
                },
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                Label(
                  Global.locale((s) => s.pay_nkn, ctx: context),
                  type: LabelType.h4,
                  textAlign: TextAlign.start,
                ),
                SizedBox(width: 20),
                Expanded(
                  child: FormText(
                    controller: _inputController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(Validate.regWalletAmount)],
                    textAlign: TextAlign.start,
                    hintText: Global.locale((s) => s.enter_amount, ctx: context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomDialogState extends BaseStateFulWidgetState<BottomDialog> with SingleTickerProviderStateMixin {
  double _dy = 0;
  double _height = 300;
  double _dragHeight = 24;
  late double _currentHeight;
  late double _minHeight;
  double _maxHeight = 686;
  double _tweenHeight = 0;
  double _minFlingVelocity = 700;
  late AnimationController _animationController;
  Color _dragColor = application.theme.backgroundColor2;
  GlobalKey _contentKey = GlobalKey();

  @override
  void onRefreshArguments() {
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

  void _handleDragUpdate(DragUpdateDetails details) {
    _dy = details.globalPosition.dy;

    setState(() {
      _currentHeight = Global.screenHeight() - _dy;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dy > _minFlingVelocity) {
      if (_currentHeight < _minHeight) {
        widget.close(ctx: context);
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
    _maxHeight = Global.screenHeight() - 86 - 38;

    List<Widget> body = <Widget>[
      Expanded(
        child: widget.builder?.call(widget.context) ?? SizedBox.shrink(),
      ),
    ];

    if (widget.action != null) {
      body.add(widget.action!);
    }

    List<Widget> content = <Widget>[
      Center(
        child: GestureDetector(
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleDragEnd,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
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
      Expanded(
        key: _contentKey,
        child: Container(
          height: _currentHeight,
          child: body.length > 1
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: body,
                )
              : widget.builder?.call(widget.context) ?? SizedBox.shrink(),
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
