import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
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
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactAddScreen extends BaseStateFulWidget {
  static final String routeName = "contact/add";

  static Future go(BuildContext? context) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName);
  }

  @override
  ContactAddScreenState createState() => new ContactAddScreenState();
}

class ContactAddScreenState extends BaseStateFulWidgetState<ContactAddScreen> with Tag {
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

  @override
  void onRefreshArguments() {}

  _selectAvatarPicture() async {
    String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: null, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    File? picked = await MediaPicker.pickImage(
      cropStyle: CropStyle.rectangle,
      cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      maxSize: Settings.sizeAvatarMax,
      bestSize: Settings.sizeAvatarBest,
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
    // wallet_address
    String? walletAddress;
    try {
      String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
      if (Validate.isNknPublicKey(pubKey)) {
        walletAddress = await Wallet.pubKeyToWalletAddr(pubKey!);
      }
    } catch (e, st) {
      handleError(e, st);
    }
    logger.i("$TAG - QR_DATA_DECODE - clientAddress:$clientAddress - walletAddress:$walletAddress");
    if (walletAddress == null || !Validate.isNknAddressOk(walletAddress)) {
      ModalDialog.of(Settings.appContext).show(
        content: Settings.locale((s) => s.error_unknown_nkn_qrcode),
        hasCloseButton: true,
      );
      return;
    }
    // state
    setState(() {
      _clientAddressController.text = clientAddress.replaceAll("\n", "").trim();
      _walletAddressController.text = walletAddress?.replaceAll("\n", "").trim() ?? "";
    });
  }

  _saveContact(BuildContext context) async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();
      // input
      String address = _clientAddressController.text.replaceAll("\n", "").trim();
      String? remarkAvatar = _headImage?.path.isNotEmpty == true ? Path.convert2Local(_headImage?.path) : null;
      String? remarkName = _nameController.text.isNotEmpty ? _nameController.text : null;
      String note = _notesController.text;
      logger.i("$TAG - _saveContact -\n address:$address,\n note:$note,\n remarkName:$remarkName,\n remarkAvatar:$remarkAvatar");
      // exist
      String? clientAddress = await contactCommon.resolveClientAddress(address);
      ContactSchema? exist = await contactCommon.query(clientAddress);
      if ((exist != null) && (exist.type == ContactType.friend)) {
        Toast.show(Settings.locale((s) => s.add_user_duplicated, ctx: context));
        Loading.dismiss();
        return;
      } else if (exist != null) {
        bool success = await contactCommon.setType(exist.address, ContactType.friend, notify: true);
        if (success) exist.type = ContactType.friend;
        success = await contactCommon.setOtherRemarkName(exist.address, remarkName, notify: true);
        if (success) exist.remarkName = remarkName ?? "";
        var data = await contactCommon.setOtherRemarkAvatar(exist.address, remarkAvatar, notify: true);
        if (data != null) exist.data = data;
        data = await contactCommon.setNotes(exist.address, note, notify: true);
        if (data != null) exist.data = data;
        Loading.dismiss();
      } else {
        ContactSchema? schema = ContactSchema.create(clientAddress, ContactType.friend);
        if (schema != null) {
          schema.remarkName = remarkName ?? "";
          await schema.nknWalletAddress;
          schema.data = {"remarkAvatar": remarkAvatar, "notes": note};
        }
        ContactSchema? added = await contactCommon.add(schema, notify: true);
        if (added == null) {
          logger.i("$TAG - _saveContact - schema:$schema");
          Toast.show(Settings.locale((s) => s.failure, ctx: context));
          Loading.dismiss();
          return;
        }
        Loading.dismiss();
      }
      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double avatarSize = 80;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Settings.locale((s) => s.add_new_contact, ctx: context),
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
                formatQrDate(value?.toString().replaceAll("\n", "").trim());
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
                        Row(
                          children: <Widget>[
                            Label(
                              Settings.locale((s) => s.nickname, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${Settings.locale((s) => s.optional, ctx: context)})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: Settings.locale((s) => s.input_name, ctx: context),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_clientAddressFocusNode),
                        ),
                        SizedBox(height: 14),
                        Label(
                          Settings.locale((s) => s.d_chat_address, ctx: context),
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _clientAddressController,
                          focusNode: _clientAddressFocusNode,
                          hintText: Settings.locale((s) => s.input_d_chat_address, ctx: context),
                          validator: Validator.of(context).pubKeyNKN(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_walletAddressFocusNode),
                          // multi: true,
                          maxLines: 10,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              Settings.locale((s) => s.wallet_address, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${Settings.locale((s) => s.optional, ctx: context)})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _walletAddressController,
                          focusNode: _walletAddressFocusNode,
                          hintText: Settings.locale((s) => s.input_wallet_address, ctx: context),
                          validator: Validator.of(context).addressNKNOrEmpty(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_notesFocusNode),
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              Settings.locale((s) => s.notes, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${Settings.locale((s) => s.optional, ctx: context)})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          hintText: Settings.locale((s) => s.input_notes, ctx: context),
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
                        text: Settings.locale((s) => s.save_contact, ctx: context),
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
