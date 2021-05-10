import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';

// TODO:GG adapt height or scroll
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
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          child: this,
        );
      },
    );
  }

  Future<T> showWithTitle<T>({
    @required Widget child,
    @required String title,
    Widget action,
    String desc = "",
    double height = 300,
  }) {
    return show<T>(
      height: height,
      action: action,
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
