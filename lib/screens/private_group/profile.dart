import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/private_group/avatar_editable.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/private_group/subscribers.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

class PrivateGroupProfileScreen extends BaseStateFulWidget {
  static const String routeName = '/privateGroup/profile';
  static final String argPrivateGroupSchema = "privateGroupSchema";
  static final String argPrivateGroupId = "groupId";

  static Future go(BuildContext? context, {PrivateGroupSchema? schema, String? groupId}) {
    if (context == null) return Future.value(null);
    if ((schema == null) && (groupId == null)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argPrivateGroupSchema: schema,
      argPrivateGroupId: groupId,
    });
  }

  final Map<String, dynamic>? arguments;

  PrivateGroupProfileScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _PrivateGroupProfileScreenState createState() => _PrivateGroupProfileScreenState();
}

class _PrivateGroupProfileScreenState extends BaseStateFulWidgetState<PrivateGroupProfileScreen> {
  StreamSubscription? _updatePrivateGroupSubscription;
  StreamSubscription? _updatePrivateGroupItemSubscription;

  PrivateGroupSchema? _privateGroup;

  bool _isOwner = false;

  @override
  void onRefreshArguments() {
    _refreshPrivateGroupSchema();
  }

  @override
  initState() {
    super.initState();
    // listen
    _updatePrivateGroupSubscription = privateGroupCommon.updateGroupStream.where((event) => event.groupId == _privateGroup?.groupId).listen((PrivateGroupSchema event) {
      setState(() {
        _privateGroup = event;
        _isOwner = privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.getPublicKey());
      });
    });
    _updatePrivateGroupItemSubscription = privateGroupCommon.updateGroupItemStream.where((event) => event.groupId == _privateGroup?.groupId).listen((PrivateGroupItemSchema event) {
      // nothing
    });
  }

  @override
  void dispose() {
    _updatePrivateGroupSubscription?.cancel();
    _updatePrivateGroupItemSubscription?.cancel();
    super.dispose();
  }

  _refreshPrivateGroupSchema({PrivateGroupSchema? schema}) async {
    PrivateGroupSchema? privateGroupSchema = widget.arguments?[PrivateGroupProfileScreen.argPrivateGroupSchema];
    String? groupId = widget.arguments?[PrivateGroupProfileScreen.argPrivateGroupId];
    if (schema != null) {
      this._privateGroup = schema;
    } else if (privateGroupSchema != null && privateGroupSchema.id != 0) {
      this._privateGroup = privateGroupSchema;
    } else if (groupId != null) {
      this._privateGroup = await privateGroupCommon.queryGroup(groupId);
    }
    if (this._privateGroup == null) return;
    _isOwner = privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.getPublicKey());

    setState(() {});
  }

  _selectAvatarPicture() async {
    String remarkAvatarPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: _privateGroup?.groupId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    String? remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
    if (remarkAvatarPath.isEmpty || remarkAvatarLocalPath == null || remarkAvatarLocalPath.isEmpty) return;
    File? picked = await MediaPicker.pickImage(
      cropStyle: CropStyle.rectangle,
      cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      bestSize: MessageSchema.avatarBestSize,
      maxSize: MessageSchema.avatarMaxSize,
      savePath: remarkAvatarPath,
    );
    if (picked == null) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    } else {
      remarkAvatarPath = picked.path;
      remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
    }

    privateGroupCommon.updateGroupAvatar(_privateGroup?.groupId, remarkAvatarLocalPath, notify: true); // await
  }

  _invitee() async {
    if (_privateGroup == null) return;
    String? address = await BottomDialog.of(Global.appContext).showInput(
      title: Global.locale((s) => s.invite_members),
      inputTip: Global.locale((s) => s.send_to),
      inputHint: Global.locale((s) => s.enter_or_select_a_user_pubkey),
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    if (address?.isNotEmpty == true) {
      bool success = await privateGroupCommon.invitee(_privateGroup?.groupId, address, toast: true);
      if (success) Toast.show(Global.locale((s) => s.invite_and_send_success));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: Global.locale((s) => s.channel_settings, ctx: context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20, bottom: 30, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// avatar
            Center(
              child: _privateGroup != null
                  ? PrivateGroupSchemaEditable(
                      radius: 48,
                      privateGroup: _privateGroup!,
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
                    Util.copyText(_privateGroup?.name);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.iconSvg('user', color: application.theme.primaryColor, width: 24),
                      SizedBox(width: 10),
                      Label(
                        Global.locale((s) => s.nickname, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          _privateGroup?.name ?? "",
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
                    PrivateGroupSubscribersScreen.go(context, schema: _privateGroup);
                  },
                  child: Row(
                    children: <Widget>[
                      Asset.image('chat/group-blue.png', width: 24),
                      SizedBox(width: 10),
                      Label(
                        Global.locale((s) => s.view_channel_members, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          "${_privateGroup?.count ?? "--"} ${Global.locale((s) => s.members, ctx: context)}",
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
                _isOwner
                    ? TextButton(
                        style: _buttonStyle(topRadius: false, botRadius: true, topPad: 10, botPad: 15),
                        onPressed: () {
                          _invitee();
                        },
                        child: Row(
                          children: <Widget>[
                            Asset.image('chat/invisit-blue.png', width: 24),
                            SizedBox(width: 10),
                            Label(
                              Global.locale((s) => s.invite_members, ctx: context),
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
                      )
                    : SizedBox.shrink(),
              ],
            ),
            SizedBox(height: 20),

            /// sendMsg
            TextButton(
              style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
              onPressed: () {
                ChatMessagesScreen.go(this.context, _privateGroup);
              },
              child: Row(
                children: <Widget>[
                  Asset.iconSvg('chat', color: application.theme.primaryColor, width: 24),
                  SizedBox(width: 10),
                  Label(
                    Global.locale((s) => s.send_message, ctx: context),
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
