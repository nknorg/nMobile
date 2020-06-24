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
          padding: EdgeInsets.only(top: 20.h, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundLightColor,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              children: populars
                  .map((item) => InkWell(
                        onTap: () {
                          Navigator.pop(context, item.topic);
                        },
                        child: PopularItem(
                          data: item,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class PopularItem extends StatelessWidget {
  static final String routeName = "PopularItem";
  final PopularModel data;
  final VoidCallback click;

  PopularItem({Key key, this.data, this.click}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          SizedBox(height: 20.h),
          Container(
            width: 90.w,
            height: 84.h,
            decoration: BoxDecoration(color: data.titleBgColor, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Label(
                data.title,
                type: LabelType.h3,
                color: data.titleColor,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Label(
            data.subTitle,
            type: LabelType.h4,
          ),
        ],
      ),
    );
  }
}
