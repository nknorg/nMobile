import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
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
import 'package:nmobile/utils/utils.dart';

class ContactAddScreen extends StatefulWidget {
  static final String routeName = "contact/add";

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

  File _headImage;

  @override
  void initState() {
    super.initState();
  }

  _selectAvatarPicture() async {
    File picked = await MediaPicker.pick(
      mediaType: MediaType.image,
      source: ImageSource.gallery,
      crop: true,
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

  formatQrDate(String clientAddress) async {
    logger.d("QR_DATA - $clientAddress");
    if (clientAddress == null || clientAddress.isEmpty) return;

    String nickName = ContactSchema.getDefaultName(clientAddress);
    String walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));

    logger.d("QR_DATA_DECODE - nickname:$nickName - clientAddress:$clientAddress - walletAddress:$walletAddress");

    setState(() {
      _nameController.text = nickName;
      _clientAddressController.text = clientAddress;
      _walletAddressController.text = walletAddress;
    });
  }

  // TODO:GG
  _saveContact(BuildContext context) async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String name = _nameController.text;
      String pubKey = _clientAddressController.text;
      String address = _walletAddressController.text;
      String note = _notesController.text;
      logger.d("name:$name, pubKey:$pubKey, address:$address, note:$note");

      // String saveImagePath = 'remark_' + pubKey; // TODO:GG need??

      // String remarkPath = 'remark_' + profile.clientAddress;
      // String filePath = getLocalContactPath(remarkPath, profileInfo['avatar']);

      // REMOVE:GG
      // File avatarSaveFile = Path.getFilePathByOriginal(firstDirName, secondDirName, file)

      ContactSchema scheme = ContactSchema(
        // avatar: ,
        firstName: name,
        clientAddress: pubKey,
        nknWalletAddress: address,
        type: ContactType.friend,
        notes: note,
      );

      ContactSchema added = await contact.add(scheme);
      if (added != null) {
        Toast.show(S.of(context).failure);
        return;
      }

      // TODO:GG need??
      // Map dataInfo = Map<String, dynamic>();
      // if (_headImage != null) {
      //   dataInfo['avatar'] = _headImage.path;
      // }
      // if (name != null && name.length > 0) {
      //   if (name != _scanNickName) {
      //     dataInfo['first_name'] = name;
      //   }
      // }
      // if (note != null && note.length > 0) {
      //   dataInfo['notes'] = note;
      // }
      // await ContactDataCenter.saveRemarkProfile(scheme, dataInfo);

      // eventBus.fire(AddContactEvent()); // TODO:GG update home_list
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
                formatQrDate(value);
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
                                      backgroundImage: FileImage(_headImage),
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
                          hintText: _localizations.input_pubKey,
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
                          validator: Validator.of(context).addressNKN(),
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
