import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/utils/asset.dart';

class SelectListItem {
  final String text;
  final dynamic value;

  SelectListItem({this.text, this.value});
}

// ignore: must_be_immutable
class SelectScreen extends StatefulWidget {
  static const String routeName = '/select';
  final Map arguments;
  BuildContext context;

  static final String title = "title";
  static final String list = "list";
  static final String selectedValue = "selectedValue";

  SelectScreen({Key key, this.arguments}) : super(key: key);

  @override
  _SelectScreenState createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  String title;
  String selectedValue;
  List<SelectListItem> list;

  @override
  void initState() {
    super.initState();
    this.title = widget.arguments['title'];
    this.list = widget.arguments['list'];
    this.selectedValue = widget.arguments['selectedValue'].toString();
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: title,
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
        child: Flex(
          direction: Axis.vertical,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(
                child: ListView.separated(
                  itemBuilder: (BuildContext context, int index) {
                    SelectListItem item = list[index];
                    List<Widget> itemChild = <Widget>[
                      Label(
                        item.text,
                        type: LabelType.bodyRegular,
                        height: 1,
                        fontWeight: FontWeight.bold,
                        color: application.theme.fontColor1,
                      ),
                    ];
                    if (item.value.toString() == selectedValue.toString()) {
                      itemChild.add(
                        Asset.iconSvg(
                          'check2',
                          width: 24,
                          color: application.theme.primaryColor,
                        ),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: application.theme.backgroundLightColor,
                        borderRadius: BorderRadius.vertical(top: index == 0 ? Radius.circular(12) : Radius.zero, bottom: index == list.length - 1 ? Radius.circular(12) : Radius.zero),
                      ),
                      child: TextButton(
                        style: ButtonStyle(
                          padding: MaterialStateProperty.resolveWith((states) => const EdgeInsets.only(left: 16, right: 16)),
                          shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: index == 0 ? Radius.circular(12) : Radius.zero, bottom: index == list.length - 1 ? Radius.circular(12) : Radius.zero))),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(item.value);
                        },
                        child: SizedBox(
                          height: 56,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: itemChild,
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Divider(
                      height: 0,
                      color: application.theme.backgroundColor2,
                    );
                  },
                  itemCount: list.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  searchAction(String val) {
    if (val.length == 0) {
      setState(() {
        this.list = widget.arguments['list'];
      });
    } else {
      List<SelectListItem> data = widget.arguments['list'];
      setState(() {
        this.list = data.where((item) => item.text.contains(val)).toList();
      });
    }
  }
}
