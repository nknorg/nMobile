import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/contact/contact.dart';
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
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class ContactAddScreen extends StatefulWidget {
  static final String routeName = "contact/add";

  static Future go(BuildContext context) {
    return Navigator.pushNamed(context, routeName);
  }

  @override
  ContactAddScreenState createState() => new ContactAddScreenState();
}

class ContactAddScreenState extends State<ContactAddScreen> {
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
    File? picked = await MediaPicker.pick(
      mediaType: MediaType.image,
      source: ImageSource.gallery,
      crop: true,
      returnPath: join(Global.applicationRootDirectory.path, Path.getLocalContactAvatar(hexEncode(chatCommon.publicKey!), "${Uuid().v4()}.jpeg")),
    );
    if (picked == null) {
      // Toast.show("Open camera or MediaLibrary for nMobile to update your profile");
      return;
    }

    if (mounted) {
      setState(() {
        _headImage = picked;
      });
    }
  }

  formatQrDate(String? clientAddress) async {
    logger.d("QR_DATA - $clientAddress");
    if (clientAddress == null || clientAddress.isEmpty) return;

    String nickName = ContactSchema.getDefaultName(clientAddress);
    String? walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));

    logger.d("QR_DATA_DECODE - nickname:$nickName - clientAddress:$clientAddress - walletAddress:$walletAddress");
    if (walletAddress == null || !verifyAddress(walletAddress)) {
      ModalDialog.of(this.context).show(
        content: S.of(this.context).error_unknown_nkn_qrcode,
        hasCloseButton: true,
      );
      return;
    }

    setState(() {
      _nameController.text = nickName;
      _clientAddressController.text = clientAddress;
      _walletAddressController.text = walletAddress;
    });
  }

  _saveContact(BuildContext context) async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String clientAddress = _clientAddressController.text;
      String? walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
      String note = _notesController.text;

      String remarkName = _nameController.text;
      String defaultName = ContactSchema.getDefaultName(clientAddress);

      String? remarkAvatar = _headImage == null ? null : Path.getLocalContactAvatar(hexEncode(chatCommon.publicKey!), Path.getFileName(_headImage!.path));

      logger.d("_saveContact -\n clientAddress:$clientAddress,\n walletAddress:$walletAddress,\n note:$note,\n firstName:$defaultName,\n remarkName:$remarkName,\n remarkAvatar:$remarkAvatar");

      ContactSchema scheme = ContactSchema(
        clientAddress: clientAddress,
        nknWalletAddress: walletAddress,
        type: ContactType.friend,
        notes: note,
        // avatar: defaultAvatar,
        firstName: defaultName,
        extraInfo: {
          'firstName': remarkName,
          'avatar': remarkAvatar,
        },
      );

      ContactSchema? added = await contactCommon.add(scheme);
      if (added == null) {
        Toast.show(S.of(context).failure);
        return;
      }

      Loading.dismiss();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double avatarSize = 80;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: _localizations.add_new_contact,
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg(
              'scan',
              width: 24,
              color: application.theme.backgroundLightColor,
            ),
            onPressed: () async {
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
              flex: 1,
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
                          _localizations.nickname,
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: _localizations.input_name,
                          validator: Validator.of(context).contactName(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_clientAddressFocusNode);
                          },
                        ),
                        SizedBox(height: 14),
                        Label(
                          _localizations.d_chat_address,
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _clientAddressController,
                          focusNode: _clientAddressFocusNode,
                          hintText: _localizations.input_d_chat_address,
                          validator: Validator.of(context).pubKey(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_walletAddressFocusNode);
                          },
                          // multi: true,
                          maxLines: 10,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              _localizations.wallet_address,
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${_localizations.optional})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _walletAddressController,
                          focusNode: _walletAddressFocusNode,
                          hintText: _localizations.input_wallet_address,
                          validator: Validator.of(context).addressNKN(), // TODO:GG or empty
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_notesFocusNode);
                          },
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              _localizations.notes,
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            Label(
                              ' (${_localizations.optional})',
                              type: LabelType.bodyLarge,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        FormText(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          hintText: _localizations.input_notes,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(null);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Button(
                          text: _localizations.save_contact,
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
            ),
          ],
        ),
      ),
    );
  }
}
