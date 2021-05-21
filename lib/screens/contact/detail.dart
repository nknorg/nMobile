import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/contact/avatar_editable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
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
  ContactSchema _contactSchema;

  StreamSubscription _updateContactSubscription;

  // TextEditingController _firstNameController = TextEditingController();
  // TextEditingController _notesController = TextEditingController();
  // FocusNode _firstNameFocusNode = FocusNode();
  // GlobalKey _nameFormKey = new GlobalKey<FormState>();
  // GlobalKey _notesFormKey = new GlobalKey<FormState>();
  // bool _nameFormValid = false;
  // bool _notesFormValid = false;
  // bool _burnSelected = false;
  // bool _initBurnSelected = false;
  // int _burnIndex = -1;
  // int _initBurnIndex = -1;
  // WalletSchema _walletDefault;
  //
  // bool _acceptNotification = false;
  //
  // String nickName;
  // String chatAddress;
  // String walletAddress;
  //
  // static const fcmGapString = '__FCMToken__:';

  // AuthBloc _authBloc;
  // NKNClientBloc _clientBloc;
  // ChatBloc _chatBloc;
  // ContactBloc _contactBloc;

  @override
  initState() {
    super.initState();

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

    _refreshContactSchema();

    // _authBloc = BlocProvider.of<AuthBloc>(context);
    // _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    // _chatBloc = BlocProvider.of<ChatBloc>(context);
    // _contactBloc = BlocProvider.of<ContactBloc>(context);
    // _clientBloc.aBloc = _authBloc;

    // int burnAfterSeconds = currentUser?.options?.deleteAfterSeconds;
    //
    // if (currentUser.isMe == false) {
    //   _acceptNotification = false;
    //   if (currentUser.notificationOpen != null) {
    //     _acceptNotification = currentUser.notificationOpen;
    //   }
    // }
    //
    // _burnSelected = burnAfterSeconds != null;
    // if (_burnSelected) {
    //   _burnIndex = BurnViewUtil.burnValueArray.indexWhere((x) => x.inSeconds == burnAfterSeconds);
    //   if (burnAfterSeconds > BurnViewUtil.burnValueArray.last.inSeconds) {
    //     _burnIndex = BurnViewUtil.burnValueArray.length - 1;
    //   }
    // }
    // if (_burnIndex < 0) _burnIndex = 0;
    // _initBurnSelected = _burnSelected;
    // _initBurnIndex = _burnIndex;
    //
    // this.nickName = currentUser.getShowName;
    //
    // this.chatAddress = currentUser.clientAddress;
    // this.walletAddress = currentUser.nknWalletAddress;
    //
    // _notesController.text = currentUser.notes;
  }

  @override
  void dispose() {
    super.dispose();
    _updateContactSubscription?.cancel();
    // _saveAndSendBurnMessage();
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
  }

  _refreshSettings() {}

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

    await contact.setRemarkAvatar(_contactSchema, remarkAvatarLocalPath, notify: true);
    // TODO:GG
    // _updateUserInfo(null, savedImg);
  }

  String _clientAddress() {
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
    await contact.setRemarkName(_contactSchema, newName.trim(), notify: true);
    // TODO:GG
    // _updateUserInfo(nName, null);
    // _chatBloc.add(RefreshMessageListEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: _contactSchema?.getDisplayName ?? "",
        // TODO:GG
        // leading: BackButton(
        //   onPressed: () {
        //     _popWithInformation();
        //   },
        // ),
      ),
      body: _contactSchema?.isMe == true
          ? SizedBox.shrink() // TODO:GG getSelfView
          : _contactSchema?.isMe == false
              ? _getPersonView(context)
              : SizedBox.shrink(),
    );
  }

  _getPersonView(BuildContext context) {
    S _localizations = S.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 20, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// avatar
          Center(
            child: ContactAvatarEditable(
              radius: 48,
              contact: _contactSchema,
              placeHolder: false,
              onSelect: _selectAvatarPicture,
            ),
          ),
          SizedBox(height: 36),

          /// name + address
          Container(
            decoration: BoxDecoration(
              color: application.theme.backgroundLightColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.all(0),
            margin: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.only(left: 16, right: 16, top: 15, bottom: 10)),
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12)))),
                  ),
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
                        height: 1,
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
                      )
                    ],
                  ),
                ),
                TextButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 15)),
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)))),
                  ),
                  onPressed: () {
                    // TODO:GG
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
                        height: 1,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Label(
                          _clientAddress(),
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
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
//           Container(
//             decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
//             margin: EdgeInsets.only(left: 16, right: 16, top: 10),
//             child: FlatButton(
//               onPressed: () async {
//                 setState(() {
//                   _burnSelected = !_burnSelected;
//                 });
//               },
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
//               child: Container(
//                 width: double.infinity,
//                 padding: _burnSelected ? 0.symm(v: 5.5) : 0.pad(),
//                 child: Column(
//                   mainAxisAlignment: _burnSelected ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
//                   children: <Widget>[
//                     Row(
//                       children: [
//                         loadAssetWalletImage('xiaohui', color: DefaultTheme.primaryColor, width: 24),
//                         SizedBox(width: 10),
//                         Label(
//                           NL10ns.of(context).burn_after_reading,
//                           type: LabelType.bodyRegular,
//                           color: DefaultTheme.fontColor1,
//                           textAlign: TextAlign.start,
//                         ),
//                         Spacer(),
//                         CupertinoSwitch(
//                           value: _burnSelected,
//                           activeColor: DefaultTheme.primaryColor,
//                           onChanged: (value) {
//                             setState(() {
//                               _burnSelected = value;
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                     _burnSelected
//                         ? Row(
//                             mainAxisSize: MainAxisSize.max,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Icon(Icons.alarm_on, size: 24, color: Colours.blue_0f).pad(r: 10),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Label(
//                                       (!_burnSelected || _burnIndex < 0) ? NL10ns.of(context).off : BurnViewUtil.getStringFromSeconds(context, BurnViewUtil.burnValueArray[_burnIndex].inSeconds),
//                                       type: LabelType.bodyRegular,
//                                       color: Colours.gray_81,
//                                       fontWeight: FontWeight.w700,
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                     Slider(
//                                       value: _burnIndex.d,
//                                       min: 0,
//                                       max: (BurnViewUtil.burnValueArray.length - 1).d,
//                                       activeColor: Colours.blue_0f,
//                                       inactiveColor: Colours.gray_81,
//                                       divisions: BurnViewUtil.burnValueArray.length - 1,
//                                       label: BurnViewUtil.burnTextArray(context)[_burnIndex],
//                                       onChanged: (value) {
//                                         setState(() {
//                                           _burnIndex = value.round();
//                                           if (_burnIndex > BurnViewUtil.burnValueArray.length - 1) {
//                                             _burnIndex = BurnViewUtil.burnValueArray.length - 1;
//                                           }
//                                         });
//                                       },
//                                     )
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           )
//                         : Space.empty,
//                   ],
//                 ),
//               ),
//             ).sized(h: _burnSelected ? 112 : 50, w: double.infinity),
//           ),
//           Label(
//             (!_burnSelected || _burnIndex < 0)
//                 ? NL10ns.of(context).burn_after_reading_desc
//                 : NL10ns.of(context).burn_after_reading_desc_disappear(
//                     BurnViewUtil.burnTextArray(context)[_burnIndex],
//                   ),
//             type: LabelType.bodySmall,
//             color: Colours.gray_81,
//             fontWeight: FontWeight.w600,
//             softWrap: true,
//           ).pad(t: 6, b: 8, l: 20, r: 20),
//           Container(
//             decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
//             margin: EdgeInsets.only(left: 16, right: 16, top: 10),
//             child: FlatButton(
//               onPressed: () async {
//                 // setState(() {
//                 //   _acceptNotification = !_acceptNotification;
//                 //   NLog.w('oNChanged 11111111'+_acceptNotification.toString());
//                 //   _saveAndSendDeviceToken();
//                 // });
//               },
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
//               child: Container(
//                 width: double.infinity,
//                 padding: _acceptNotification ? 0.symm(v: 5.5) : 0.pad(),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: <Widget>[
//                     Row(
//                       children: [
//                         loadAssetIconsImage('notification_bell', color: DefaultTheme.primaryColor, width: 24),
//                         SizedBox(width: 10),
//                         Label(
//                           NL10ns.of(context).remote_notification,
//                           type: LabelType.bodyRegular,
//                           color: DefaultTheme.fontColor1,
//                           textAlign: TextAlign.start,
//                         ),
//                         Spacer(),
//                         CupertinoSwitch(
//                           value: _acceptNotification,
//                           activeColor: DefaultTheme.primaryColor,
//                           onChanged: (value) {
//                             setState(() {
//                               _acceptNotification = value;
//                               _saveAndSendDeviceToken();
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ).sized(h: 50, w: double.infinity),
//           ),
//           Label(
//             // (_acceptNotification)
//             //     ? NL10ns.of(context).setting_accept_notification
//             //     : NL10ns.of(context).setting_deny_notification,
//             NL10ns.of(context).accept_notification,
//             type: LabelType.bodySmall,
//             color: Colours.gray_81,
//             fontWeight: FontWeight.w600,
//             softWrap: true,
//           ).pad(t: 6, b: 8, l: 20, r: 20),
//           Container(
//             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
//             margin: EdgeInsets.only(left: 16, right: 16, top: 10),
//             child: FlatButton(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
//               child: Container(
//                 width: double.infinity,
//                 child: Row(
//                   children: <Widget>[
//                     SvgPicture.asset('assets/icons/chat.svg', width: 24, color: DefaultTheme.primaryColor),
// //                                      loadAssetChatPng('send_message', width: 22),
//                     SizedBox(width: 10),
//                     Label(NL10ns.of(context).send_message, type: LabelType.bodyRegular, color: DefaultTheme.fontColor1),
//                     Spacer(),
//                     SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
//                   ],
//                 ),
//               ),
//               onPressed: () {
//                 Navigator.of(context).pushNamed(MessageChatPage.routeName, arguments: currentUser);
//               },
//             ).sized(h: 50, w: double.infinity),
//           ),
          // getStatusView(), // TODO:GG
        ],
      ),
    );
  }

