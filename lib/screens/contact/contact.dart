import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/router/custom_router.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/contact/chat_profile.dart';
import 'package:nmobile/screens/contact/show_chat_id.dart';
import 'package:nmobile/screens/contact/show_my_chat_address.dart';
import 'package:nmobile/screens/view/burn_view_utils.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ContactScreen extends StatefulWidget {
  static const String routeName = '/contact';


  final ContactSchema arguments;

  ContactScreen({this.arguments});

  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> with RouteAware, AccountDependsBloc {
  ChatBloc _chatBloc;
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
  SourceProfile _sourceProfile;
  String nickName;
  WalletSchema _walletDefault;

  bool _acceptNotification = false;

  static const fcmGapString = '__FCMToken__:';

  initAsync() async {
    _sourceProfile = widget.arguments.sourceProfile;
    setState(() {});

    NLog.d('getAndroidXXXX');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RouteUtils.routeObserver.subscribe(this, ModalRoute.of(context));
  }

  @override
  void dispose() {
    RouteUtils.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPop() {
//    _setContactOptions();
    NLog.d('didPop');
    super.didPop();
  }

  @override
  Future<void> initState() {
    super.initState();
    NLog.d('getAndroidXXXX');

    _chatBloc = BlocProvider.of<ChatBloc>(context);
    initAsync();
    int burnAfterSeconds = widget.arguments.options?.deleteAfterSeconds;

    if (widget.arguments.notificationOpen != null && widget.arguments.notificationOpen == true){
      _acceptNotification = true;
    }

    _burnSelected = burnAfterSeconds != null;
    if (_burnSelected) {
      _burnIndex = BurnViewUtil.burnValueArray.indexWhere((x) => x.inSeconds == burnAfterSeconds);
      if (burnAfterSeconds > BurnViewUtil.burnValueArray.last.inSeconds) {
        _burnIndex = BurnViewUtil.burnValueArray.length - 1;
      }
    }
    if (_burnIndex < 0) _burnIndex = 0;
    _initBurnSelected = _burnSelected;
    _initBurnIndex = _burnIndex;

    nickName = widget.arguments.name;
    _notesController.text = widget.arguments.notes;
  }

  _saveAndSendBurnMessage() async {
    if (_burnSelected == _initBurnSelected && _burnIndex == _initBurnIndex) return;
    var _burnValue;
    if (!_burnSelected || _burnIndex < 0) {
      await widget.arguments.setBurnOptions(db, null);
      print("Close Send Burn Message");
    } else {
      _burnValue = BurnViewUtil.burnValueArray[_burnIndex].inSeconds;
      await widget.arguments.setBurnOptions(db, _burnValue);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: accountChatId,
      to: widget.arguments.clientAddress,
      contentType: ContentType.eventContactOptions,
    );
    sendMsg.isOutbound = true;
    sendMsg.burnAfterSeconds = _burnValue;
    sendMsg.content = sendMsg.toContentOptionData(0);

    print("Send Burn Message"+sendMsg.content.toString());
    _chatBloc.add(SendMessage(sendMsg));
  }

  _saveAndSendDeviceToken() async{
    String deviceToken = '';
    if (_acceptNotification == true){
      deviceToken = await account.client.fetchDeviceToken();
      if (Platform.isIOS){
        String fcmToken = await account.client.fetchFCMToken();
        if (fcmToken != null && fcmToken.length > 0){
          deviceToken = deviceToken+"$fcmGapString$fcmToken";
        }
      }
      if (Platform.isAndroid && deviceToken.length == 0){
        showToast('暂不支持没有Google服务的机型');
      }
    }
    else{
      deviceToken = '';
      showToast('关闭');
    }
    widget.arguments.setNotificationOpen(db, _acceptNotification);

    var sendMsg = MessageSchema.fromSendData(
      from: accountChatId,
      to: widget.arguments.clientAddress,
      contentType: ContentType.eventContactOptions,
      deviceToken: deviceToken,
    );
    sendMsg.isOutbound = true;
    sendMsg.content = sendMsg.toContentOptionData(1);
    sendMsg.deviceToken = deviceToken;
    _chatBloc.add(SendMessage(sendMsg));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.arguments.isMe) {
      return getSelfView();
    } else {
      return getPersonView();
    }
  }

  changeNotes() {
    BottomDialog.of(context).showBottomDialog(
      height: 320,
      title: NL10ns.of(context).edit_notes,
      child: Form(
        key: _notesFormKey,
        autovalidate: true,
        onChanged: () {
          _notesFormValid = (_notesFormKey.currentState as FormState).validate();
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
                    Label(
                      NL10ns.of(context).notes,
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                    Textbox(
                      multi: true,
                      minLines: 1,
                      maxLines: 3,
                      controller: _notesController,
                      textInputAction: TextInputAction.newline,
                      maxLength: 200,
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
            _notesFormValid = (_notesFormKey.currentState as FormState).validate();
            if (_notesFormValid) {
              var contact = widget.arguments;
              contact.notes = _notesController.text.trim();

              await contact.setNotes(db, contact.notes);
              _chatBloc.add(RefreshMessages());
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
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
            _nameFormValid = (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              var contact = widget.arguments;
              contact.firstName = _firstNameController.text.trim();
              await contact.setName(db, contact.firstName);
              setState(() {
                nickName = widget.arguments.name;
              });
              _chatBloc.add(RefreshMessages());
              Navigator.of(context).pop();
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
    File savedImg = await getHeaderImage(accountPubkey);
    if (savedImg == null) return;
    await widget.arguments.setAvatar(db, accountPubkey, savedImg);
    setState(() {
      widget.arguments.avatar = savedImg;
    });
  }

  showChangeSelfNameDialog() {
    _firstNameController.text = widget.arguments.firstName;

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
            _nameFormValid = (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              var contact = widget.arguments;
              contact.firstName = _firstNameController.text.trim();
              setState(() {
                nickName = widget.arguments.name;
              });
              contact.setName(db, contact.firstName);
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  showQRDialog() {
    String qrContent;
    if (widget.arguments.name.length == 6 && widget.arguments.clientAddress.startsWith(widget.arguments.name)) {
      qrContent = widget.arguments.clientAddress;
    } else {
      qrContent = widget.arguments.name + "@" + widget.arguments.clientAddress;
    }

    BottomDialog.of(context).showBottomDialog(
      title: widget.arguments.name,
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
            Navigator.pop(context);
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
              widget.arguments.setFriend(db, isFriend: false);
              setState(() {});
            }
          }).show();
    } else {
      widget.arguments.setFriend(db, isFriend: b);
      setState(() {});
      showToast(NL10ns.of(context).success);
    }
  }

  getStatusView() {
    if (widget.arguments.type == ContactType.stranger) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 16, right: 16, top: 10),
        child: FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.person_add,
                  color: DefaultTheme.primaryColor,
                ),
                SizedBox(width: 10),
                Label(NL10ns.of(context).add_contact, type: LabelType.bodyRegular, color: DefaultTheme.primaryColor),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 16, right: 16, top: 10),
        child: FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                SizedBox(width: 10),
                Label(NL10ns.of(context).delete, type: LabelType.bodyRegular, color: Colors.red),
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

  String getName() {
    String name =
        '${_sourceProfile?.name != null && _sourceProfile.name.isNotEmpty && (widget.arguments.firstName != null && widget.arguments.firstName.isNotEmpty || widget.arguments.lastName != null && widget.arguments.lastName.isNotEmpty) ? '(${_sourceProfile?.name})' : ''}';
    return widget.arguments.name;
  }

  _selectWallets() {
    BottomDialog.of(context).showSelectWalletDialog(
      title: NL10ns.of(context).select_another_wallet,
      onlyNkn: true,
      callback: (wallet) async {
        LOG('_selectWallets').w(wallet);
        Timer(Duration(milliseconds: 30), () {
          _changeAccount(wallet);
        });
      },
    );
  }

  _changeAccount(WalletSchema wallet) async {
    if (wallet.address == widget.arguments.nknWalletAddress) return;
    DChatAuthenticationHelper.authToVerifyPassword(
        forceShowInputDialog: true,
        wallet: wallet,
        onGot: (nw) async {
          final walletAddr = nw['address'];
          final publicKey = nw['publicKey'];

          final accountNew = DChatAccount(
            walletAddr,
            publicKey,
            Uint8List.fromList(hexDecode(nw['seed'])),
            ClientEventListener(BlocProvider.of<ClientBloc>(context)),
          );
          final localStorage = LocalStorage();
          await localStorage.set(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS, accountNew.wallet.address);

          final localAuth = await LocalAuthenticationService.instance;
          if (localAuth.isProtectionEnabled) {
            // nothing, since the above
            // `await wallet.exportWallet(password)`
            // steps have saved the password.
          }

          account.client.disConnect();
          changeAccount(accountNew);
          // Must be behind `changeAccount()`, since you need to use the new `db` object.
          final currentUser = await ContactSchema.getContactByAddress(db, publicKey);
          if (currentUser == null) {
            DateTime now = DateTime.now();
            await ContactSchema(
              type: ContactType.me,
              clientAddress: publicKey,
              nknWalletAddress: walletAddr,
              createdTime: now,
              updatedTime: now,
              profileVersion: uuid.v4(),
            ).createContact(db);
          }
          showToast(NL10ns.of(context).account_switching_completed);
          setState(() {
            nickName = accountNew.client.myChatId.substring(0, 6);
            _walletDefault = wallet;
          });
        },
        onError: (pwdIncorrect, e) {
          if (pwdIncorrect) {
            showToast(NL10ns.of(context).tip_password_error);
          }
        });
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
                      InkWell(
                        onTap: () {
                          if (widget?.arguments?.avatarFilePath != null) {
                            Navigator.push(context, CustomRoute(PhotoPage(arguments: widget.arguments.avatarFilePath)));
                          }
                        },
                        child: Container(
                          child: widget.arguments.avatarWidget(
                            db,
                            backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                            size: 48,
                            fontColor: DefaultTheme.fontLightColor,
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
                          child: SvgPicture.asset('assets/icons/camera.svg', width: 16),
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
                          decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              FlatButton(
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                                onPressed: showChangeSelfNameDialog,
                                child: Row(
                                  children: <Widget>[
                                    loadAssetIconsImage('user', color: DefaultTheme.primaryColor, width: 24),
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
                                    SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
                                  ],
                                ),
                              ).sized(h: 48),
                              FlatButton(
                                padding: const EdgeInsets.only(left: 16, right: 16),
                                onPressed: () {
                                  Navigator.pushNamed(context, ShowMyChatID.routeName);
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    loadAssetChatPng('chat_id', color: DefaultTheme.primaryColor, width: 22),
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
                                        accountChatId.substring(0, 8) + "...",
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
                                padding: const EdgeInsets.only(left: 16, right: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                                onPressed: () {
                                  Navigator.pushNamed(context, ShowMyChatAddress.routeName,
                                      arguments: _walletDefault?.address ?? widget.arguments.nknWalletAddress);
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    loadAssetIconsImage(
                                      'wallet',
                                      color: DefaultTheme.primaryColor,
                                      width: 24,
                                    ),
                                    SizedBox(width: 10),
                                    Label(
                                      NL10ns.of(context).wallet_address,
                                      type: LabelType.bodyRegular,
                                      color: DefaultTheme.fontColor1,
                                      height: 1,
                                    ),
                                    SizedBox(width: 20),
                                    Expanded(
                                      child: Label(
                                        (_walletDefault?.address ?? widget.arguments.nknWalletAddress).substring(0, 8) + "...",
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
                              FlatButton(
                                padding: const EdgeInsets.only(left: 16, right: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                                onPressed: _selectWallets,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    loadAssetIconsImage('wallet', color: DefaultTheme.primaryColor, width: 24),
                                    _walletDefault == null
                                        ? BlocBuilder<WalletsBloc, WalletsState>(
                                            builder: (ctx, state) {
                                              if (state is WalletsLoaded) {
                                                final wallet = state.wallets.firstWhere((w) {
                                                  return w.address == widget.arguments.nknWalletAddress;
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
                                        NL10ns.of(context).change_default_chat_wallet,
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

  Widget _personListView(){
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),),
        color: DefaultTheme.backgroundColor6,
      ),
      height: MediaQuery.of(context).size.height,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 4, bottom: 32),
        itemCount: 8,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0){
            return Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Stack(
                    children: <Widget>[
                      InkWell(
                        onTap: () {
                          if (widget.arguments.avatarFilePath != null) {
                            Navigator.push(context, CustomRoute(PhotoPage(arguments: widget.arguments.avatarFilePath)));
                          }
                        },
                        child: Container(
                          child: widget.arguments.avatarWidget(
                            db,
                            backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                            size: 48,
                            fontColor: DefaultTheme.fontLightColor,
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
                            File savedImg = await getHeaderImage(accountPubkey);
                            setState(() {
                              widget.arguments.avatar = savedImg;
                            });
                            await widget.arguments.setAvatar(db, accountPubkey, savedImg);
                            _chatBloc.add(RefreshMessages());
                          },
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Label(
                        widget.arguments.nickName ?? '',
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
          }
          else if (index == 1){
            return Container(
              decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.symmetric(horizontal: 12,vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FlatButton(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                    onPressed: () {
                      _firstNameController.text = widget.arguments.name;
                      _detailChangeName(context);
                    },
                    child: Row(
                      children: <Widget>[
                        loadAssetIconsImage('user', color: DefaultTheme.primaryColor, width: 24),
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
                            getName(),
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
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                    onPressed: () {
                      Navigator.pushNamed(context, ChatProfile.routeName, arguments: widget.arguments);
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
                            widget.arguments.clientAddress.substring(0, 8) + '...',
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
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                BodyBox(
                  color: DefaultTheme.backgroundColor6,
                  padding: EdgeInsets.only(top: 20),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[

                            SizedBox(height: 40),
                            getStatusView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).pad(t: 28),
              ],
            );
          }
          else if (index == 2){
            return SizedBox(height: 10);
          }
          else if (index == 3){
            return Container(
              decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                onPressed: () async {
                  setState(() {
                    _burnSelected = !_burnSelected;
                    _saveAndSendBurnMessage();
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  padding: _burnSelected ? 0.symm(v: 5.5) : 0.pad(),
                  child: Column(
                    mainAxisAlignment: _burnSelected ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: [
                          loadAssetWalletImage('xiaohui', color: DefaultTheme.primaryColor, width: 24),
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
                                _saveAndSendBurnMessage();
                              });
                            },
                          ),
//                                        SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
                        ],
                      ),
                      _burnSelected
                          ? Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.alarm_on, size: 24, color: Colours.blue_0f).pad(r: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(
                                  (!_burnSelected || _burnIndex < 0)
                                      ? NL10ns.of(context).off
                                      : BurnViewUtil.getStringFromSeconds(context, BurnViewUtil.burnValueArray[_burnIndex].inSeconds),
                                  type: LabelType.bodyRegular,
                                  color: Colours.gray_81,
                                  fontWeight: FontWeight.w700,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Slider(
                                  value: _burnIndex.d,
                                  min: 0,
                                  max: (BurnViewUtil.burnValueArray.length - 1).d,
                                  activeColor: Colours.blue_0f,
                                  inactiveColor: Colours.gray_81,
                                  divisions: BurnViewUtil.burnValueArray.length - 1,
                                  label: BurnViewUtil.burnTextArray(context)[_burnIndex],
                                  onChanged:(value){
                                    setState(() {
                                      _burnIndex = value.round();
                                      if (_burnIndex > BurnViewUtil.burnValueArray.length - 1) {
                                        _burnIndex = BurnViewUtil.burnValueArray.length - 1;
                                      }
                                    });
                                  },
                                  onChangeEnd:(value){
                                    print('Value is'+value.toString());
                                    _saveAndSendBurnMessage();
                                  }
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
          }
          else if (index == 4){
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
          }
          else if (index == 5){
            return Container(
              decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                onPressed: () async {
                  setState(() {
                    _acceptNotification = !_acceptNotification;
                    _saveAndSendDeviceToken();
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  padding: _acceptNotification ? 0.symm(v: 5.5) : 0.pad(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: [
                          loadAssetIconsImage('notification_bell', color: DefaultTheme.primaryColor, width: 24),
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
//                                        SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
                        ],
                      ),
                    ],
                  ),
                ),
              ).sized(h: 50, w: double.infinity),
            );
          }
          else if (index == 6){
            if (Platform.isAndroid){
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
          }
          else if (index == 7){
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: FlatButton(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
                child: Container(
                  width: double.infinity,
                  child: Row(
                    children: <Widget>[
                      SvgPicture.asset('assets/icons/chat.svg', width: 24, color: DefaultTheme.primaryColor),
//                                      loadAssetChatPng('send_message', width: 22),
                      SizedBox(width: 10),
                      Label(NL10ns.of(context).send_message, type: LabelType.bodyRegular, color: DefaultTheme.fontColor1),
                      Spacer(),
                      SvgPicture.asset('assets/icons/right.svg', width: 24, color: DefaultTheme.fontColor2)
                    ],
                  ),
                ),
                onPressed: () {
//                                  _setContactOptions();
                  Navigator.of(context)
                      .pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: widget.arguments));
                },
              ).sized(h: 50, w: double.infinity),
            );
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
        title: '',
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: _personListView()
    );
  }
}
