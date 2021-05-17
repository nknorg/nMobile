import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/asset.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/screens/common/scanner.dart';

class ContactAddScreen extends StatefulWidget {
  static final String routeName = "contact/add";

  @override
  ContactAddScreenState createState() => new ContactAddScreenState();
}

class ContactAddScreenState extends State<ContactAddScreen> {
  GlobalKey _formKey = new GlobalKey<FormState>();

  bool _formValid = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _pubKeyController = TextEditingController();
  TextEditingController _addressController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _pubKeyFocusNode = FocusNode();
  FocusNode _addressFocusNode = FocusNode();
  FocusNode _notesFocusNode = FocusNode();

  File _imageHeaderFile;

  String scanNickName;

  @override
  void initState() {
    super.initState();
  }

  String formatName(String qm) {
    // String nickName, chatId;
    // try {
    //   if (qm.contains('@')) {
    //     nickName = qm.substring(0, qm.lastIndexOf('@'));
    //     chatId = qm.substring(qm.lastIndexOf('@') + 1, qm.length);
    //   } else if (qm.contains('.')) {
    //     nickName = qm.substring(0, qm.lastIndexOf('.'));
    //     chatId = qm.substring(qm.lastIndexOf('.') + 1, qm.length);
    //   } else {
    //     nickName = qm.toString().substring(0, 6);
    //     chatId = qm.toString();
    //   }
    //
    //   scanNickName = nickName;
    //
    //   setState(() {
    //     _nameController.text = nickName;
    //     _pubKeyController.text = chatId;
    //   });
    //
    //   if (chatId.indexOf('.') == -1) {
    //     NknWalletPlugin.pubKeyToWalletAddr(chatId).then((value) {
    //       setState(() {
    //         _addressController.text = value;
    //       });
    //     });
    //   }
    // } catch (e) {}
    // // todo Check return '';
    return '';
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
                if (value != null) {
                  formatName(value);
                }
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
                              _imageHeaderFile == null
                                  ? CircleAvatar(
                                      radius: avatarSize / 2,
                                      backgroundColor: application.theme.backgroundColor2,
                                      child: Asset.iconSvg('user', color: application.theme.fontColor2),
                                    )
                                  : CircleAvatar(
                                      radius: avatarSize / 2,
                                      backgroundImage: FileImage(_imageHeaderFile),
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
                            FocusScope.of(context).requestFocus(_pubKeyFocusNode);
                          },
                        ),
                        SizedBox(height: 14),
                        Label(
                          _localizations.d_chat_address,
                          type: LabelType.h3,
                          textAlign: TextAlign.start,
                        ),
                        FormText(
                          controller: _pubKeyController,
                          focusNode: _pubKeyFocusNode,
                          hintText: _localizations.input_pubKey,
                          validator: Validator.of(context).pubKey(),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_addressFocusNode);
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
                          controller: _addressController,
                          focusNode: _addressFocusNode,
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

  _saveContact(BuildContext context) async {
    // if ((_formKey.currentState as FormState).validate()) {
    //   (_formKey.currentState as FormState).save();
    //   String name = _nameController.text;
    //   String pubKey = _pubKeyController.text;
    //   String address = _addressController.text;
    //   String note = _notesController.text;
    //   ContactSchema contact = ContactSchema(
    //       firstName: name,
    //       clientAddress: pubKey,
    //       nknWalletAddress: address,
    //       type: ContactType.friend,
    //       notes: note);
    //   var result = await contact.insertContact();
    //   contact.setFriend(true);
    //
    //   Map dataInfo = Map<String, dynamic>();
    //   if (imageHeaderFile != null) {
    //     dataInfo['avatar'] = imageHeaderFile.path;
    //   }
    //   if (name != null && name.length > 0) {
    //     if (name != scanNickName){
    //       dataInfo['first_name'] = name;
    //     }
    //   }
    //   if (note != null && note.length > 0) {
    //     dataInfo['notes'] = note;
    //   }
    //   await ContactDataCenter.saveRemarkProfile(contact, dataInfo);
    //
    //   eventBus.fire(AddContactEvent());
    //   Navigator.pop(context);
    // }
  }

  _selectAvatarPicture() async {
    // String address = _pubKeyController.text;
    // String saveImagePath = 'remark_' + address;
    // File savedImg = await getHeaderImage(saveImagePath);
    // if (savedImg == null) return;
    //
    // if (savedImg == null) {
    //   showToast('Open camera or MediaLibrary for nMobile to update your profile');
    // } else {
    //   if (mounted) {
    //     setState(() {
    //       imageHeaderFile = savedImg;
    //     });
    //   }
    // }
  }

// String createContactFilePath(File file) {
//   String name = hexEncode(md5.convert(file.readAsBytesSync()).bytes);
//   Directory rootDir = Global.applicationRootDirectory;
//   String p = join(rootDir.path, NKNClientCaller.currentChatId, 'contact');
//   Directory dir = Directory(p);
//   if (!dir.existsSync()) {
//     dir.createSync(recursive: true);
//   } else {}
//   String fullName = file?.path?.split('/')?.last;
//   String fileName;
//   String fileExt;
//   int index = fullName.lastIndexOf('.');
//   if (index > -1) {
//     fileExt = fullName?.split('.')?.last;
//     fileName = fullName?.substring(0, index);
//   } else {
//     fileName = fullName;
//   }
//   String path = join(rootDir.path, dir.path, name + '.' + fileExt);
//   return path;
// }
}
