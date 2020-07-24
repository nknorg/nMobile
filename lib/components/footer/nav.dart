import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/components/ButtonIcon.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/image_utils.dart';

class Nav extends StatefulWidget {
  PageController controller;
  List<Widget> screens;
  int currentIndex = 0;

  Nav({
    this.screens,
    this.controller,
    this.currentIndex,
  });

  @override
  _NavState createState() => new _NavState();
}

class _NavState extends State<Nav> {
  void _onItemTapped(int index) {
    setState(() {
      widget.currentIndex = index;
      widget.controller.jumpToPage(index);
      Global.currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color _color = Theme.of(context).unselectedWidgetColor;
    Color _selectedColor = DefaultTheme.primaryColor;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: DefaultTheme.backgroundColor2)],
        color: DefaultTheme.backgroundLightColor,
        border: Border(top: BorderSide(color: DefaultTheme.backgroundColor2)),
//        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          ButtonIcon(
            icon: loadAssetIconsImage('chat', color: widget.currentIndex == 0 ? _selectedColor : _color),
            text: NMobileLocalizations.of(context).menu_chat,
            height: 60,
            fontColor: widget.currentIndex == 0 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(0),
          ),
          ButtonIcon(
            icon: loadAssetIconsImage('wallet', color: widget.currentIndex == 1 ? _selectedColor : _color),
            text: NMobileLocalizations.of(context).menu_wallet,
            height: 60,
            fontColor: widget.currentIndex == 1 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(1),
          ),
          ButtonIcon(
            icon: loadAssetIconsImage('settings', color: widget.currentIndex == 2 ? _selectedColor : _color),
            text: NMobileLocalizations.of(context).menu_settings,
            height: 60,
            fontColor: widget.currentIndex == 2 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(2),
          ),
        ],
      ),
    );
  }
}
