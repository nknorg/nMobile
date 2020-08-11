import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class NewHeaderPage {
  static getHeader(context) {
    return Header(
      titleChild: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Label(
          NL10ns.of(context).menu_news.toUpperCase(),
          type: LabelType.h2,
        ),
      ),
      hasBack: false,
      backgroundColor: DefaultTheme.primaryColor,
      leading: null,
      action: IconButton(
        icon: SvgPicture.asset(
          'assets/icons/news_share.svg',
          color: DefaultTheme.backgroundLightColor,
          width: 18.w,
        ),
        onPressed: () {},
      ),
    );
  }
}
