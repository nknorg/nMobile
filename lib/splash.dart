import 'package:flutter/material.dart';
import 'package:flutter_screenutil/screenutil.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/helpers/global.dart';

class SplashPage extends StatefulWidget {
  static const String routeName = '/SplashPage';

  @override
  State<StatefulWidget> createState() {
    return SplashPageState();
  }
}

class SplashPageState extends State<SplashPage> {
  bool splashTime = false;
  bool initTime = false;

  @override
  void initState() {
    super.initState();

    Global.initData().then((v) {
      Navigator.pushReplacementNamed(context, AppScreen.routeName);
    });
  }

  next() {
    if (splashTime && initTime) {
      Navigator.pushReplacementNamed(context, AppScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 375, height: 812);
    return Material(
      child: Container(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Spacer(),
          ],
        ),
      ),
    );
  }
}
