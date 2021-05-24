import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/avatar_editable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class ContactDetailScreen extends StatefulWidget {
  static const String routeName = '/contact/detail';
  static final String argContactSchema = "contact_schema";
  static final String argContactId = "contact_id";

  static Future go(BuildContext context, {ContactSchema schema, int contactId}) {
    logger.d("contact detail - id:$contactId - schema:$schema");
    if (schema == null && (contactId == null || contactId == 0)) return null;
    return Navigator.pushNamed(context, routeName, arguments: {
      argContactSchema: schema,
      argContactId: contactId,
    });
  }

  final Map<String, dynamic> arguments;

  ContactDetailScreen({Key key, this.arguments}) : super(key: key);

  @override
  _ContactDetailScreenState createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
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

  static List<String> burnTextArray(BuildContext context) {
    return [
      S.of(context).burn_5_seconds,
      S.of(context).burn_10_seconds,
      S.of(context).burn_30_seconds,
      S.of(context).burn_1_minute,
      S.of(context).burn_5_minutes,
      S.of(context).burn_10_minutes,
      S.of(context).burn_30_minutes,
      S.of(context).burn_1_hour,
      S.of(context).burn_6_hour,
      S.of(context).burn_12_hour,
      S.of(context).burn_1_day,
      S.of(context).burn_1_week,
    ];
  }

  static String getStringFromSeconds(context, int seconds) {
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
      return burnTextArray(context)[currentIndex];
    }
  }

  ContactSchema _contactSchema;
  WalletSchema _walletSchema;

  StreamSubscription _updateContactSubscription;

  bool _initBurnOpen = false;
  int _initBurnProgress = -1;
  bool _burnOpen = false;
  int _burnProgress = -1;

  bool _notificationOpen = false;

  // FocusNode _firstNameFocusNode = FocusNode();
  // GlobalKey _nameFormKey = new GlobalKey<FormState>();
  // bool _nameFormValid = false;
  // WalletSchema _walletDefault;

  // String nickName;
  // String chatAddress;
  // String walletAddress;

  // static const fcmGapString = '__FCMToken__:';

  // AuthBloc _authBloc;
  // NKNClientBloc _clientBloc;
  // ChatBloc _chatBloc;
  // ContactBloc _contactBloc;

  @override
  initState() {
    super.initState();

    // listen
    _updateContactSubscription = contact.updateStream.listen((List<ContactSchema> list) {
      if (list == null || list.isEmpty) return;
      List result = list.where((element) => (element != null) && (element?.id == _contactSchema?.id)).toList();
      if (result != null && result.isNotEmpty) {
        if (mounted) {
          setState(() {
            _contactSchema = result[0];
          });
        }
      }
    });

    // init
    _refreshContactSchema();
    _refreshDefaultWallet();

    // _authBloc = BlocProvider.of<AuthBloc>(context);
    // _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    // _chatBloc = BlocProvider.of<ChatBloc>(context);
    // _contactBloc = BlocProvider.of<ContactBloc>(context);
    // _clientBloc.aBloc = _authBloc;

    // this.nickName = currentUser.getShowName;
    // this.chatAddress = currentUser.clientAddress;
    // this.walletAddress = currentUser.nknWalletAddress;
  }

  @override
  void dispose() {
    _updateBurnIfNeed();
    super.dispose();
    _updateContactSubscription?.cancel();
  }

  _refreshContactSchema() async {
    ContactSchema contactSchema = widget.arguments[ContactDetailScreen.argContactSchema];
    int contactId = widget.arguments[ContactDetailScreen.argContactId];
    if (contactSchema != null && contactSchema.id != 0) {
      this._contactSchema = contactSchema;
    } else if (contactId != null && contactId != 0) {
      this._contactSchema = await contact.queryContact(contactId);
    }
    if (this._contactSchema == null) return;

    // burn
    int burnAfterSeconds = _contactSchema?.options?.deleteAfterSeconds;
    _burnOpen = burnAfterSeconds != null && burnAfterSeconds != 0;
    if (_burnOpen) {
      _burnProgress = burnValueArray.indexWhere((x) => x.inSeconds == burnAfterSeconds);
      if (burnAfterSeconds > burnValueArray.last.inSeconds) {
        _burnProgress = burnValueArray.length - 1;
      }
    }
    if (_burnProgress < 0) _burnProgress = 0;
    _initBurnOpen = _burnOpen;
    _initBurnProgress = _burnProgress;

    // notification
    if (_contactSchema.isMe == false) {
      if (_contactSchema.notificationOpen != null) {
        _notificationOpen = _contactSchema.notificationOpen;
      } else {
        _notificationOpen = false;
      }
    }
  }

  _refreshDefaultWallet() async {
    _walletSchema = await wallet.getWalletDefault();
    // TODO:GG listen
  }

  _selectAvatarPicture() async {
    String remarkAvatarLocalPath = Path.getLocalContactAvatar(hexEncode(chat.publicKey), "${Uuid().v4()}.jpeg");
    String remarkAvatarPath = join(Global.applicationRootDirectory.path, remarkAvatarLocalPath);
    File picked = await MediaPicker.pick(
      mediaType: MediaType.image,
      source: ImageSource.gallery,
      crop: true,
      returnPath: remarkAvatarPath,
    );
    if (picked == null) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    }

    if (_contactSchema?.type == ContactType.me) {
      await contact.setAvatar(_contactSchema, remarkAvatarLocalPath, notify: true);
    } else {
      await contact.setRemarkAvatar(_contactSchema, remarkAvatarLocalPath, notify: true);
    }
    // _chatBloc.add(RefreshMessageListEvent()); // TODO:GG notify chat
  }

  String _getClientAddress() {
    if (_contactSchema?.clientAddress != null) {
      if (_contactSchema.clientAddress.length > 10) {
        return _contactSchema.clientAddress.substring(0, 10) + '...';
      }
      return _contactSchema.clientAddress;
    }
    return '';
  }

  _modifyNickname(BuildContext context) async {
    S _localizations = S.of(context);
    String newName = await BottomDialog.of(context).showInput(
      title: _localizations.edit_nickname,
      inputTip: _localizations.edit_nickname,
      inputHint: _localizations.input_nickname,
      value: _contactSchema?.getDisplayName,
      actionText: _localizations.save,
      maxLength: 20,
    );
    if (newName == null || newName.trim().isEmpty) return;
    if (_contactSchema?.type == ContactType.me) {
      await contact.setName(_contactSchema, newName.trim(), notify: true);
    } else {
      await contact.setRemarkName(_contactSchema, newName.trim(), notify: true);
    }
    // _chatBloc.add(RefreshMessageListEvent()); // TODO:GG notify chat
  }

  _updateBurnIfNeed() async {
    if (_burnOpen == _initBurnOpen && _burnProgress == _initBurnProgress) return;
    var _burnValue;
    if (!_burnOpen || _burnProgress < 0) {
      _burnValue = null;
    } else {
      _burnValue = burnValueArray[_burnProgress].inSeconds;
    }
    await contact.setOptionsBurn(_contactSchema, _burnValue, notify: true);

    // TODO:GG notify chat
    // var sendMsg = MessageSchema.formSendMessage(
    //   from: NKNClientCaller.currentChatId,
    //   to: currentUser.clientAddress,
    //   contentType: ContentType.eventContactOptions,
    // );
    // sendMsg.burnAfterSeconds = _burnValue;
    // sendMsg.content = sendMsg.toContactBurnOptionData();
    //
    // _chatBloc.add(SendMessageEvent(sendMsg));
  }

  _updateNotificationAndDeviceToken() async {
    // TODO:GG deviceToken get
    // String deviceToken = '';
    // widget.contactInfo.notificationOpen = _notificationOpen;
    // if (_notificationOpen == true) {
    //   deviceToken = await NKNClientCaller.fetchDeviceToken();
    //   if (Platform.isIOS) {
    //     String fcmToken = await NKNClientCaller.fetchFcmToken();
    //     if (fcmToken != null && fcmToken.length > 0) {
    //       deviceToken = deviceToken + "$fcmGapString$fcmToken";
    //     }
    //   }
    //   if (Platform.isAndroid && deviceToken.length == 0) {
    //     showToast(_localizations.unavailable_device);
    //     setState(() {
    //       widget.contactInfo.notificationOpen = false;
    //       _notificationOpen = false;
    //       currentUser.setNotificationOpen(_notificationOpen);
    //     });
    //     return;
    //   }
    // } else {
    //   deviceToken = '';
    //   showToast(_localizations.close);
    // }

    contact.setNotificationOpen(_contactSchema?.id, _notificationOpen, notify: true);

    // TODO:GG notify chat
    // var sendMsg = MessageSchema.formSendMessage(
    //   from: NKNClientCaller.currentChatId,
    //   to: currentUser.clientAddress,
    //   contentType: ContentType.eventContactOptions,
    //   deviceToken: deviceToken,
    // );
    // sendMsg.deviceToken = deviceToken;
    // sendMsg.content = sendMsg.toContactNoticeOptionData();
    // _chatBloc.add(SendMessageEvent(sendMsg));
  }

  _addFriend(BuildContext context) {
    S _localizations = S.of(context);
    contact.setType(_contactSchema?.id, ContactType.friend, notify: true);
    Toast.show(_localizations.success);
  }

  _deleteAction(BuildContext context) {
    S _localizations = S.of(context);

    ModalDialog.of(context).confirm(
      title: _localizations.tip,
      content: _localizations.delete_friend_confirm_title,
      agree: Button(
        text: _localizations.delete_contact,
        backgroundColor: application.theme.strongColor,
        width: double.infinity,
        onPressed: () async {
          contact.delete(_contactSchema?.id);
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
      reject: Button(
        text: _localizations.cancel,
        backgroundColor: application.theme.backgroundLightColor,
        fontColor: application.theme.fontColor2,
        width: double.infinity,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: _contactSchema?.getDisplayName ?? "",
      ),
      body: _contactSchema?.isMe == true
          ? _getSelfView(context)
          : _contactSchema?.isMe == false
              ? _getPersonView(context)
              : SizedBox.shrink(),
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

  _getSelfView(BuildContext context) {
    S _localizations = S.of(context);

    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 32),
            decoration: BoxDecoration(
              color: application.theme.backgroundColor4,
            ),
            child: Center(
              /// avatar
              child: ContactAvatarEditable(
                key: ValueKey(_contactSchema?.getDisplayAvatarPath ?? ""),
                radius: 48,
                contact: _contactSchema,
                placeHolder: false,
                onSelect: _selectAvatarPicture,
              ),
            ),
          ),
          Stack(
            children: [
              Container(
                height: 32,
                decoration: BoxDecoration(color: application.theme.backgroundColor4),
              ),
              Container(
                decoration: BoxDecoration(
                  color: application.theme.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: EdgeInsets.only(left: 16, right: 16, top: 26, bottom: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(
                      _localizations.my_profile,
                      type: LabelType.h3,
                    ),
                    SizedBox(height: 24),

                    /// name
                    TextButton(
                      style: _buttonStyle(topRadius: true, botRadius: false, topPad: 15, botPad: 10),
                      onPressed: () {
                        _modifyNickname(context);
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
                              _contactSchema?.getDisplayName ?? "",
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

                    /// address
                    TextButton(
                      style: _buttonStyle(topRadius: false, botRadius: false, topPad: 12, botPad: 12),
                      onPressed: () {
                        // TODO:GG chat_id detail
                        // Navigator.pushNamed(context, ShowMyChatID.routeName);
                      },
                      child: Row(
                        children: <Widget>[
                          Asset.image('chat/chat-id.png', color: application.theme.primaryColor, width: 24),
                          SizedBox(width: 10),
                          Label(
                            _localizations.d_chat_address,
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Label(
                              _getClientAddress(),
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

                    /// wallet
                    TextButton(
                      style: _buttonStyle(topRadius: false, botRadius: true, topPad: 10, botPad: 15),
                      onPressed: () {
                        // _selectWallets, // TODO:GG
                      },
                      child: Row(
                        children: <Widget>[
                          Asset.iconSvg('wallet', color: application.theme.primaryColor, width: 24),
                          SizedBox(width: 10),
                          Label(
                            _walletSchema?.name ?? "--",
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Label(
                              _localizations.change_default_chat_wallet,
                              type: LabelType.bodyRegular,
                              color: application.theme.primaryColor,
                              overflow: TextOverflow.fade,
                              textAlign: TextAlign.right,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _getPersonView(BuildContext context) {
    S _localizations = S.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 20, bottom: 30, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// avatar
          Center(
            child: ContactAvatarEditable(
              key: ValueKey(_contactSchema?.getDisplayAvatarPath ?? ""),
              radius: 48,
              contact: _contactSchema,
              placeHolder: false,
              onSelect: _selectAvatarPicture,
            ),
          ),
          SizedBox(height: 36),

          Column(
            children: <Widget>[
              /// name
              TextButton(
                style: _buttonStyle(topRadius: true, botRadius: false, topPad: 15, botPad: 10),
                onPressed: () {
                  _modifyNickname(context);
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
                        _contactSchema?.getDisplayName ?? "",
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

              /// address
              TextButton(
                style: _buttonStyle(topRadius: false, botRadius: true, topPad: 10, botPad: 15),
                onPressed: () {
                  // TODO:GG chat_id detail
                  //   Navigator.pushNamed(context, ChatProfile.routeName, arguments: currentUser);
                },
                child: Row(
                  children: <Widget>[
                    Asset.image('chat/chat-id.png', color: application.theme.primaryColor, width: 24),
                    SizedBox(width: 10),
                    Label(
                      _localizations.d_chat_address,
                      type: LabelType.bodyRegular,
                      color: application.theme.fontColor1,
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Label(
                        _getClientAddress(),
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
            ],
          ),
          SizedBox(height: 28),

          /// burn
          TextButton(
            style: _buttonStyle(topRadius: true, botRadius: true, topPad: 8, botPad: 8),
            onPressed: () {
              setState(() {
                _burnOpen = !_burnOpen;
              });
            },
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Asset.image('contact/xiaohui.png', color: application.theme.primaryColor, width: 24),
                    SizedBox(width: 10),
                    Label(
                      _localizations.burn_after_reading,
                      type: LabelType.bodyRegular,
                      color: application.theme.fontColor1,
                    ),
                    Spacer(),
                    CupertinoSwitch(
                      value: _burnOpen,
                      activeColor: application.theme.primaryColor,
                      onChanged: (value) {
                        setState(() {
                          _burnOpen = value;
                        });
                      },
                    ),
                  ],
                ),
                ExpansionLayout(
                  isExpanded: _burnOpen,
                  child: Container(
                    padding: EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(Icons.alarm_on, size: 24, color: application.theme.primaryColor),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Label(
                                  (!_burnOpen || _burnProgress < 0) ? _localizations.off : getStringFromSeconds(context, burnValueArray[_burnProgress].inSeconds),
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
                                label: burnTextArray(context)[_burnProgress],
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 6),
            child: Label(
              (!_burnOpen || _burnProgress < 0)
                  ? _localizations.burn_after_reading_desc
                  : _localizations.burn_after_reading_desc_disappear(
                      burnTextArray(context)[_burnProgress],
                    ),
              type: LabelType.bodySmall,
              fontWeight: FontWeight.w600,
              softWrap: true,
            ),
          ),
          SizedBox(height: 28),

          /// notification
          TextButton(
            style: _buttonStyle(topRadius: true, botRadius: true, topPad: 8, botPad: 8),
            onPressed: () {
              // setState(() {
              //   _notificationOpen = !_notificationOpen;
              //   _updateNotificationAndDeviceToken();
              // });
            },
            child: Row(
              children: <Widget>[
                Asset.iconSvg('notification-bell', color: application.theme.primaryColor, width: 24),
                SizedBox(width: 10),
                Label(
                  _localizations.remote_notification,
                  type: LabelType.bodyRegular,
                  color: application.theme.fontColor1,
                ),
                Spacer(),
                CupertinoSwitch(
                  value: _notificationOpen,
                  activeColor: application.theme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _notificationOpen = value;
                      _updateNotificationAndDeviceToken();
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 20, right: 20),
            child: Label(
              _localizations.accept_notification,
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
              // TODO:GG chat 1_to_1
              // Navigator.of(context).pushNamed(MessageChatPage.routeName, arguments: currentUser);
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
          // SizedBox(height: 28),

          /// AddContact
          _contactSchema?.type == ContactType.stranger
              ? Column(
                  children: [
                    SizedBox(height: 10),
                    TextButton(
                      style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
                      onPressed: () {
                        _addFriend(context);
                      },
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.person_add, color: application.theme.primaryColor),
                          SizedBox(width: 10),
                          Label(
                            _localizations.add_contact,
                            type: LabelType.bodyRegular,
                            color: application.theme.primaryColor,
                          ),
                          Spacer(),
                        ],
                      ),
                    ),
                  ],
                )
              : SizedBox.shrink(),

          /// delete
          _contactSchema?.type == ContactType.friend
              ? Column(
                  children: [
                    SizedBox(height: 28),
                    TextButton(
                      style: _buttonStyle(topRadius: true, botRadius: true, topPad: 12, botPad: 12),
                      onPressed: () {
                        _deleteAction(context);
                      },
                      child: Row(
                        children: <Widget>[
                          Spacer(),
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 10),
                          Label(_localizations.delete, type: LabelType.bodyRegular, color: Colors.red),
                          Spacer(),
                        ],
                      ),
                    ),
                  ],
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

// _selectWallets() {
//   BottomDialog.of(context).showSelectWalletDialog(
//     title: _localizations.select_another_wallet,
//     onlyNkn: true,
//     callback: (wallet) async {
//       Timer(Duration(milliseconds: 30), () {
//         _changeAccount(wallet);
//       });
//     },
//   );
// }

// _changeAccount(WalletSchema wallet) async {
//   if (wallet.address == currentUser.nknWalletAddress) return;
//   var password = await BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NL10ns.of(Global.appContext).verify_wallet_password);
//   if (password != null) {
//     try {
//       var w = await wallet.exportWallet(password);
//       if (w['address'] == wallet.address) {
//         onGetPassword(wallet, password);
//       } else {
//         showToast(_localizations.tip_password_error);
//       }
//     } catch (e) {
//       if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
//         showToast(_localizations.tip_password_error);
//       }
//     }
//   }
// }

// void onGetPassword(WalletSchema wallet, String password) async {
//   EasyLoading.show();
//
//   var eWallet = await wallet.exportWallet(password);
//   // currentUser = await ContactSchema.fetchCurrentUser();
//
//   _clientBloc.add(NKNDisConnectClientEvent());
//   if (currentUser == null) {
//     NLog.w('Current User is____null');
//     DateTime now = DateTime.now();
//     currentUser = ContactSchema(
//       type: ContactType.me,
//       clientAddress: eWallet['publicKey'],
//       nknWalletAddress: eWallet['address'],
//       createdTime: now,
//       updatedTime: now,
//       profileVersion: uuid.v4(),
//     );
//     await currentUser.insertContact();
//   }
//
//   TimerAuth.instance.enableAuth();
//   await LocalStorage().set(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS, eWallet['address']);
//
//   var walletAddress = eWallet['address'];
//   var publicKey = eWallet['publicKey'];
//   Uint8List seedList = Uint8List.fromList(hexDecode(eWallet['seed']));
//   if (seedList != null && seedList.isEmpty) {
//     NLog.w('Wrong!!! seedList.isEmpty');
//   }
//   String _seedKey = hexEncode(sha256(hexEncode(seedList.toList(growable: false))));
//
//   if (NKNClientCaller.currentChatId == null || publicKey == NKNClientCaller.currentChatId || NKNClientCaller.currentChatId.length == 0) {
//     await NKNDataManager.instance.initDataBase(publicKey, _seedKey);
//   } else {
//     await NKNDataManager.instance.changeDatabase(publicKey, _seedKey);
//   }
//   NKNClientCaller.instance.setChatId(publicKey);
//
//   currentUser = await ContactSchema.fetchCurrentUser();
//   setState(() {
//     nickName = currentUser.getShowName;
//     chatAddress = currentUser.clientAddress;
//     walletAddress = currentUser.nknWalletAddress;
//   });
//
//   _authBloc.add(AuthToUserEvent(publicKey, walletAddress));
//   NKNClientCaller.instance.createClient(seedList, null, publicKey);
//
//   Timer(Duration(milliseconds: 200), () async {
//     _contactBloc.add(UpdateUserInfoEvent(currentUser));
//     EasyLoading.dismiss();
//     showToast(_localizations.tip_switch_success);
//   });
// }

}