// _saveAndSendBurnMessage() async {
//   if (_burnSelected == _initBurnSelected && _burnIndex == _initBurnIndex) return;
//   var _burnValue;
//   if (!_burnSelected || _burnIndex < 0) {
//     await currentUser.setBurnOptions(null);
//   } else {
//     _burnValue = BurnViewUtil.burnValueArray[_burnIndex].inSeconds;
//     await currentUser.setBurnOptions(_burnValue);
//   }
//   var sendMsg = MessageSchema.formSendMessage(
//     from: NKNClientCaller.currentChatId,
//     to: currentUser.clientAddress,
//     contentType: ContentType.eventContactOptions,
//   );
//   sendMsg.burnAfterSeconds = _burnValue;
//   sendMsg.content = sendMsg.toContactBurnOptionData();
//
//   _chatBloc.add(SendMessageEvent(sendMsg));
// }

// _saveAndSendDeviceToken() async {
//   String deviceToken = '';
//   widget.contactInfo.notificationOpen = _acceptNotification;
//   if (_acceptNotification == true) {
//     deviceToken = await NKNClientCaller.fetchDeviceToken();
//     if (Platform.isIOS) {
//       String fcmToken = await NKNClientCaller.fetchFcmToken();
//       if (fcmToken != null && fcmToken.length > 0) {
//         deviceToken = deviceToken + "$fcmGapString$fcmToken";
//       }
//     }
//     if (Platform.isAndroid && deviceToken.length == 0) {
//       showToast(NL10ns.of(context).unavailable_device);
//       setState(() {
//         widget.contactInfo.notificationOpen = false;
//         _acceptNotification = false;
//         currentUser.setNotificationOpen(_acceptNotification);
//       });
//       return;
//     }
//   } else {
//     deviceToken = '';
//     showToast(NL10ns.of(context).close);
//   }
//   currentUser.setNotificationOpen(_acceptNotification);
//
//   var sendMsg = MessageSchema.formSendMessage(
//     from: NKNClientCaller.currentChatId,
//     to: currentUser.clientAddress,
//     contentType: ContentType.eventContactOptions,
//     deviceToken: deviceToken,
//   );
//   sendMsg.deviceToken = deviceToken;
//   sendMsg.content = sendMsg.toContactNoticeOptionData();
//   _chatBloc.add(SendMessageEvent(sendMsg));
// }

