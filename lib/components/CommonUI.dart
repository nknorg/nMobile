import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/entity/topic_repo.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ColorValue {
  /// Thin, the least thick
  static const Color dividerColor = Color(0xFFF5F5F5);
  static const Color darkTextColor = Color(0xFF333333);
  static const Color greyTextColor = Color(0xFF666666);
  static const Color lightGreyColor = Color(0xFF999999);
  static const Color orangeMainColor = Color(0xFFFF8300);

  static const List bgColorList = [
    0xFF4DAFBE,
    0xFF7CBC85,
    0xFFEAAA9D,
    0xFF7CBC85,
    0xFF95217A,
    0xFF3D8962,
    0xFFE59F54,
    0xFFB36E28,
    0xFFDF826F,
    0xFFEDB379
  ];
  static const List textColorList = [
    0xFE5775A,
    0xFFE59578,
    0xFF3D8962,
    0xFFBB7FAA,
    0xFFF9F351,
    0xFFA42126,
    0xFF4B70AE,
    0xFF234881,
    0xFF3D8962,
    0xFF7688BD
  ];

  static Color generaterColor(int tag) {
    tag = tag % 30;
    if (tag == 1) {
      return Color(0xFFFFFFCC);
    }
    if (tag == 2) {
      return Color(0xFFCCFFFF);
    }
    if (tag == 3) {
      return Color(0xFFFFCCCC);
    }
    if (tag == 4) {
      return Color(0xFFCCCCFF);
    }
    if (tag == 5) {
      return Color(0xFFE3AC55);
    }
    if (tag == 6) {
      return Color(0xFF008B8B);
    }
    if (tag == 7) {
      return Color(0xFFFFDEAD);
    }
    if (tag == 8) {
      return Color(0xFFDAA520);
    }
    if (tag == 9) {
      return Color(0xFFDEB887);
    }
    if (tag == 10) {
      return Color(0xFFCD5C5C);
    }
    if (tag == 11) {
      return Color(0xFF57AF84);
    }
    if (tag == 12) {
      return Color(0xFFBF91B6);
    }
    return Color(0xFFF0A4F1);
  }
}

class CommonUI {
  factory CommonUI() => _getInstance();
  static CommonUI get instance => _getInstance();
  static CommonUI _instance;
  CommonUI._internal() {
    // init
  }

  static CommonUI _getInstance() {
    if (_instance == null) {
      _instance = new CommonUI._internal();
    }
    return _instance;
  }

