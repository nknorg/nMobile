import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/avatar_editable.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class TopicProfileScreen extends BaseStateFulWidget {
  static const String routeName = '/topic/profile';
  static final String argTopicSchema = "topic_schema";
  static final String argTopicId = "topic_id";

  static Future go(BuildContext context, {TopicSchema? schema, int? topicId}) {
    logger.d("TopicProfileScreen - go - id:$topicId - schema:$schema");
    if (schema == null && (topicId == null || topicId == 0)) return Future.value(null);
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
  TopicSchema? _topicSchema;

  StreamSubscription? _updateTopicSubscription;

  @override
  void onRefreshArguments() {
    _refreshTopicSchema();
  }

  @override
  initState() {
    super.initState();
    // listen
    _updateTopicSubscription = topicCommon.updateStream.where((event) => event.id == _topicSchema?.id).listen((TopicSchema event) {
      setState(() {
        _topicSchema = event;
      });
    });
  }

  @override
  void dispose() {
    _updateTopicSubscription?.cancel();
    super.dispose();
  }

  _refreshTopicSchema({TopicSchema? schema}) async {
    TopicSchema? topicSchema = widget.arguments![TopicProfileScreen.argTopicSchema];
    int? topicId = widget.arguments![TopicProfileScreen.argTopicId];
    if (schema != null) {
      this._topicSchema = schema;
    } else if (topicSchema != null && topicSchema.id != 0) {
      this._topicSchema = topicSchema;
    } else if (topicId != null && topicId != 0) {
      this._topicSchema = await topicCommon.query(topicId);
    }
    if (this._topicSchema == null) return;
    setState(() {});
  }

  _selectAvatarPicture() async {
    if (clientCommon.publicKey == null) return;
    String remarkAvatarLocalPath = Path.createLocalFile(hexEncode(clientCommon.publicKey!), SubDirType.topic, "${Uuid().v4()}.jpeg");
    String? remarkAvatarPath = Path.getCompleteFile(remarkAvatarLocalPath);
    File? picked = await MediaPicker.pick(
      mediaType: MediaType.image,
      source: ImageSource.gallery,
      cropStyle: CropStyle.rectangle,
      cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 50,
      returnPath: remarkAvatarPath,
    );
    if (picked == null) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    }

    await topicCommon.setAvatar(_topicSchema?.id, remarkAvatarLocalPath, notify: true);
  }

  _deleteAction() {
    S _localizations = S.of(this.context);

    ModalDialog.of(this.context).confirm(
      title: _localizations.tip,
      content: _localizations.delete_friend_confirm_title,
      agree: Button(
        text: _localizations.unsubscribe,
        backgroundColor: application.theme.strongColor,
        width: double.infinity,
        onPressed: () async {
          topicCommon.delete(_topicSchema?.id, notify: true);
          Navigator.pop(this.context);
          Navigator.pop(this.context);
        },
      ),
      reject: Button(
        text: _localizations.cancel,
        backgroundColor: application.theme.backgroundLightColor,
        fontColor: application.theme.fontColor2,
        width: double.infinity,
        onPressed: () => Navigator.pop(this.context),
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

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(this.context);

    int membersCount = 0; // TODO:GG topic count
    bool isJoined = _topicSchema?.joined == true; // TODO:GG topic joined

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: _localizations.channel_settings,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20, bottom: 30, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// avatar
            Center(
              child: _topicSchema != null
                  ? TopicAvatarEditable(
                      radius: 48,
                      topic: _topicSchema!,
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
                    copyText(_topicSchema?.fullName, context: context);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.iconSvg('user', color: application.theme.primaryColor, width: 24),
                      SizedBox(width: 10),
                      Label(
                        _localizations.nickname,
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          _topicSchema?.fullName ?? "",
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
                  style: _buttonStyle(topRadius: false, botRadius: false, topPad: 10, botPad: 10),
                  onPressed: () {
                    // TODO:GG subscriber screen
                    // Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: widget.arguments);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.image('chat/group-blue.png', width: 24),
                      SizedBox(width: 10),
                      Label(
                        _localizations.view_channel_members,
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          "$membersCount${_localizations.members}",
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
                    // TODO:GG invitee
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.image('chat/invisit-blue.png', width: 24),
                      SizedBox(width: 10),
                      Label(
                        _localizations.invite_members,
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
                ChatMessagesScreen.go(this.context, _topicSchema);
              },
              child: Row(
                children: <Widget>[
                  Asset.iconSvg('chat', color: application.theme.primaryColor, width: 24),
                  SizedBox(width: 10),
                  Label(
                    _localizations.send_message,
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
            TextButton(
              style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
              onPressed: () {
                _deleteAction();
              },
              child: Row(
                children: <Widget>[
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 10),
                  Label(_localizations.delete, type: LabelType.bodyRegular, color: Colors.red),
                  Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
