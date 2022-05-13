import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactAddScreen extends StatefulWidget {
  static final String routeName = "contact/add";

  static Future go(BuildContext context) {
    return Navigator.pushNamed(context, routeName);
  }

  @override
  ContactAddScreenState createState() => new ContactAddScreenState();
}

class ContactAddScreenState extends State<ContactAddScreen> with Tag {
  GlobalKey _formKey = new GlobalKey<FormState>();

  bool _formValid = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _clientAddressController = TextEditingController();
  TextEditingController _walletAddressController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _clientAddressFocusNode = FocusNode();
  FocusNode _walletAddressFocusNode = FocusNode();
  FocusNode _notesFocusNode = FocusNode();

  File? _headImage;

  @override
  void initState() {
    super.initState();
  }

  _selectAvatarPicture() async {
    String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: null, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    File? picked = await MediaPicker.pickImage(
      cropStyle: CropStyle.rectangle,
      cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      bestSize: MessageSchema.avatarBestSize,
      maxSize: MessageSchema.avatarMaxSize,
      savePath: savePath,
    );
    if (picked == null || !picked.existsSync()) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    }

    setState(() {
      _headImage = picked;
    });
  }

  formatQrDate(String? clientAddress) async {
    logger.i("$TAG - QR_DATA - $clientAddress");
    if (clientAddress == null || clientAddress.isEmpty) return;

    String nickName = ContactSchema.getDefaultName(clientAddress);
    String? walletAddress;
    try {
      String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
      if (pubKey?.isNotEmpty == true) {
        walletAddress = await Wallet.pubKeyToWalletAddr(pubKey!);
      }
    } catch (e) {
      handleError(e);
    }
    logger.i("$TAG - QR_DATA_DECODE - nickname:$nickName - clientAddress:$clientAddress - walletAddress:$walletAddress");
    if (walletAddress == null || !Validate.isNknAddressOk(walletAddress)) {
      ModalDialog.of(Global.appContext).show(
        content: Global.locale((s) => s.error_unknown_nkn_qrcode),
        hasCloseButton: true,
      );
      return;
    }

    setState(() {
      _nameController.text = nickName;
      _clientAddressController.text = clientAddress;
      _walletAddressController.text = walletAddress ?? "";
    });
  }

  _saveContact(BuildContext context) async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String clientAddress = _clientAddressController.text;
      String note = _notesController.text;

      String defaultName = ContactSchema.getDefaultName(clientAddress);
      String? remarkName = _nameController.text != defaultName ? _nameController.text : null;

      String? remarkAvatar = _headImage?.path.isNotEmpty == true ? Path.convert2Local(_headImage?.path) : null;

      logger.i("$TAG - _saveContact -\n clientAddress:$clientAddress,\n note:$note,\n firstName:$defaultName,\n remarkName:$remarkName,\n remarkAvatar:$remarkAvatar");

      ContactSchema? schema = await ContactSchema.createByType(clientAddress, type: ContactType.friend);
      if (schema == null) return;
      schema.firstName = defaultName;
      schema.data = {
        'firstName': remarkName,
        'lastName': "",
        'avatar': remarkAvatar,
        "notes": note,
      };

      ContactSchema? exist = await contactCommon.queryByClientAddress(schema.clientAddress);
      if (exist != null) {
        if (exist.type == ContactType.friend) {
          Toast.show(Global.locale((s) => s.add_user_duplicated, ctx: context));
          Loading.dismiss();
          return;
        } else {
          bool success1 = await contactCommon.setType(exist.id, ContactType.friend, notify: true);
          if (success1) exist.type = ContactType.friend;
          bool success2 = await contactCommon.setRemarkName(exist, remarkName ?? "", "", notify: true);
          if (success2) exist.data?['firstName'] = remarkName ?? "";
          bool success3 = await contactCommon.setRemarkAvatar(exist, remarkAvatar ?? "", notify: true);
          if (success3) exist.data?['avatar'] = remarkAvatar ?? "";
          bool success4 = await contactCommon.setNotes(exist, note, notify: true);
          if (success4) exist.data?['notes'] = note;
        }
      } else {
        ContactSchema? added = await contactCommon.add(schema, notify: true, checkDuplicated: false);
        if (added == null) {
          Toast.show(Global.locale((s) => s.failure, ctx: context));
          Loading.dismiss();
          return;
        }
      }
      Loading.dismiss();
      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double avatarSize = 80;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Global.locale((s) => s.add_new_contact, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg(
              'scan',
              width: 24,
              color: application.theme.backgroundLightColor,
            ),
            onPressed: () async {
              // permission
              PermissionStatus permissionStatus = await Permission.camera.request();
              if (permissionStatus != PermissionStatus.granted) return;
              // scan
              Navigator.pushNamed(context, ScannerScreen.routeName).then((value) {
                formatQrDate(value?.toString());
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.always,
        onChanged: () {
          setState(() {
            _formValid = (_formKey.currentState as FormState).validate();
          });
        },
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          child: Stack(
                            children: <Widget>[
                              _headImage == null
                                  ? CircleAvatar(
                                      radius: avatarSize / 2,
                                      backgroundColor: application.theme.backgroundColor2,
                                      child: Asset.iconSvg('user', color: application.theme.fontColor2),
                                    )
                                  : CircleAvatar(
                                      radius: avatarSize / 2,
                                      backgroundImage: FileImage(_headImage!),
                                    ),
                              InkWell(
                                onTap: _selectAvatarPicture,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: CircleAvatar(
                                    radius: avatarSize / 5,
                                    backgroundColor: application.theme.primaryColor,
                                    child: Asset.iconSvg(
                                      'camera',
                                      color: application.theme.backgroundLightColor,
                                      width: avatarSize / 5,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Label(
                          Global.locale((s) => s.nickname, ctx: context),
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: Global.locale((s) => s.input_name, ctx: context),
                          validator: Validator.of(context).contactName(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_clientAddressFocusNode),
                        ),
                        SizedBox(height: 14),
                        Label(
                          Global.locale((s) => s.d_chat_address, ctx: context),
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _clientAddressController,
                          focusNode: _clientAddressFocusNode,
                          hintText: Global.locale((s) => s.input_d_chat_address, ctx: context),
                          validator: Validator.of(context).pubKeyNKN(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_walletAddressFocusNode),
                          // multi: true,
                          maxLines: 10,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              Global.locale((s) => s.wallet_address, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${Global.locale((s) => s.optional, ctx: context)})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _walletAddressController,
                          focusNode: _walletAddressFocusNode,
                          hintText: Global.locale((s) => s.input_wallet_address, ctx: context),
                          validator: Validator.of(context).addressNKNOrEmpty(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_notesFocusNode),
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              Global.locale((s) => s.notes, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${Global.locale((s) => s.optional, ctx: context)})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          hintText: Global.locale((s) => s.input_notes, ctx: context),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Button(
                        text: Global.locale((s) => s.save_contact, ctx: context),
                        width: double.infinity,
                        disabled: !_formValid,
                        onPressed: () {
                          _saveContact(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
