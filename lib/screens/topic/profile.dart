import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/topic/avatar_editable.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/topic/subscribers.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

class TopicProfileScreen extends BaseStateFulWidget {
  static const String routeName = '/topic/profile';
  static final String argTopicSchema = "topic_schema";
  static final String argTopicId = "topic_id";

  static Future go(BuildContext? context, {TopicSchema? schema, String? topicId}) {
    if (context == null) return Future.value(null);
    if (schema == null && (topicId == null || topicId.isEmpty)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argTopicSchema: schema,
      argTopicId: topicId,
    });
  }

  final Map<String, dynamic>? arguments;

  TopicProfileScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _TopicProfileScreenState createState() => _TopicProfileScreenState();
}

class _TopicProfileScreenState extends BaseStateFulWidgetState<TopicProfileScreen> {
  StreamSubscription? _updateTopicSubscription;
  // StreamSubscription? _deleteTopicSubscription;
  StreamSubscription? _onSubscriberAddStreamSubscription;
  StreamSubscription? _onSubscriberUpdateStreamSubscription;

  TopicSchema? _topic;

  bool? _isJoined;

  // bool isPopIng = false;

  @override
  void onRefreshArguments() {
    _refreshTopicSchema();
  }

  @override
  initState() {
    super.initState();
    // listen
    // isPopIng = false;
    _updateTopicSubscription = topicCommon.updateStream.where((event) => event.topicId == _topic?.topicId).listen((TopicSchema event) {
      // if (!event.joined && !isPopIng) {
      //   isPopIng = true;
      //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
      //   return;
      // }
      setState(() {
        _topic = event;
      });
      _refreshJoined(); // await
      // _refreshMembersCount(); // await
    });
    _onSubscriberAddStreamSubscription = subscriberCommon.addStream.where((event) => event.topicId == _topic?.topicId).listen((SubscriberSchema schema) {
      if (schema.contactAddress == clientCommon.address) {
        _refreshJoined();
      }
      // _refreshMembersCount();
    });
    _onSubscriberUpdateStreamSubscription = subscriberCommon.updateStream.where((event) => event.topicId == _topic?.topicId).listen((event) {
      if (event.contactAddress == clientCommon.address) {
        _refreshJoined();
      } else {
        // _refreshMembersCount();
      }
    });

    // _deleteTopicSubscription = topicCommon.deleteStream.where((event) => event == _topicSchema?.topic).listen((String topic) {
    //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    // });
  }

  @override
  void dispose() {
    _updateTopicSubscription?.cancel();
    _onSubscriberAddStreamSubscription?.cancel();
    _onSubscriberUpdateStreamSubscription?.cancel();
    // _deleteTopicSubscription?.cancel();
    super.dispose();
  }

  _refreshTopicSchema({TopicSchema? schema}) async {
    TopicSchema? topicSchema = widget.arguments?[TopicProfileScreen.argTopicSchema];
    String? topicId = widget.arguments?[TopicProfileScreen.argTopicId];
    if (schema != null) {
      this._topic = schema;
    } else if (topicSchema != null) {
      this._topic = topicSchema;
    } else if (topicId?.isNotEmpty == true) {
      this._topic = await topicCommon.query(topicId);
    }
    if (this._topic == null) return;
    setState(() {});

    // exist
    topicCommon.query(this._topic?.topicId).then((TopicSchema? exist) async {
      if (exist != null) return;
      TopicSchema? added = await topicCommon.add(this._topic, notify: true);
      if (added == null) return;
      setState(() {
        this._topic = added;
      });
      // check
      topicCommon.checkExpireAndSubscribe(this._topic?.topicId); // await
    });

    _refreshJoined(); // await
    _refreshMembersCount(); // await
  }

