import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/assets.dart';
import '../../generated/l10n.dart';

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
  var _theme = application.theme;

  void _onItemTapped(int index) {
    setState(() {
      widget.currentIndex = index;
      widget.controller.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    Color _color = Theme.of(context).unselectedWidgetColor;
    Color _selectedColor = _theme.primaryColor;
    return BottomNavigationBar(
      backgroundColor: _theme.navBackgroundColor,
      currentIndex: widget.currentIndex,
      type: BottomNavigationBarType.fixed,
      unselectedItemColor: _theme.fontColor2,
      selectedItemColor: _theme.primaryColor,
      onTap: _onItemTapped,
      items: [
        BottomNavigationBarItem(
          icon: assetIcon('chat', color: _color),
          activeIcon: assetIcon('chat', color: _selectedColor),
          label: _localizations.menu_home,
        ),
        BottomNavigationBarItem(
          icon: assetIcon('wallet', color: _color),
          activeIcon: assetIcon('wallet', color: _selectedColor),
          label: _localizations.menu_wallet,
        ),
        BottomNavigationBarItem(
          icon: assetIcon('settings', color: _color),
          activeIcon: assetIcon('settings', color: _selectedColor),
          label: _localizations.menu_settings,
        ),
      ],
    );
  }
}
