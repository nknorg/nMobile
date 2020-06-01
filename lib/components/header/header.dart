import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/extensions.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget titleChild;
  final Color backgroundColor;
  final Widget action;
  final Widget leading;
  bool hasBack;
  bool isWalletPage;
  bool isNotBackedUp;

  Header(
      {this.title,
      this.titleChild,
      this.backgroundColor,
      this.action,
      this.leading,
      this.hasBack = true,
      this.isWalletPage = false,
      this.isNotBackedUp = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: hasBack,
      backgroundColor: backgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: leading,
      title: Row(
        children: <Widget>[
          (titleChild != null
                  ? titleChild
                  : Text(
                      title ?? '',
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: DefaultTheme.labelFontSize),
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      maxLines: 1,
                    ))
              .padding(4.pal()),
          notBackedUp(context)
        ],
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: action,
        ),
      ],
      elevation: 0,
    );
  }

  Widget notBackedUp(BuildContext context) {
    final label = Label(
      NMobileLocalizations.of(context).not_backed_up,
      type: LabelType.h4,
    ).padding(4.pal().par(4));
    return isWalletPage && isNotBackedUp ? label : label.offstage(true);
  }

  @override
  Size get preferredSize => Size.fromHeight(60);
}
