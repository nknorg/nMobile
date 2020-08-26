import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/model/popular_channel.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class CreateGroupDialog extends StatefulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> with AccountDependsBloc {
  ChatBloc _chatBloc;
  TextEditingController _topicController = TextEditingController();
  TextEditingController _feeController = TextEditingController();
  FocusNode _feeToFocusNode = FocusNode();
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  bool _showFeeLayout = false;
  double _fee = 0;
  double _sliderFee = 0.1;
  double _sliderFeeMin = 0;
  double _sliderFeeMax = 10;
  bool _loading = false;
  bool _privateSelected = false;

  @override
  void initState() {
    super.initState();
    _feeController.text = _fee.toString();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        child: Form(
          key: _formKey,
          autovalidate: true,
          onChanged: () {
            _formValid = (_formKey.currentState as FormState).validate();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 14),
                child: Label(
                  NL10ns.of(context).create_channel,
                  type: LabelType.h3,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Label(
                          NL10ns.of(context).name,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1,
                          textAlign: TextAlign.start,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              NL10ns.of(context).private_channel,
                              type: LabelType.bodyRegular,
                              color: DefaultTheme.fontColor1,
                            ),
                            CupertinoSwitch(
                              value: _privateSelected,
                              activeColor: DefaultTheme.primaryColor,
                              onChanged: (value) async {
                                setState(() {
                                  _privateSelected = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Textbox(
                            controller: _topicController,
                            validator: Validator.of(context).required(),
                            hintText: NL10ns.of(context).input_name,
                          ),
                        ),
//                        SizedBox(width: 10),
//                        Container(
//                          child: InkWell(
//                            child: loadAssetChatPng('group_blue', width: 24),
//                            onTap: () {
//                              Navigator.pushNamed(context, PopularGroupPage.routeName).then((v) {
//                                if (v != null) {
//                                  _topicController.text = v;
//                                }
//                              });
//                            },
//                          ),
//                        )
                      ],
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showFeeLayout = !_showFeeLayout;
                                });
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Label(
                                    NL10ns.of(context).advanced,
                                    type: LabelType.bodyRegular,
                                    color: DefaultTheme.fontColor1,
                                    textAlign: TextAlign.start,
                                  ),
                                  RotatedBox(
                                    quarterTurns: _showFeeLayout ? 2 : 0,
                                    child: loadAssetIconsImage('down', color: DefaultTheme.primaryColor, width: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ExpansionLayout(
                    isExpanded: _showFeeLayout,
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Label(
                                      NL10ns.of(context).fee,
                                      type: LabelType.bodyRegular,
                                      color: DefaultTheme.fontColor1,
                                      textAlign: TextAlign.start,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Textbox(
                                    controller: _feeController,
                                    focusNode: _feeToFocusNode,
                                    padding: const EdgeInsets.only(bottom: 0),
                                    onSaved: (v) => _fee = double.parse(v ?? 0),
                                    onChanged: (v) {
                                      setState(() {
                                        double fee = v.isNotEmpty ? double.parse(v) : 0;
                                        if (fee > _sliderFeeMax) {
                                          fee = _sliderFeeMax;
                                        } else if (fee < _sliderFeeMin) {
                                          fee = _sliderFeeMin;
                                        }
                                        _sliderFee = fee;
                                      });
                                    },
                                    suffixIcon: GestureDetector(
                                      onTap: () {},
                                      child: Container(
                                        width: 20,
                                        alignment: Alignment.centerRight,
                                        child: Label(
                                          NL10ns.of(context).nkn,
                                          type: LabelType.label,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8, top: 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  NL10ns.of(context).slow,
                                  type: LabelType.bodySmall,
                                  color: DefaultTheme.primaryColor,
                                ),
                                Label(
                                  NL10ns.of(context).average,
                                  type: LabelType.bodySmall,
                                  color: DefaultTheme.primaryColor,
                                ),
                                Label(
                                  NL10ns.of(context).fast,
                                  type: LabelType.bodySmall,
                                  color: DefaultTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 6, top: 0),
                            child: Slider(
                              value: _sliderFee,
                              onChanged: (v) {
                                setState(() {
                                  _sliderFee = _fee = v;
                                  _feeController.text = _fee.toStringAsFixed(2);
                                });
                              },
                              max: _sliderFeeMax,
                              min: _sliderFeeMin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 16, top: 16),
                    child: Label(
                      NL10ns.of(context).popular_channels,
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              getPopularView(),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 10),
                child: Button(
                  text: NL10ns.of(context).continue_text,
                  width: double.infinity,
                  disabled: _loading,
                  onPressed: () async {
                    if (_formValid) {
                      createOrJoinGroup(_topicController.text);
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  getPopularView() {
    List<Widget> list = [];
    for (PopularChannel item in PopularChannel.defaultData()) {
      list.add(InkWell(
        onTap: () async {
          createOrJoinGroup(item.topic);
        },
        child: Container(
          height: 40.h,
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 40.h,
                width: 40.w,
                decoration: BoxDecoration(color: item.titleBgColor, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Label(
                    item.title,
                    type: LabelType.h4,
                    color: item.titleColor,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      height: 40,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Label(
                            item.topic,
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Label(
                            item.desc,
                            height: 1,
                            type: LabelType.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/chat.svg',
                width: 24,
                color: DefaultTheme.primaryColor,
              ),
            ],
          ),
        ),
      ));
    }
    return Container(
      height: 200.h,
      child: SingleChildScrollView(
        child: Column(
          children: list,
        ),
      ),
    );
  }

  createOrJoinGroup(topicName) async {
    if (isEmpty(topicName)) {
      return;
    }
    if (_privateSelected) {
      if (!isPrivateTopic(topicName)) {
        topicName = '$topicName.$accountPubkey';
      }
    }
    final topicRepo = TopicRepo(db);
    var group = await topicRepo.getTopicByName(topicName);
    if (group == null) {
      setState(() {
        _loading = true;
      });
      EasyLoading.show();
      await GroupChatHelper.subscribeTopic(
          account: account,
          topicName: topicName,
          chatBloc: _chatBloc,
          callback: (success, e) async {
            if (success) {
              final topicSpotName = Topic.spotName(name: topicName);
              if (topicSpotName.isPrivate) {
                // TODO: delay pull action at least 3 minutes.
                GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                    client: account.client,
                    topicName: topicName,
                    accountPubkey: accountPubkey,
                    myChatId: accountChatId,
                    repoSub: SubscriberRepo(db),
                    repoBlackL: BlackListRepo(db),
                    repoTopic: TopicRepo(db),
                    membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                    needUploadMetaCallback: (topicName) {
                      GroupChatPrivateChannel.uploadPermissionMeta(
                        client: account.client,
                        topicName: topicName,
                        accountPubkey: accountPubkey,
                        repoSub: SubscriberRepo(db),
                        repoBlackL: BlackListRepo(db),
                      );
                    });
              } else {
                GroupChatPublicChannel.pullSubscribersPublicChannel(
                  client: account.client,
                  topicName: topicName,
                  myChatId: accountChatId,
                  repoSub: SubscriberRepo(db),
                  repoTopic: TopicRepo(db),
                  membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                );
              }
              // see below.
            } else {
              // see below.
            }
          });
      EasyLoading.dismiss();
      setState(() {
        _loading = false;
      });
    }
    group = await topicRepo.getTopicByName(topicName);
    if (group == null) {
      showToast(NL10ns.of(context).something_went_wrong);
    } else {
      Navigator.of(context).pushReplacementNamed(
        ChatGroupPage.routeName,
        arguments: ChatSchema(
          type: group.isPrivate ? ChatType.PrivateChannel : ChatType.Channel,
          topic: group,
        ),
      );
    }
  }
}
