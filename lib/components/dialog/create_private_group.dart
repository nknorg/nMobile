import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/theme/theme.dart';

class CreatePrivateGroup extends BaseStateFulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends BaseStateFulWidgetState<CreatePrivateGroup> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _topicController = TextEditingController();

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
  }

  Future<bool> createPrivateGroup(String? groupName) async {
    if (groupName == null || groupName.isEmpty) return false;
    if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);

    Loading.show();
    PrivateGroupSchema? privateGroupSchema = await privateGroupCommon.createPrivateGroup(groupName);
    if (privateGroupSchema != null) {
      // TODO:GG PG check
      await chatOutCommon.sendPrivateGroupSubscribe(privateGroupSchema.groupId);
      ChatMessagesScreen.go(Global.appContext, privateGroupSchema.groupId);
    }
    Loading.dismiss();

    return true;
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: () {
        _formValid = (_formKey.currentState as FormState).validate();
      },
      child: Flex(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(width: 20),
                    Label(
                      Global.locale((s) => s.name),
                      type: LabelType.bodyRegular,
                      color: _theme.fontColor1,
                      textAlign: TextAlign.start,
                    ),
                    Spacer(),
                    SizedBox(width: 20),
                  ],
                ),
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: FormText(
                          controller: _topicController,
                          hintText: Global.locale((s) => s.input_name),
                          validator: Validator.of(context).required(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 18),
                child: Button(
                  width: double.infinity,
                  text: Global.locale((s) => s.continue_text),
                  onPressed: () {
                    if (_formValid) createPrivateGroup(_topicController.text);
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