  _refreshJoined() async {
    if (_topic == null || !clientCommon.isClientOK) return;
    bool? isJoined = await topicCommon.isSubscribed(_topic?.topicId, clientCommon.address);
    if ((isJoined == true) && (_topic?.isPrivate == true)) {
      SubscriberSchema? _me = await subscriberCommon.query(_topic?.topicId, clientCommon.address);
      isJoined = _me?.status == SubscriberStatus.Subscribed;
    }
    // do not topic.setJoined because filed is_joined is action not a tag
    if (_isJoined != isJoined) {
      setState(() {
        _isJoined = isJoined;
      });
    }
    if ((isJoined != null) && (isJoined != _topic?.joined)) {
      await topicCommon.setJoined(_topic?.topicId, isJoined, notify: true);
    }
  }

  _refreshMembersCount() async {
    int count = await subscriberCommon.getSubscribersCount(_topic?.topicId, _topic?.isPrivate == true);
    if (_topic?.count != count) {
      await topicCommon.setCount(_topic?.topicId, count, notify: true);
    }
  }

  _selectAvatarPicture() async {
    String remarkAvatarPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: _topic?.topicId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    String? remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
    if (remarkAvatarPath.isEmpty || remarkAvatarLocalPath == null || remarkAvatarLocalPath.isEmpty) return;
    application.inSystemSelecting = true;
    File? picked = await MediaPicker.pickImage(
      cropStyle: CropStyle.rectangle,
      cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      maxSize: Settings.sizeAvatarMax,
      bestSize: Settings.sizeAvatarBest,
      savePath: remarkAvatarPath,
    );
    application.inSystemSelecting = false;
    if (picked == null) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    } else {
      remarkAvatarPath = picked.path;
      remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
    }