// _popWithInformation() {
//   // _saveAndSendBurnMessage();
//   Navigator.of(context).pop('yes');
// }

// copyAction(String content) {
//   CopyUtils.copyAction(context, content);
// }

// showChangeSelfNameDialog() {
//   _firstNameController.text = currentUser.firstName;
//
//   BottomDialog.of(context).showBottomDialog(
//     title: NL10ns.of(context).edit_nickname,
//     child: Form(
//       key: _nameFormKey,
//       autovalidate: true,
//       onChanged: () {
//         _nameFormValid = (_nameFormKey.currentState as FormState).validate();
//       },
//       child: Flex(
//         direction: Axis.horizontal,
//         children: <Widget>[
//           Expanded(
//             flex: 1,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 4),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: <Widget>[
//                   Textbox(
//                     controller: _firstNameController,
//                     focusNode: _firstNameFocusNode,
//                     hintText: NL10ns.of(context).input_nickname,
//                     maxLength: 20,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//     action: Padding(
//       padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
//       child: Button(
//         text: NL10ns.of(context).save,
//         width: double.infinity,
//         onPressed: () async {
//           _nameFormValid = (_nameFormKey.currentState as FormState).validate();
//           if (_nameFormValid) {
//             currentUser.firstName = _firstNameController.text.trim();
//             setState(() {
//               nickName = currentUser.getShowName;
//             });
//             _updateUserInfo(currentUser.firstName, null);
//             _popWithInformation();
//           }
//         },
//       ),
//     ),
//   );
// }

