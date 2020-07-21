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
  double _fontSize = 0;
  double _selectedFontSize = 10;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          ButtonIcon(
            height: 68,
            icon: loadAssetIconsImage(
              'chat',
              color: widget.currentIndex == 0 ? _selectedColor : _color,
            ),
            text: NMobileLocalizations.of(context).menu_chat,
            fontColor: widget.currentIndex == 0 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(0),
          ),
          ButtonIcon(
            height: 68,
            icon: loadAssetIconsImage(
              'wallet',
              color: widget.currentIndex == 1 ? _selectedColor : _color,
            ),
            text: NMobileLocalizations.of(context).menu_wallet,
            fontColor: widget.currentIndex == 1 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(1),
          ),
          ButtonIcon(
            height: 68,
            icon: loadAssetIconsImage(
              'news',
              color: widget.currentIndex == 2 ? _selectedColor : _color,
            ),
            text: NMobileLocalizations.of(context).menu_news,
            fontColor: widget.currentIndex == 2 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(2),
          ),
          ButtonIcon(
            height: 68,
            icon: loadAssetIconsImage(
              'settings',
              color: widget.currentIndex == 3 ? _selectedColor : _color,
            ),
            text: NMobileLocalizations.of(context).menu_settings,
            fontColor: widget.currentIndex == 3 ? _selectedColor : _color,
            onPressed: () => _onItemTapped(3),
          ),
        ],
      ),
    );
  }
}