  static Widget avatarWidget({
    ContactSchema contact,
    Topic topic,
    // File avatar,
    double radiusSize,
    // int themeId,
    // String name,
  }) {
    File avatarFile;
    int themeId;
    String name;
    Color fColor;

    /// = Color(ColorValue.textColorList[themeId%10]);
    Color bColor;

    /// = Color(ColorValue.bgColorList[themeId%10]);
    if (contact != null) {
      avatarFile = File(contact.getShowAvatarPath);
      if (contact.getShowName != null) {
        name = contact.getShowName;
      }
      if (contact.options != null &&
          contact.options.color != null &&
          contact.options.backgroundColor != null) {
        if (contact.options.backgroundColor != null) {
          themeId = contact.options.backgroundColor;
        }
        fColor = Color(contact.options.color);
        bColor = Color(contact.options.backgroundColor);
      } else {
        int random =
            Random().nextInt(DefaultTheme.headerBackgroundColor.length);
        int backgroundColor = DefaultTheme.headerBackgroundColor[random];
        int color = DefaultTheme.headerColor[random];
        fColor = Color(color);
        bColor = Color(backgroundColor);
        contact.setOptionColor();
      }
    } else if (topic != null) {
      if (topic.avatarUri != null) {
        avatarFile = File(topic.avatarUri);
      }
      if (topic.topicName != null) {
        name = topic.topicName;
      }
      if (topic.options != null) {
        if (topic.options.backgroundColor != null &&
            topic.options.color != null &&
            topic.options.backgroundColor != null) {
          themeId = topic.options.backgroundColor;
        } else if (topic.themeId != null) {
          themeId = topic.themeId;
        }
        fColor = Color(topic.options.color);
        bColor = Color(topic.options.backgroundColor);
      }
    } else {
      name = '';
      return Container();
    }

    if (avatarFile != null && avatarFile.path.length > 0) {
      return CircleAvatar(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3, right: 1),
          ),
        ),
        radius: radiusSize,
        backgroundImage: FileImage(avatarFile),
      );
    }

    if (themeId == null) {
      themeId = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    }

    return CircleAvatar(
      radius: radiusSize,
      backgroundColor: bColor,
      child: Label(
        name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
        type: LabelType.bodyLarge,
        color: fColor,
      ),
    );
  }

  static showToast(String msg) {
    Fluttertoast.showToast(
        msg: "This is Center Short Toast",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  static Widget sectionTitle(String title) {
    return Container(
      height: 52,
      color: ColorValue.dividerColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: 15, top: 19),
            width: 3,
            height: 15,
            color: ColorValue.orangeMainColor,
          ),
          Container(
            margin: EdgeInsets.only(left: 5, top: 15, bottom: 15),
            child: Text(
              "$title",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ColorValue.darkTextColor,
                fontSize: 17,
              ),
            ),
          )
        ],
      ),
    );
  }

  static showAlertMessage(BuildContext context, String contentString) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Container(
                child: Text(NL10ns.of(context).tip),
                alignment: Alignment.center,
              ),
              content: Text(('$contentString')),
              actions: <Widget>[
                FlatButton(
                  child: new Text(NL10ns.of(context).ok),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ));
  }

  static showAlertFunctionMessage(
      BuildContext context, String contentString, Function call()) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Container(
                child: Text(NL10ns.of(context).tip),
                alignment: Alignment.center,
              ),
              content: Text(('$contentString')),
              actions: <Widget>[
                FlatButton(
                  child: new Text(NL10ns.of(context).ok),
                  onPressed: () {
                    Navigator.of(context).pop();
                    call();
                  },
                ),
              ],
            ));
  }

  static showChooseAlert(BuildContext context, String title, String content,
      String sureName, String cancelName, Function call) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Container(
                child: Text('$title'),
                alignment: Alignment.center,
              ),
              content: Container(
                child: Text(
                  ('$content'),
                  textAlign: TextAlign.center,
                ),
              ),
              actions: <Widget>[
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 120,
                      margin: EdgeInsets.only(left: 15, right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.white,
                        border: Border.all(color: Color(0xFFD1D1D1), width: 1),
                      ),
                      child: RaisedButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        color: Colors.transparent,
                        elevation: 0,
                        highlightElevation: 0,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          height: 40,
                          child: Text(
                            "$cancelName",
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 120,
                      margin: EdgeInsets.only(right: 15, left: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFFF7746), Color(0xFFFEB02F)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: RaisedButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.transparent,
                        elevation: 0,
                        highlightElevation: 0,
                        onPressed: call,
                        child: Container(
                          alignment: Alignment.center,
                          height: 40,
                          child: Text(
                            "$sureName",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ));
  }

  static Widget customSureButton(
      String buttonName, Function call, double height) {
    return Container(
      height: height,
      child: FlatButton(
        child: Text(
          "$buttonName",
          style: TextStyle(
            color: Color(0xFFFF9800),
            fontSize: 12,
          ),
        ),
        onPressed: call,
      ),
      decoration: new BoxDecoration(
        color: Colors.white,
        //设置四周圆角 角度
        borderRadius: BorderRadius.all(Radius.circular(22.5)),
        //设置四周边框
        border: new Border.all(width: .5, color: Color(0xFFFEB02F)),
      ),
    );
  }

  static Widget errorView(BuildContext context, String errorMsg) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
        height: height,
        width: width,
        child: Column(
          children: [
            Spacer(),
            Container(
              margin: EdgeInsets.only(
                  left: (width - 250) / 2,
                  bottom: 20,
                  right: (width - 250) / 2),
              child: Image.asset("images/icon_nodata.png",
                  width: 250, height: 170),
            ),
            Container(
              child: Text(
                "$errorMsg",
                style: TextStyle(
                  fontSize: 16,
                  color: ColorValue.lightGreyColor,
                ),
              ),
            ),
            Spacer(),
          ],
        ));
  }

  static double calculateTextHeight(String value, double fontSize,
      FontWeight fontWeight, double maxWidth, int maxLines) {
    TextPainter painter = TextPainter(
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: fontWeight,
              fontSize: fontSize,
            )));
    painter.layout(maxWidth: maxWidth);

    ///get text Width :painter.width
    return painter.height;
  }
}
