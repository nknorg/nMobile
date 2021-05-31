import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/utils/asset.dart';

import '../../generated/l10n.dart';

class Nav extends BaseStateFulWidget {
  PageController controller;
  List<Widget> screens;
  int currentIndex = 0;

  Nav({
    required this.screens,
    required this.controller,
    this.currentIndex = 0,
  });

  @override
  _NavState createState() => new _NavState();
}

class _NavState extends BaseStateFulWidgetState<Nav> {
  var _theme = application.theme;

  @override
  void onRefreshArguments() {
    _theme = application.theme;
  }

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
      currentIndex: widget.currentIndex,
      onTap: _onItemTapped,
      items: [
        BottomNavigationBarItem(
          icon: Asset.iconSvg('chat', color: _color),
          activeIcon: Asset.iconSvg('chat', color: _selectedColor),
          label: _localizations.menu_chat,
        ),
        BottomNavigationBarItem(
          icon: Asset.iconSvg('wallet', color: _color),
          activeIcon: Asset.iconSvg('wallet', color: _selectedColor),
          label: _localizations.menu_wallet,
        ),
        BottomNavigationBarItem(
          icon: Asset.iconSvg('settings', color: _color),
          activeIcon: Asset.iconSvg('settings', color: _selectedColor),
          label: _localizations.menu_settings,
        ),
      ],
    );
  }
}