// _updateUserInfo(String nickName, File avatarImage) async {
//   if (currentUser.isMe) {
//     if (nickName != null && nickName.length > 0) {
//       await currentUser.setName(currentUser.firstName);
//     } else if (avatarImage != null) {
//       await currentUser.setAvatar(avatarImage);
//     }
//     _contactBloc.add(UpdateUserInfoEvent(currentUser));
//   } else {
//     Map dataInfo = Map<String, dynamic>();
//     if (nickName != null && nickName.length > 0) {
//       dataInfo['first_name'] = nickName;
//     } else if (avatarImage != null) {
//       dataInfo['avatar'] = avatarImage.path;
//     }
//     await ContactDataCenter.saveRemarkProfile(currentUser, dataInfo);
//     currentUser = await ContactSchema.fetchContactByAddress(currentUser.clientAddress);
//     setState(() {
//       nickName = currentUser.getShowName;
//     });
//   }
//   _chatBloc.add(RefreshMessageListEvent());
// }

// showQRDialog() {
//   String qrContent;
//   if (currentUser.getShowName.length == 6 && currentUser.clientAddress.startsWith(currentUser.getShowName)) {
//     qrContent = currentUser.clientAddress;
//   } else {
//     qrContent = currentUser.getShowName + "@" + currentUser.clientAddress;
//   }
//
//   BottomDialog.of(context).showBottomDialog(
//     title: currentUser.getShowName,
//     height: 480,
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: <Widget>[
//         Label(
//           NL10ns.of(context).scan_show_me_desc,
//           type: LabelType.bodyRegular,
//           color: DefaultTheme.fontColor2,
//           overflow: TextOverflow.fade,
//           textAlign: TextAlign.left,
//           height: 1,
//           softWrap: true,
//         ),
//         SizedBox(height: 10),
//         Center(
//           child: QrImage(
//             data: qrContent,
//             backgroundColor: DefaultTheme.backgroundLightColor,
//             version: QrVersions.auto,
//             size: 240.0,
//           ),
//         )
//       ],
//     ),
//     action: Padding(
//       padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
//       child: Button(
//         text: NL10ns.of(context).close,
//         width: double.infinity,
//         onPressed: () async {
//           _popWithInformation();
//         },
//       ),
//     ),
//   );
// }

// showAction(bool b) async {
//   if (!b) {
//     //delete
//     SimpleConfirm(
//         context: context,
//         content: NL10ns.of(context).delete_friend_confirm_title,
//         buttonText: NL10ns.of(context).delete,
//         buttonColor: Colors.red,
//         callback: (v) {
//           if (v) {
//             currentUser.setFriend(false);
//             setState(() {});
//           }
//         }).show();
//   } else {
//     currentUser.setFriend(b);
//     setState(() {});
//     showToast(NL10ns.of(context).success);
//   }
// }

// getStatusView() {
//   if (currentUser.type == ContactType.stranger) {
//     return Container(
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
//       margin: EdgeInsets.only(left: 16, right: 16, top: 10),
//       child: FlatButton(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
//         child: Container(
//           width: double.infinity,
//           child: Row(
//             children: <Widget>[
//               Icon(
//                 Icons.person_add,
//                 color: DefaultTheme.primaryColor,
//               ),
//               SizedBox(width: 10),
//               Label(NL10ns.of(context).add_contact, type: LabelType.bodyRegular, color: DefaultTheme.primaryColor),
//               Spacer(),
//             ],
//           ),
//         ),
//         onPressed: () {
//           showAction(true);
//         },
//       ).sized(h: 50, w: double.infinity),
//     );
//   } else {
//     return Container(
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
//       margin: EdgeInsets.only(left: 16, right: 16, top: 30),
//       child: FlatButton(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
//         child: Container(
//           width: double.infinity,
//           child: Row(
//             children: <Widget>[
//               Spacer(),
//               Icon(
//                 Icons.delete,
//                 color: Colors.red,
//               ),
//               SizedBox(width: 10),
//               Label(NL10ns.of(context).delete, type: LabelType.bodyRegular, color: Colors.red),
//               Spacer(),
//             ],
//           ),
//         ),
//         onPressed: () {
//           showAction(false);
//         },
//       ).sized(h: 50, w: double.infinity),
//     );
//   }
// }

// _selectWallets() {
//   BottomDialog.of(context).showSelectWalletDialog(
//     title: NL10ns.of(context).select_another_wallet,
//     onlyNkn: true,
//     callback: (wallet) async {
//       Timer(Duration(milliseconds: 30), () {
//         _changeAccount(wallet);
//       });
//     },
//   );
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
//     showToast(NL10ns.of(context).tip_switch_success);
//   });
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
//         showToast(NL10ns.of(context).tip_password_error);
//       }
//     } catch (e) {
//       if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
//         showToast(NL10ns.of(context).tip_password_error);
//       }
//     }
//   }
// }

// getSelfView() {
//   return Scaffold(
//     backgroundColor: DefaultTheme.backgroundColor4,
//     appBar: Header(title: '', backgroundColor: DefaultTheme.backgroundColor4),
//     body: Container(
//       child: Column(
//         children: <Widget>[
//           Container(
//             width: double.infinity,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: <Widget>[
//                 Stack(
//                   children: <Widget>[
//                     Container(
//                       child: GestureDetector(
//                         onTap: () {
//                           updatePic();
//                         },
//                         child: Container(
//                           child: CommonUI.avatarWidget(
//                             radiusSize: 48,
//                             contact: currentUser,
//                           ),
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       bottom: 0,
//                       right: 0,
//                       child: Button(
//                         padding: const EdgeInsets.all(0),
//                         width: 24,
//                         height: 24,
//                         backgroundColor: DefaultTheme.primaryColor,
//                         child: SvgPicture.asset('assets/icons/camera.svg', width: 16),
//                         onPressed: () async {
//                           updatePic();
//                         },
//                       ),
//                     )
//                   ],
//                 ),
//                 SizedBox(height: 20)
//               ],
//             ),
//           ),
//           Expanded(
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
//               child: BodyBox(
//                 padding: EdgeInsets.only(
//                   top: 0,
//                 ),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Padding(
//                         padding: EdgeInsets.fromLTRB(20.w, 20.h, 0, 16.h),
//                         child: Label(
//                           NL10ns.of(context).my_profile,
//                           type: LabelType.h3,
//                         ),
//                       ),
//                       Container(
//                         decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
//                         margin: EdgeInsets.symmetric(horizontal: 12),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: <Widget>[
//                             FlatButton(
//                               padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
//                               onPressed: showChangeSelfNameDialog,
//                               child: Row(
//                                 children: <Widget>[
//                                   loadAssetIconsImage('user', color: DefaultTheme.primaryColor, width: 24),
//                                   SizedBox(width: 10),
//                                   Label(
//                                     NL10ns.of(context).nickname,
//                                     type: LabelType.bodyRegular,
//                                     color: DefaultTheme.fontColor1,
//                                     height: 1,
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Label(
//                                       nickName ?? '',
//                                       type: LabelType.bodyRegular,
//                                       color: DefaultTheme.fontColor2,
//                                       overflow: TextOverflow.fade,
//                                       textAlign: TextAlign.right,
//                                       height: 1,
//                                     ),
//                                   ),
//                                   SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
//                                 ],
//                               ),
//                             ).sized(h: 48),
//                             FlatButton(
//                               padding: const EdgeInsets.only(left: 16, right: 16),
//                               onPressed: () {
//                                 Navigator.pushNamed(context, ShowMyChatID.routeName);
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 children: <Widget>[
//                                   loadAssetChatPng('chat_id', color: DefaultTheme.primaryColor, width: 22),
//                                   SizedBox(width: 10),
//                                   Label(
//                                     NL10ns.of(context).d_chat_address,
//                                     type: LabelType.bodyRegular,
//                                     color: DefaultTheme.fontColor1,
//                                     height: 1,
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Label(
//                                       _chatAddress(),
//                                       type: LabelType.bodyRegular,
//                                       textAlign: TextAlign.right,
//                                       color: DefaultTheme.fontColor2,
//                                       maxLines: 1,
//                                     ),
//                                   ),
//                                   SvgPicture.asset(
//                                     'assets/icons/right.svg',
//                                     width: 24,
//                                     color: DefaultTheme.fontColor2,
//                                   )
//                                 ],
//                               ),
//                             ).sized(h: 48),
//                             FlatButton(
//                               padding: const EdgeInsets.only(left: 16, right: 16),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
//                               onPressed: _selectWallets,
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: <Widget>[
//                                   loadAssetIconsImage('wallet', color: DefaultTheme.primaryColor, width: 24),
//                                   _walletDefault == null
//                                       ? BlocBuilder<WalletsBloc, WalletsState>(
//                                           builder: (ctx, state) {
//                                             if (state is WalletsLoaded) {
//                                               final wallet = state.wallets.firstWhere((w) {
//                                                 return w.address == currentUser.nknWalletAddress;
//                                               }, orElse: null);
//                                               if (wallet != null) {
//                                                 _walletDefault = wallet;
//                                               }
//                                             }
//                                             return Label(
//                                               _walletDefault?.name ?? '--',
//                                               type: LabelType.bodyRegular,
//                                               color: DefaultTheme.fontColor1,
//                                               height: 1,
//                                             ).pad(l: 10);
//                                           },
//                                         )
//                                       : Label(
//                                           _walletDefault?.name ?? '--',
//                                           type: LabelType.bodyRegular,
//                                           color: DefaultTheme.fontColor1,
//                                           height: 1,
//                                         ).pad(l: 10),
//                                   Expanded(
//                                     child: Label(
//                                       NL10ns.of(context).change_default_chat_wallet,
//                                       type: LabelType.bodyRegular,
//                                       color: Colours.blue_0f,
//                                       textAlign: TextAlign.right,
//                                       maxLines: 1,
//                                     ),
//                                   )
//                                 ],
//                               ),
//                             ).sized(h: 48),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

}
