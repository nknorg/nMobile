import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/auth/auth_bloc.dart';
import 'package:nmobile/blocs/auth/auth_event.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/router/custom_router.dart';
import 'package:nmobile/model/entity/chat.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/model/entity/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/contact/chat_profile.dart';
import 'package:nmobile/screens/contact/show_chat_id.dart';
import 'package:nmobile/screens/view/burn_view_utils.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ContactScreen extends StatefulWidget {
  static const String routeName = '/contact';

  final ContactSchema contactInfo;

  ContactScreen({this.contactInfo});

  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  FocusNode _firstNameFocusNode = FocusNode();
  GlobalKey _nameFormKey = new GlobalKey<FormState>();
  GlobalKey _notesFormKey = new GlobalKey<FormState>();
  bool _nameFormValid = false;
  bool _notesFormValid = false;
  bool _burnSelected = false;
  bool _initBurnSelected = false;
  int _burnIndex = -1;
  int _initBurnIndex = -1;
  WalletSchema _walletDefault;

  bool _acceptNotification = false;

  ContactSchema currentUser;

  String nickName;
  String chatAddress;
  String walletAddress;

  static const fcmGapString = '__FCMToken__:';

  AuthBloc _authBloc;
  NKNClientBloc _clientBloc;
  ChatBloc _chatBloc;

  ContactBloc _contactBloc;

  @override
  void dispose() {
    _saveAndSendBurnMessage();
    super.dispose();
  }

  @override
  initState() {
    super.initState();

    _authBloc = BlocProvider.of<AuthBloc>(context);
    _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _contactBloc = BlocProvider.of<ContactBloc>(context);

    _clientBloc.aBloc = _authBloc;

    currentUser = widget.contactInfo;

    int burnAfterSeconds = currentUser?.options?.deleteAfterSeconds;

    if (currentUser.isMe == false) {
      _acceptNotification = false;
      if (currentUser.notificationOpen != null) {
        _acceptNotification = currentUser.notificationOpen;
      }
    }

    _burnSelected = burnAfterSeconds != null;
    if (_burnSelected) {
      _burnIndex = BurnViewUtil.burnValueArray
          .indexWhere((x) => x.inSeconds == burnAfterSeconds);
      if (burnAfterSeconds > BurnViewUtil.burnValueArray.last.inSeconds) {
        _burnIndex = BurnViewUtil.burnValueArray.length - 1;
      }
    }
    if (_burnIndex < 0) _burnIndex = 0;
    _initBurnSelected = _burnSelected;
    _initBurnIndex = _burnIndex;

    this.nickName = currentUser.getShowName;

    this.chatAddress = currentUser.clientAddress;
    this.walletAddress = currentUser.nknWalletAddress;

    _notesController.text = currentUser.notes;
  }

  String _chatAddress() {
    if (currentUser != null) {
      if (currentUser.clientAddress != null) {
        if (currentUser.clientAddress.length > 8) {
          return currentUser.clientAddress.substring(0, 8) + '...';
        }
        return currentUser.clientAddress;
      }
    }
    return '';
  }

  _saveAndSendBurnMessage() async {
    if (_burnSelected == _initBurnSelected && _burnIndex == _initBurnIndex)
      return;
    var _burnValue;
    if (!_burnSelected || _burnIndex < 0) {
      await currentUser.setBurnOptions(null);
    } else {
      _burnValue = BurnViewUtil.burnValueArray[_burnIndex].inSeconds;
      NLog.w('_saveAndSendBurnMessage_____!!!!' + _burnValue.toString());
      await currentUser.setBurnOptions(_burnValue);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: currentUser.clientAddress,
      contentType: ContentType.eventContactOptions,
    );
    sendMsg.burnAfterSeconds = _burnValue;
    sendMsg.content = sendMsg.toContactBurnOptionData();

    _chatBloc.add(SendMessageEvent(sendMsg));
  }

  _saveAndSendDeviceToken() async {
    String deviceToken = '';
    widget.contactInfo.notificationOpen = _acceptNotification;
    if (_acceptNotification == true) {
      deviceToken = await NKNClientCaller.fetchDeviceToken();
      if (Platform.isIOS) {
        String fcmToken = await NKNClientCaller.fetchFcmToken();
        if (fcmToken != null && fcmToken.length > 0) {
          deviceToken = deviceToken + "$fcmGapString$fcmToken";
        }
      }
      if (Platform.isAndroid && deviceToken.length == 0) {
        showToast(NL10ns.of(context).unavailable_device);
        setState(() {
          widget.contactInfo.notificationOpen = false;
          _acceptNotification = false;
          currentUser.setNotificationOpen(_acceptNotification);
        });
        return;
      }
    } else {
      deviceToken = '';
      showToast(NL10ns.of(context).close);
    }
    currentUser.setNotificationOpen(_acceptNotification);

    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: currentUser.clientAddress,
      contentType: ContentType.eventContactOptions,
      deviceToken: deviceToken,
    );
    sendMsg.deviceToken = deviceToken;
    sendMsg.content = sendMsg.toContactNoticeOptionData();
    _chatBloc.add(SendMessageEvent(sendMsg));
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser.isMe) {
      return getSelfView();
    } else {
      return getPersonView();
    }
  }

  _popWithInformation() {
    // _saveAndSendBurnMessage();
    Navigator.of(context).pop('yes');
  }

  _detailChangeName(BuildContext context) {
    BottomDialog.of(context).showBottomDialog(
      title: NL10ns.of(context).edit_contact,
      child: Form(
        key: _nameFormKey,
        autovalidate: true,
        onChanged: () {
          _nameFormValid = (_nameFormKey.currentState as FormState).validate();
        },
        child: Flex(
          direction: Axis.horizontal,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Textbox(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      maxLength: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).save,
          width: double.infinity,
          onPressed: () async {
            _nameFormValid =
                (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              String nName = _firstNameController.text.trim();
              setState(() {
                nickName = nName;
              });
              _updateUserInfo(nName, null);

              _chatBloc.add(RefreshMessageListEvent());
              _popWithInformation();
            }
          },
        ),
      ),
    );
  }

  copyAction(String content) {
    CopyUtils.copyAction(context, content);
  }

  updatePic() async {
    String saveImagePath = '';
    if (currentUser.isMe) {
      saveImagePath = NKNClientCaller.currentChatId;
    } else {
      saveImagePath = 'remark_' + currentUser.clientAddress;
    }
    NLog.w('!!!!!! saveImagePath is_____' + saveImagePath.toString());
    File savedImg = await getHeaderImage(saveImagePath);
    if (savedImg == null) {
      showToast(
          'Open camera or MediaLibrary for nMobile to update your profile');
    } else {
      if (mounted) {
        setState(() {
          currentUser.avatar = savedImg;
        });
      }
      _updateUserInfo(null, savedImg);
    }
  }

  showChangeSelfNameDialog() {
    _firstNameController.text = currentUser.firstName;

    BottomDialog.of(context).showBottomDialog(
      title: NL10ns.of(context).edit_nickname,
      child: Form(
        key: _nameFormKey,
        autovalidate: true,
        onChanged: () {
          _nameFormValid = (_nameFormKey.currentState as FormState).validate();
        },
        child: Flex(
          direction: Axis.horizontal,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Textbox(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      hintText: NL10ns.of(context).input_nickname,
                      maxLength: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).save,
          width: double.infinity,
          onPressed: () async {
            _nameFormValid =
                (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              currentUser.firstName = _firstNameController.text.trim();
              setState(() {
                nickName = currentUser.getShowName;
              });
              _updateUserInfo(currentUser.firstName, null);
              _popWithInformation();
            }
          },
        ),
      ),
    );
  }

  _updateUserInfo(String nickName, File avatarImage) async {
    if (currentUser.isMe) {
      if (nickName != null && nickName.length > 0) {
        await currentUser.setName(currentUser.firstName);
      } else if (avatarImage != null) {
        await currentUser.setAvatar(avatarImage);
      }
      _contactBloc.add(UpdateUserInfoEvent(currentUser));
      NLog.w('UpdateContactBLockcccccccc');
    } else {
      Map dataInfo = Map<String, dynamic>();
      if (nickName != null && nickName.length > 0) {
        dataInfo['first_name'] = nickName;
      } else if (avatarImage != null) {
        dataInfo['avatar'] = avatarImage.path;
      }
      await ContactDataCenter.saveRemarkProfile(currentUser, dataInfo);
      currentUser =
          await ContactSchema.fetchContactByAddress(currentUser.clientAddress);
      setState(() {
        nickName = currentUser.getShowName;
      });
    }
    _chatBloc.add(RefreshMessageListEvent());
  }

  showQRDialog() {
    String qrContent;
    if (currentUser.getShowName.length == 6 &&
        currentUser.clientAddress.startsWith(currentUser.getShowName)) {
      qrContent = currentUser.clientAddress;
    } else {
      qrContent = currentUser.getShowName + "@" + currentUser.clientAddress;
    }

    BottomDialog.of(context).showBottomDialog(
      title: currentUser.getShowName,
      height: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Label(
            NL10ns.of(context).scan_show_me_desc,
            type: LabelType.bodyRegular,
            color: DefaultTheme.fontColor2,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.left,
            height: 1,
            softWrap: true,
          ),
          SizedBox(height: 10),
          Center(
            child: QrImage(
              data: qrContent,
              backgroundColor: DefaultTheme.backgroundLightColor,
              version: QrVersions.auto,
              size: 240.0,
            ),
          )
        ],
      ),
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NL10ns.of(context).close,
          width: double.infinity,
          onPressed: () async {
            _popWithInformation();
          },
        ),
      ),
    );
  }

  showAction(bool b) async {
    if (!b) {
      //delete
      SimpleConfirm(
          context: context,
          content: NL10ns.of(context).delete_friend_confirm_title,
          buttonText: NL10ns.of(context).delete,
          buttonColor: Colors.red,
          callback: (v) {
            if (v) {
              currentUser.setFriend(false);
              setState(() {});
            }
          }).show();
    } else {
      currentUser.setFriend(b);
      setState(() {});
      showToast(NL10ns.of(context).success);
    }
  }

  getStatusView() {
    if (currentUser.type == ContactType.stranger) {
      return Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 16, right: 16, top: 10),
        child: FlatButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.person_add,
                  color: DefaultTheme.primaryColor,
                ),
                SizedBox(width: 10),
                Label(NL10ns.of(context).add_contact,
                    type: LabelType.bodyRegular,
                    color: DefaultTheme.primaryColor),
                Spacer(),
              ],
            ),
          ),
          onPressed: () {
            showAction(true);
          },
        ).sized(h: 50, w: double.infinity),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 16, right: 16, top: 30),
        child: FlatButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Spacer(),
                Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                SizedBox(width: 10),
                Label(NL10ns.of(context).delete,
                    type: LabelType.bodyRegular, color: Colors.red),
                Spacer(),
              ],
            ),
          ),
          onPressed: () {
            showAction(false);
          },
        ).sized(h: 50, w: double.infinity),
      );
    }
  }

  _selectWallets() {
    BottomDialog.of(context).showSelectWalletDialog(
      title: NL10ns.of(context).select_another_wallet,
      onlyNkn: true,
      callback: (wallet) async {
        Timer(Duration(milliseconds: 30), () {
          _changeAccount(wallet);
        });
      },
    );
  }

  void onGetPassword(WalletSchema wallet, String password) async {
    EasyLoading.show();

    var eWallet = await wallet.exportWallet(password);
    // currentUser = await ContactSchema.fetchCurrentUser();

    _clientBloc.add(NKNDisConnectClientEvent());
    if (currentUser == null) {
      NLog.w('Current User is____null');
      DateTime now = DateTime.now();
      currentUser = ContactSchema(
        type: ContactType.me,
        clientAddress: eWallet['publicKey'],
        nknWalletAddress: eWallet['address'],
        createdTime: now,
        updatedTime: now,
        profileVersion: uuid.v4(),
      );
      await currentUser.insertContact();
    }

    TimerAuth.instance.enableAuth();
    await LocalStorage()
        .set(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS, eWallet['address']);

    var walletAddress = eWallet['address'];
    var publicKey = eWallet['publicKey'];
    Uint8List seedList = Uint8List.fromList(hexDecode(eWallet['seed']));
    if (seedList != null && seedList.isEmpty) {
      NLog.w('Wrong!!! seedList.isEmpty');
    }
    String _seedKey =
        hexEncode(sha256(hexEncode(seedList.toList(growable: false))));

    if (NKNClientCaller.currentChatId == null ||
        publicKey == NKNClientCaller.currentChatId ||
        NKNClientCaller.currentChatId.length == 0) {
      await NKNDataManager.instance.initDataBase(publicKey, _seedKey);
    } else {
      await NKNDataManager.instance.changeDatabase(publicKey, _seedKey);
    }
    NKNClientCaller.instance.setChatId(publicKey);

    currentUser = await ContactSchema.fetchCurrentUser();
    setState(() {
      nickName = currentUser.getShowName;
      chatAddress = currentUser.clientAddress;
      walletAddress = currentUser.nknWalletAddress;
    });

    _authBloc.add(AuthToUserEvent(publicKey, walletAddress));
    NKNClientCaller.instance.createClient(seedList, null, publicKey);

    Timer(Duration(milliseconds: 200), () async {
      EasyLoading.dismiss();
      showToast(NL10ns.of(context).tip_switch_success);
    });
  }

  _changeAccount(WalletSchema wallet) async {
    if (wallet.address == currentUser.nknWalletAddress) return;
    var password = await BottomDialog.of(Global.appContext)
        .showInputPasswordDialog(
            title: NL10ns.of(Global.appContext).verify_wallet_password);
    if (password != null) {
      try {
        var w = await wallet.exportWallet(password);
        if (w['address'] == wallet.address) {
          onGetPassword(wallet, password);
        } else {
          showToast(NL10ns.of(context).tip_password_error);
        }
      } catch (e) {
        if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
          showToast(NL10ns.of(context).tip_password_error);
        }
      }
    }
  }

  getSelfView() {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(title: '', backgroundColor: DefaultTheme.backgroundColor4),
      body: Container(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      Container(
                        child: GestureDetector(
                          onTap: () {
                            updatePic();
                          },
                          child: Container(
                            child: CommonUI.avatarWidget(
                              radiusSize: 48,
                              contact: currentUser,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Button(
                          padding: const EdgeInsets.all(0),
                          width: 24,
                          height: 24,
                          backgroundColor: DefaultTheme.primaryColor,
                          child: SvgPicture.asset('assets/icons/camera.svg',
                              width: 16),
                          onPressed: () async {
                            updatePic();
                          },
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 20)
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
                child: BodyBox(
                  padding: EdgeInsets.only(
                    top: 0,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(20.w, 20.h, 0, 16.h),
                          child: Label(
                            NL10ns.of(context).my_profile,
                            type: LabelType.h3,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              color: DefaultTheme.backgroundLightColor,
                              borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              FlatButton(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, top: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12))),
                                onPressed: showChangeSelfNameDialog,
                                child: Row(
                                  children: <Widget>[
                                    loadAssetIconsImage('user',
                                        color: DefaultTheme.primaryColor,
                                        width: 24),
                                    SizedBox(width: 10),
                                    Label(
                                      NL10ns.of(context).nickname,
                                      type: LabelType.bodyRegular,
                                      color: DefaultTheme.fontColor1,
                                      height: 1,
                                    ),
                                    SizedBox(width: 20),
                                    Expanded(
                                      child: Label(
                                        nickName ?? '',
                                        type: LabelType.bodyRegular,
                                        color: DefaultTheme.fontColor2,
                                        overflow: TextOverflow.fade,
                                        textAlign: TextAlign.right,
                                        height: 1,
                                      ),
                                    ),
                                    SvgPicture.asset('assets/icons/right.svg',
                                        width: 24,
                                        color: DefaultTheme.fontColor2)
                                  ],
                                ),
                              ).sized(h: 48),
                              FlatButton(
                                padding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, ShowMyChatID.routeName);
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    loadAssetChatPng('chat_id',
                                        color: DefaultTheme.primaryColor,
                                        width: 22),
                                    SizedBox(width: 10),
                                    Label(
                                      NL10ns.of(context).d_chat_address,
                                      type: LabelType.bodyRegular,
                                      color: DefaultTheme.fontColor1,
                                      height: 1,
                                    ),
                                    SizedBox(width: 20),
                                    Expanded(
                                      child: Label(
                                        _chatAddress(),
                                        type: LabelType.bodyRegular,
                                        textAlign: TextAlign.right,
                                        color: DefaultTheme.fontColor2,
                                        maxLines: 1,
                                      ),
                                    ),
                                    SvgPicture.asset(
                                      'assets/icons/right.svg',
                                      width: 24,
                                      color: DefaultTheme.fontColor2,
                                    )
                                  ],
                                ),
                              ).sized(h: 48),
                              FlatButton(
                                padding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12))),
                                onPressed: _selectWallets,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    loadAssetIconsImage('wallet',
                                        color: DefaultTheme.primaryColor,
                                        width: 24),
                                    _walletDefault == null
                                        ? BlocBuilder<WalletsBloc,
                                            WalletsState>(
                                            builder: (ctx, state) {
                                              if (state is WalletsLoaded) {
                                                final wallet = state.wallets
                                                    .firstWhere((w) {
                                                  return w.address ==
                                                      currentUser
                                                          .nknWalletAddress;
                                                }, orElse: null);
                                                if (wallet != null) {
                                                  _walletDefault = wallet;
                                                }
                                              }
                                              return Label(
                                                _walletDefault?.name ?? '--',
                                                type: LabelType.bodyRegular,
                                                color: DefaultTheme.fontColor1,
                                                height: 1,
                                              ).pad(l: 10);
                                            },
                                          )
                                        : Label(
                                            _walletDefault?.name ?? '--',
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ).pad(l: 10),
                                    Expanded(
                                      child: Label(
                                        NL10ns.of(context)
                                            .change_default_chat_wallet,
                                        type: LabelType.bodyRegular,
                                        color: Colours.blue_0f,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                      ),
                                    )
                                  ],
                                ),
                              ).sized(h: 48),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personListView() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
        ),
        color: DefaultTheme.backgroundColor6,
      ),
      height: MediaQuery.of(context).size.height,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 4, bottom: 32),
        itemCount: 9,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Stack(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          if (currentUser.getShowAvatarPath != null &&
                              currentUser.getShowAvatarPath.length > 0) {
                            print('currentUser.avatarFilePath is__' +
                                currentUser.getShowAvatarPath.toString());
                            if (currentUser.getShowAvatarPath != null) {
                              Navigator.push(
                                  context,
                                  CustomRoute(PhotoPage(
                                      arguments:
                                          currentUser.getShowAvatarPath)));
                            }
                          } else {
                            updatePic();
                          }
                        },
                        child: Container(
                          child: CommonUI.avatarWidget(
                            radiusSize: 48,
                            contact: currentUser,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Button(
                          padding: const EdgeInsets.all(0),
                          width: 24,
                          height: 24,
                          backgroundColor: DefaultTheme.primaryColor,
                          child: SvgPicture.asset(
                            'assets/icons/camera.svg',
                            width: 16,
                          ),
                          onPressed: () async {
                            updatePic();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Label(
                        currentUser.getShowName,
                        type: LabelType.bodyLarge,
                        color: Colors.white,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                ],
              ),
            );
          } else if (index == 1) {
            return Container(
              decoration: BoxDecoration(
                  color: DefaultTheme.backgroundLightColor,
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FlatButton(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12))),
                    onPressed: () {
                      _firstNameController.text = currentUser.getShowName;
                      _detailChangeName(context);
                    },
                    child: Row(
                      children: <Widget>[
                        loadAssetIconsImage('user',
                            color: DefaultTheme.primaryColor, width: 24),
                        SizedBox(width: 10),
                        Label(
                          NL10ns.of(context).nickname,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1,
                          height: 1,
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Label(
                            currentUser.getShowName,
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor2,
                            overflow: TextOverflow.fade,
                            textAlign: TextAlign.right,
                            height: 1,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/right.svg',
                          width: 24,
                          color: DefaultTheme.fontColor2,
                        )
                      ],
                    ),
                  ).sized(h: 48),
                  FlatButton(
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(12))),
                    onPressed: () {
                      Navigator.pushNamed(context, ChatProfile.routeName,
                          arguments: currentUser);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        loadAssetChatPng(
                          'chat_id',
                          color: DefaultTheme.primaryColor,
                          width: 22,
                        ),
                        SizedBox(width: 10),
                        Label(
                          NL10ns.of(context).d_chat_address,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1,
                          height: 1,
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Label(
                            _chatAddress(),
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor2,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/right.svg',
                          width: 24,
                          color: DefaultTheme.fontColor2,
                        )
                      ],
                    ),
                  ).sized(h: 48),
                ],
              ),
            );
          } else if (index == 2) {
            return SizedBox(height: 10);
          } else if (index == 3) {
            return Container(
              decoration: BoxDecoration(
                  color: DefaultTheme.backgroundLightColor,
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                onPressed: () async {
                  setState(() {
                    _burnSelected = !_burnSelected;
                  });
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  padding: _burnSelected ? 0.symm(v: 5.5) : 0.pad(),
                  child: Column(
                    mainAxisAlignment: _burnSelected
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: [
                          loadAssetWalletImage('xiaohui',
                              color: DefaultTheme.primaryColor, width: 24),
                          SizedBox(width: 10),
                          Label(
                            NL10ns.of(context).burn_after_reading,
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor1,
                            textAlign: TextAlign.start,
                          ),
                          Spacer(),
                          CupertinoSwitch(
                            value: _burnSelected,
                            activeColor: DefaultTheme.primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _burnSelected = value;
                              });
                            },
                          ),
                        ],
                      ),
                      _burnSelected
                          ? Row(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.alarm_on,
                                        size: 24, color: Colours.blue_0f)
                                    .pad(r: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Label(
                                        (!_burnSelected || _burnIndex < 0)
                                            ? NL10ns.of(context).off
                                            : BurnViewUtil.getStringFromSeconds(
                                                context,
                                                BurnViewUtil
                                                    .burnValueArray[_burnIndex]
                                                    .inSeconds),
                                        type: LabelType.bodyRegular,
                                        color: Colours.gray_81,
                                        fontWeight: FontWeight.w700,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Slider(
                                        value: _burnIndex.d,
                                        min: 0,
                                        max: (BurnViewUtil
                                                    .burnValueArray.length -
                                                1)
                                            .d,
                                        activeColor: Colours.blue_0f,
                                        inactiveColor: Colours.gray_81,
                                        divisions:
                                            BurnViewUtil.burnValueArray.length -
                                                1,
                                        label: BurnViewUtil.burnTextArray(
                                            context)[_burnIndex],
                                        onChanged: (value) {
                                          setState(() {
                                            _burnIndex = value.round();
                                            if (_burnIndex >
                                                BurnViewUtil
                                                        .burnValueArray.length -
                                                    1) {
                                              _burnIndex = BurnViewUtil
                                                      .burnValueArray.length -
                                                  1;
                                            }
                                          });
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Space.empty,
                    ],
                  ),
                ),
              ).sized(h: _burnSelected ? 112 : 50, w: double.infinity),
            );
          } else if (index == 4) {
            return Label(
              (!_burnSelected || _burnIndex < 0)
                  ? NL10ns.of(context).burn_after_reading_desc
                  : NL10ns.of(context).burn_after_reading_desc_disappear(
                      BurnViewUtil.burnTextArray(context)[_burnIndex],
                    ),
              type: LabelType.bodySmall,
              color: Colours.gray_81,
              fontWeight: FontWeight.w600,
              softWrap: true,
            ).pad(t: 6, b: 8, l: 20, r: 20);
          } else if (index == 5) {
            return Container(
              decoration: BoxDecoration(
                  color: DefaultTheme.backgroundLightColor,
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                onPressed: () async {
                  // setState(() {
                  //   _acceptNotification = !_acceptNotification;
                  //   NLog.w('oNChanged 11111111'+_acceptNotification.toString());
                  //   _saveAndSendDeviceToken();
                  // });
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  padding: _acceptNotification ? 0.symm(v: 5.5) : 0.pad(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: [
                          loadAssetIconsImage('notification_bell',
                              color: DefaultTheme.primaryColor, width: 24),
                          SizedBox(width: 10),
                          Label(
                            NL10ns.of(context).remote_notification,
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor1,
                            textAlign: TextAlign.start,
                          ),
                          Spacer(),
                          CupertinoSwitch(
                            value: _acceptNotification,
                            activeColor: DefaultTheme.primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _acceptNotification = value;
                                _saveAndSendDeviceToken();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).sized(h: 50, w: double.infinity),
            );
          } else if (index == 6) {
            if (Platform.isAndroid) {
              return Container(
                height: 1,
              );
            }
            return Label(
              // (_acceptNotification)
              //     ? NL10ns.of(context).setting_accept_notification
              //     : NL10ns.of(context).setting_deny_notification,
              NL10ns.of(context).accept_notification,
              type: LabelType.bodySmall,
              color: Colours.gray_81,
              fontWeight: FontWeight.w600,
              softWrap: true,
            ).pad(t: 6, b: 8, l: 20, r: 20);
          } else if (index == 7) {
            return Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  child: Row(
                    children: <Widget>[
                      SvgPicture.asset('assets/icons/chat.svg',
                          width: 24, color: DefaultTheme.primaryColor),
//                                      loadAssetChatPng('send_message', width: 22),
                      SizedBox(width: 10),
                      Label(NL10ns.of(context).send_message,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1),
                      Spacer(),
                      SvgPicture.asset('assets/icons/right.svg',
                          width: 24, color: DefaultTheme.fontColor2)
                    ],
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed(ChatSinglePage.routeName,
                      arguments: ChatSchema(
                          type: ChatType.PrivateChat, contact: currentUser));
                },
              ).sized(h: 50, w: double.infinity),
            );
          } else if (index == 8){
            return getStatusView();
          }
          return Container();
        },
      ),
    );
  }

  getPersonView() {
    return Scaffold(
        backgroundColor: DefaultTheme.backgroundColor4,
        appBar: Header(
          leading: BackButton(
            onPressed: () {
              _popWithInformation();
            },
          ),
          backgroundColor: DefaultTheme.backgroundColor4,
        ),
        body: _personListView());
  }
}
