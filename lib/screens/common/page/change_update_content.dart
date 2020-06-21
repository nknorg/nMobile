import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class ChangeUpdateContentPage extends StatefulWidget {
  static final String routeName = "ChangeUpdateContentPage";
  final Map arguments;

  const ChangeUpdateContentPage({Key key, this.arguments}) : super(key: key);

  @override
  ChangeUpdateContentPageState createState() => new ChangeUpdateContentPageState();
}

class ChangeUpdateContentPageState extends State<ChangeUpdateContentPage> {
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.arguments['content'];
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.arguments['title'] ?? ''),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            SizedBox(height: 10.h),
            Row(
              children: <Widget>[
                SizedBox(width: 20.w),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 1,
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF2A2A3C)),
                    decoration: InputDecoration(
                        hintText: widget.arguments['hint'] ?? '',
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDFDFE2), width: 0.6.w)),
                        labelStyle: TextStyle(
                          color: Color(0xFFCACACD),
                        ),
                        contentPadding: EdgeInsets.fromLTRB(0, 14.h, 14.w, 14.h)),
                  ),
                ),
                SizedBox(width: 20.w)
              ],
            ),
            SizedBox(height: 20.h),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
              child: Button(
                text: NMobileLocalizations.of(context).save,
                width: double.infinity,
                onPressed: () {
                  Navigator.pop(context, _controller.text);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
