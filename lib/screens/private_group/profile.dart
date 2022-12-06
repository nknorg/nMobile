import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/private_group/avatar_editable.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/private_group/subscribers.dart';
import 'package:nmobile/utils/asset.dart';
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
  static List<Duration> burnValueArray = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(hours: 12),
    Duration(days: 1),
    Duration(days: 7),
  ];

  static List<String> burnTextArray() {
    return [
      Global.locale((s) => s.burn_5_seconds),
      Global.locale((s) => s.burn_10_seconds),
      Global.locale((s) => s.burn_30_seconds),
      Global.locale((s) => s.burn_1_minute),
      Global.locale((s) => s.burn_5_minutes),
      Global.locale((s) => s.burn_10_minutes),
      Global.locale((s) => s.burn_30_minutes),
      Global.locale((s) => s.burn_1_hour),
      Global.locale((s) => s.burn_6_hour),
      Global.locale((s) => s.burn_12_hour),
      Global.locale((s) => s.burn_1_day),
      Global.locale((s) => s.burn_1_week),
    ];
  }

  static String getStringFromSeconds(int seconds) {
    int currentIndex = -1;
    for (int index = 0; index < burnValueArray.length; index++) {
      Duration duration = burnValueArray[index];
      if (seconds == duration.inSeconds) {
        currentIndex = index;
        break;
      }
    }
    if (currentIndex == -1) {
      return '';
    } else {
      return burnTextArray()[currentIndex];
    }
  }

  StreamSubscription? _updatePrivateGroupSubscription;
  StreamSubscription? _updatePrivateGroupItemSubscription;

  PrivateGroupSchema? _privateGroup;

  bool _isOwner = false;

  bool _initBurnOpen = false;
  int _initBurnProgress = -1;
  bool _burnOpen = false;
  int _burnProgress = -1;

  @override
  void onRefreshArguments() {
    _refreshPrivateGroupSchema();
  }

  @override
  initState() {
    super.initState();
    // listen
    _updatePrivateGroupSubscription = privateGroupCommon.updateGroupStream.where((event) => event.groupId == _privateGroup?.groupId).listen((PrivateGroupSchema event) {
      _initBurning(event);
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
    _updateBurnIfNeed();
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

    _initBurning(this._privateGroup);

    setState(() {});
  }

  _initBurning(PrivateGroupSchema? privateGroup) {
    int? burnAfterSeconds = privateGroup?.options?.deleteAfterSeconds;
    _burnOpen = burnAfterSeconds != null && burnAfterSeconds != 0;
    if (_burnOpen) {
      _burnProgress = burnValueArray.indexWhere((x) => x.inSeconds == burnAfterSeconds);
      if (burnAfterSeconds != null && burnAfterSeconds > burnValueArray.last.inSeconds) {
        _burnProgress = burnValueArray.length - 1;
      }
    }
    if (_burnProgress < 0) _burnProgress = 0;
    _initBurnOpen = _burnOpen;
    _initBurnProgress = _burnProgress;
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

  _updateBurnIfNeed() {
    if (_burnOpen == _initBurnOpen && _burnProgress == _initBurnProgress) return;
    int _burnValue;
    if (!_burnOpen || _burnProgress < 0) {
      _burnValue = 0;
    } else {
      _burnValue = burnValueArray[_burnProgress].inSeconds;
    }
    _privateGroup?.options?.deleteAfterSeconds = _burnValue;
    privateGroupCommon.setOptionsBurning(_privateGroup?.groupId, _burnValue, notify: true); // await
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
    if (Validate.isNknChatIdentifierOk(address)) {
      bool success = await privateGroupCommon.invitee(_privateGroup?.groupId, address, toast: true);
      if (success) Toast.show(Global.locale((s) => s.invite_and_send_success));
    }
  }

  _quit() async {
    ModalDialog.of(Global.appContext).confirm(
      title: Global.locale((s) => s.tip),
      content: Global.locale((s) => s.leave_group_confirm_title),
      agree: Button(
        width: double.infinity,
        text: Global.locale((s) => s.unsubscribe),
        backgroundColor: application.theme.strongColor,
        onPressed: () async {
          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          Loading.show();
          bool success = await privateGroupCommon.quit(_privateGroup?.groupId, toast: true, notify: true);
          Loading.dismiss();
          if (success) Toast.show(Global.locale((s) => s.unsubscribed, ctx: context));
        },
      ),
      reject: Button(
        width: double.infinity,
        text: Global.locale((s) => s.cancel),
        fontColor: application.theme.fontColor2,
        backgroundColor: application.theme.backgroundLightColor,
        onPressed: () {
          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
        },
      ),
    );
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
              crossAxisAlignment: CrossAxisAlignment.start,
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

            /// burn
            TextButton(
              style: _buttonStyle(topRadius: true, botRadius: true, topPad: 15, botPad: 15),
              onPressed: () {
                if (_isOwner) {
                  setState(() {
                    _burnOpen = !_burnOpen;
                  });
                } else {
                  Toast.show(Global.locale((s) => s.only_owner_can_modify, ctx: context));
                }
              },
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Asset.image('contact/xiaohui.png', color: application.theme.primaryColor, width: 24),
                      SizedBox(width: 10),
                      Label(
                        Global.locale((s) => s.burn_after_reading, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      Spacer(),
                      _isOwner
                          ? CupertinoSwitch(
                              value: _burnOpen,
                              activeColor: application.theme.primaryColor,
                              onChanged: (value) {
                                setState(() {
                                  _burnOpen = value;
                                });
                              },
                            )
                          : Label(
                              _burnOpen ? (_burnProgress >= 0 ? burnTextArray()[_burnProgress] : "") : Global.locale((s) => s.close, ctx: context),
                              type: LabelType.bodyRegular,
                              color: application.theme.fontColor2,
                              overflow: TextOverflow.fade,
                              textAlign: TextAlign.right,
                            ),
                    ],
                  ),
                  _isOwner
                      ? ExpansionLayout(
                          isExpanded: _burnOpen,
                          child: Container(
                            padding: EdgeInsets.only(top: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(Icons.alarm_on, size: 24, color: application.theme.primaryColor),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16),
                                        child: Label(
                                          (!_burnOpen || _burnProgress < 0) ? Global.locale((s) => s.off, ctx: context) : getStringFromSeconds(burnValueArray[_burnProgress].inSeconds),
                                          type: LabelType.bodyRegular,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Slider(
                                        value: _burnProgress >= 0 ? _burnProgress.roundToDouble() : 0,
                                        min: 0,
                                        max: (burnValueArray.length - 1).roundToDouble(),
                                        activeColor: application.theme.primaryColor,
                                        inactiveColor: application.theme.fontColor2,
                                        divisions: burnValueArray.length - 1,
                                        label: _burnProgress >= 0 ? burnTextArray()[_burnProgress] : "",
                                        onChanged: (value) {
                                          setState(() {
                                            _burnProgress = value.round();
                                            if (_burnProgress > burnValueArray.length - 1) {
                                              _burnProgress = burnValueArray.length - 1;
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SizedBox.shrink(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 6),
              child: Label(
                (!_burnOpen || _burnProgress < 0)
                    ? Global.locale((s) => s.burn_after_reading_desc, ctx: context)
                    : Global.locale(
                        (s) => s.burn_after_reading_desc_disappear(
                              burnTextArray()[_burnProgress],
                            ),
                        ctx: context),
                type: LabelType.bodySmall,
                fontWeight: FontWeight.w600,
                softWrap: true,
              ),
            ),
            SizedBox(height: 28),

            /// sendMsg
            TextButton(
              style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
              onPressed: () {
                _updateBurnIfNeed();
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

            /// status
            _privateGroup?.joined == true
                ? TextButton(
                    style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
                    onPressed: () {
                      _quit();
                    },
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 10),
                        Label(
                          Global.locale((s) => s.unsubscribe, ctx: context),
                          type: LabelType.bodyRegular,
                          color: Colors.red,
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