    topicCommon.setAvatar(_topic?.topicId, remarkAvatarLocalPath, notify: true); // await
  }

  _invitee() async {
    if (_topic == null) return;
    String? address = await BottomDialog.of(Settings.appContext).showInput(
      title: Settings.locale((s) => s.invite_members),
      inputTip: Settings.locale((s) => s.send_to),
      inputHint: Settings.locale((s) => s.enter_or_select_a_user_pubkey),
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    if (Validate.isNknChatIdentifierOk(address)) {
      double? fee = 0.0;
      if (_topic?.isPrivate == true) {
        fee = await topicCommon.getTopicSubscribeFee(this.context);
        if (fee == null) return;
      }
      await topicCommon.invitee(
        _topic?.topicId,
        _topic?.isPrivate == true,
        _topic?.isOwner(clientCommon.address) == true,
        address,
        fee: fee,
        toast: true,
        sendMsg: true,
      );
    }
  }

  _statusAction(bool nextSubscribe) async {
    if (nextSubscribe) {
      double? fee = await topicCommon.getTopicSubscribeFee(this.context);
      if (fee == null) return;
      Loading.show();
      TopicSchema? result = await topicCommon.subscribe(_topic?.topicId, fee: fee);
      Loading.dismiss();
      if (result != null) Toast.show(Settings.locale((s) => s.subscribed));
    } else {
      ModalDialog.of(Settings.appContext).confirm(
        title: Settings.locale((s) => s.tip),
        content: Settings.locale((s) => s.leave_group_confirm_title),
        agree: Button(
          width: double.infinity,
          text: Settings.locale((s) => s.unsubscribe),
          backgroundColor: application.theme.strongColor,
          onPressed: () async {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            double? fee = await topicCommon.getTopicSubscribeFee(this.context);
            if (fee == null) return;
            Loading.show();
            TopicSchema? deleted = await topicCommon.unsubscribe(_topic?.topicId, fee: fee, toast: true);
            Loading.dismiss();
            if (deleted != null) {
              Toast.show(Settings.locale((s) => s.unsubscribed));
              // if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            }
          },
        ),
        reject: Button(
          width: double.infinity,
          text: Settings.locale((s) => s.cancel),
          fontColor: application.theme.fontColor2,
          backgroundColor: application.theme.backgroundLightColor,
          onPressed: () {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: Settings.locale((s) => s.channel_settings, ctx: context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20, bottom: 30, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// avatar
            Center(
              child: _topic != null
                  ? TopicAvatarEditable(
                      radius: 48,
                      topic: _topic!,
                      placeHolder: false,
                      onSelect: _selectAvatarPicture,
                    )
                  : SizedBox.shrink(),
            ),
            SizedBox(height: 36),

            Column(
              children: <Widget>[
                /// name
                TextButton(
                  style: _buttonStyle(topRadius: true, botRadius: false, topPad: 15, botPad: 10),
                  onPressed: () {
                    Util.copyText(_topic?.topicId);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.iconSvg('user', color: application.theme.primaryColor, width: 24),
                      SizedBox(width: 10),
                      Label(
                        Settings.locale((s) => s.nickname, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          _topic?.topicId ?? "",
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor2,
                          overflow: TextOverflow.fade,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Asset.iconSvg(
                        'right',
                        width: 24,
                        color: application.theme.fontColor2,
                      ),
                    ],
                  ),
                ),

                /// count
                TextButton(
                  style: _buttonStyle(topRadius: false, botRadius: false, topPad: 12, botPad: 12),
                  onPressed: () {
                    TopicSubscribersScreen.go(context, schema: _topic);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.image('chat/group-blue.png', width: 24),
                      SizedBox(width: 10),
                      Label(
                        Settings.locale((s) => s.view_channel_members, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          "${_topic?.count ?? "--"} ${Settings.locale((s) => s.members, ctx: context)}",
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor2,
                          overflow: TextOverflow.fade,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Asset.iconSvg(
                        'right',
                        width: 24,
                        color: application.theme.fontColor2,
                      ),
                    ],
                  ),
                ),

                /// invitee
                TextButton(
                  style: _buttonStyle(topRadius: false, botRadius: true, topPad: 10, botPad: 15),
                  onPressed: () {
                    _invitee();
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.image('chat/invisit-blue.png', width: 24),
                      SizedBox(width: 10),
                      Label(
                        Settings.locale((s) => s.invite_members, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Spacer(),
                      Asset.iconSvg(
                        'right',
                        width: 24,
                        color: application.theme.fontColor2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            /// sendMsg
            TextButton(
              style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
              onPressed: () {
                ChatMessagesScreen.go(this.context, _topic);
              },
              child: Row(
                children: <Widget>[
                  Asset.iconSvg('chat', color: application.theme.primaryColor, width: 24),
                  SizedBox(width: 10),
                  Label(
                    Settings.locale((s) => s.send_message, ctx: context),
                    type: LabelType.bodyRegular,
                    color: application.theme.fontColor1,
                  ),
                  Spacer(),
                  Asset.iconSvg(
                    'right',
                    width: 24,
                    color: application.theme.fontColor2,
                  ),
                ],
              ),
            ),
            SizedBox(height: 28),

            /// status
            _isJoined != null
                ? TextButton(
                    style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
                    onPressed: () {
                      _statusAction(!(_isJoined!));
                    },
                    child: Row(
                      children: <Widget>[
                        Icon(
                          (_isJoined ?? false) ? Icons.exit_to_app : Icons.person_add,
                          color: (_isJoined ?? false) ? Colors.red : application.theme.primaryColor,
                        ),
                        SizedBox(width: 10),
                        Label(
                          (_isJoined ?? false) ? Settings.locale((s) => s.unsubscribe, ctx: context) : Settings.locale((s) => s.subscribe, ctx: context),
                          type: LabelType.bodyRegular,
                          color: (_isJoined ?? false) ? Colors.red : application.theme.primaryColor,
                        ),
                        Spacer(),
                      ],
                    ),
                  )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  _buttonStyle({bool topRadius = true, bool botRadius = true, double topPad = 12, double botPad = 12}) {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((state) => application.theme.backgroundLightColor),
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16, top: topPad, bottom: botPad)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: topRadius ? Radius.circular(12) : Radius.zero,
            bottom: botRadius ? Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
