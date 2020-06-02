import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/popular_model.dart';

class PopularGroupPage extends StatefulWidget {
  static final String routeName = "PopularGroupPage";

  @override
  PopularGroupPageState createState() => new PopularGroupPageState();
}

class PopularGroupPageState extends State<PopularGroupPage> {
  List<PopularModel> populars;

  @override
  void initState() {
    super.initState();
    LogUtil.v('onCreate', tag: 'PopularGroupPage');
    populars = PopularModel.defaultData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NMobileLocalizations.of(context).popular_channels,
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 20.h, left: 10.w, right: 10.w),
          color: DefaultTheme.backgroundLightColor,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: <Widget>[
                GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: List.generate(
                      populars.length,
                      (index) {
                        PopularModel model = populars[index];
                        return Column(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 60.h),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: model.titleBgColor),
                              child: Center(
                                child: Label(
                                  model.title,
                                  type: LabelType.h3,
                                  color: model.titleColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
