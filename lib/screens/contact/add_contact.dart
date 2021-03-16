import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/event/eventbus.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/data/contact_data_center.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class AddContact extends StatefulWidget {
  static final String routeName = "AddContact";

  @override
  AddContactState createState() => new AddContactState();
}

class AddContactState extends State<AddContact> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _pubKeyFocusNode = FocusNode();
  FocusNode _addressFocusNode = FocusNode();
  FocusNode _notesFocusNode = FocusNode();

  TextEditingController _nameController = TextEditingController();
  TextEditingController _pubKeyController = TextEditingController();
  TextEditingController _addressController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  File imageHeaderFile;

  String scanNickName;

  @override
  void initState() {
    super.initState();
  }

  String formatName(String qm) {
    String nickName, chatId;
    try {
      if (qm.contains('@')) {
        nickName = qm.substring(0, qm.lastIndexOf('@'));
        chatId = qm.substring(qm.lastIndexOf('@') + 1, qm.length);
      } else if (qm.contains('.')) {
        nickName = qm.substring(0, qm.lastIndexOf('.'));
        chatId = qm.substring(qm.lastIndexOf('.') + 1, qm.length);
      } else {
        nickName = qm.toString().substring(0, 6);
        chatId = qm.toString();
      }

      scanNickName = nickName;

      setState(() {
        _nameController.text = nickName;
        _pubKeyController.text = chatId;
      });

      if (chatId.indexOf('.') == -1) {
        NknWalletPlugin.pubKeyToWalletAddr(chatId).then((value) {
          setState(() {
            _addressController.text = value;
          });
        });
      }
    } catch (e) {}
    // todo Check return '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NL10ns.of(context).add_new_contact,
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'scan',
            width: 24,
            color: DefaultTheme.backgroundLightColor,
          ),
          onPressed: () async {
            Navigator.of(context).pushNamed(ScannerScreen.routeName).then((value) => {
              if (value != null) {
                formatName(value),
              }
            });
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          color: DefaultTheme.backgroundLightColor,
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Container(
                  child: Form(
                    key: _formKey,
                    autovalidate: true,
                    onChanged: () {
                      setState(() {
                        _formValid =
                            (_formKey.currentState as FormState).validate();
                      });
                    },
                    child: Flex(
                      direction: Axis.vertical,
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              child: Flex(
                                direction: Axis.vertical,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Container(
                                        width: 80,
                                        height: 80,
                                        child: Stack(
                                          children: <Widget>[
                                            imageHeaderFile == null
                                                ? CircleAvatar(
                                                    radius: 80,
                                                    backgroundColor:
                                                        DefaultTheme
                                                            .backgroundColor1,
                                                    child: loadAssetIconsImage(
                                                        'user',
                                                        color: DefaultTheme
                                                            .fontColor2),
                                                  )
                                                : CircleAvatar(
                                                    radius: 80,
                                                    backgroundImage: FileImage(
                                                        imageHeaderFile),
                                                  ),
                                            InkWell(
                                              onTap: _updatePic,
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor:
                                                      DefaultTheme.primaryColor,
                                                  child: loadAssetIconsImage(
                                                    'camera',
                                                    color: DefaultTheme
                                                        .backgroundLightColor,
                                                    width: 14,
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
                                  Expanded(
                                    flex: 0,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 32),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Label(
                                            NL10ns.of(context).nickname,
                                            type: LabelType.h3,
                                            textAlign: TextAlign.start,
                                          ),
                                          Textbox(
                                            hintText:
                                                NL10ns.of(context).input_name,
                                            focusNode: _nameFocusNode,
                                            controller: _nameController,
                                            onFieldSubmitted: (_) {
                                              FocusScope.of(context)
                                                  .requestFocus(
                                                      _pubKeyFocusNode);
                                            },
                                            textInputAction:
                                                TextInputAction.next,
                                            validator: Validator.of(context)
                                                .contactName(),
                                          ),
                                          SizedBox(height: 14.h),
                                          Label(
                                            NL10ns.of(context).d_chat_address,
                                            type: LabelType.h3,
                                            textAlign: TextAlign.start,
                                          ),
                                          Textbox(
                                            focusNode: _pubKeyFocusNode,
                                            controller: _pubKeyController,
                                            maxLines: 2,
                                            multi: true,
                                            hintText:
                                                NL10ns.of(context).input_pubKey,
                                            onFieldSubmitted: (_) {
                                              FocusScope.of(context)
                                                  .requestFocus(
                                                      _addressFocusNode);
                                            },
                                            textInputAction:
                                                TextInputAction.next,
                                            validator:
                                                Validator.of(context).pubKey(),
                                          ),
                                          Row(
                                            children: <Widget>[
                                              Label(
                                                NL10ns.of(context)
                                                    .wallet_address,
                                                type: LabelType.h3,
                                                textAlign: TextAlign.start,
                                              ),
                                              Label(
                                                ' (${NL10ns.of(context).optional})',
                                                type: LabelType.bodyLarge,
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                          Textbox(
                                            focusNode: _addressFocusNode,
                                            controller: _addressController,
                                            hintText: NL10ns.of(context)
                                                .input_wallet_address,
                                          ),
                                          Row(
                                            children: <Widget>[
                                              Label(
                                                NL10ns.of(context).notes,
                                                type: LabelType.h3,
                                                textAlign: TextAlign.start,
                                              ),
                                              Label(
                                                ' (${NL10ns.of(context).optional})',
                                                type: LabelType.bodyLarge,
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                          Textbox(
                                            focusNode: _notesFocusNode,
                                            controller: _notesController,
                                            hintText:
                                                NL10ns.of(context).input_notes,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 0,
                          child: SafeArea(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8, top: 8),
                              child: Column(
                                children: <Widget>[
                                  Padding(
                                    padding:
                                        EdgeInsets.only(left: 30, right: 30),
                                    child: Button(
                                      text: NL10ns.of(context).save_contact,
                                      disabled: !_formValid,
                                      onPressed: () {
                                        _saveAction(context);
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
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _saveAction(BuildContext context) async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      String name = _nameController.text;
      String pubKey = _pubKeyController.text;
      String address = _addressController.text;
      String note = _notesController.text;
      ContactSchema contact = ContactSchema(
          firstName: name,
          clientAddress: pubKey,
          nknWalletAddress: address,
          type: ContactType.friend,
          notes: note);
      var result = await contact.insertContact();
      contact.setFriend(true);

      Map dataInfo = Map<String, dynamic>();
      if (imageHeaderFile != null) {
        dataInfo['avatar'] = imageHeaderFile.path;
      }
      if (name != null && name.length > 0) {
        if (name != scanNickName){
          dataInfo['first_name'] = name;
        }
      }
      if (note != null && note.length > 0) {
        dataInfo['notes'] = note;
      }
      await ContactDataCenter.saveRemarkProfile(contact, dataInfo);

      eventBus.fire(AddContactEvent());
      Navigator.pop(context);
    }
  }

  _updatePic() async {
    String address = _pubKeyController.text;
    String saveImagePath = 'remark_' + address;
    File savedImg = await getHeaderImage(saveImagePath);
    if (savedImg == null) return;

    if (savedImg == null) {
      showToast(
          'Open camera or MediaLibrary for nMobile to update your profile');
    } else {
      if (mounted) {
        setState(() {
          imageHeaderFile = savedImg;
        });
      }
    }
  }
  //
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
