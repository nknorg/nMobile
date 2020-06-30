import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/custom_router.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
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

class _ContactScreenState extends State<ContactScreen> with RouteAware {
  ChatBloc _chatBloc;
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _nameController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  FocusNode _firstNameFocusNode = FocusNode();
  GlobalKey _nameFormKey = new GlobalKey<FormState>();
  GlobalKey _notesFormKey = new GlobalKey<FormState>();
  bool _nameFormValid = false;
  bool _notesFormValid = false;
  bool _burnSelected = false;
  List<Duration> _burnValueArray = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  List<String> _burnTextArray;
  double _sliderBurnValue = 0;
  int _burnValue;
  SourceProfile _sourceProfile;
  OptionsSchema _sourceOptions;

  initAsync() async {
    _sourceProfile = widget.arguments.sourceProfile;
    setState(() {});
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
    _setContactOptions();
    NLog.d('didPop');
    super.didPop();
  }

  @override
  void initState() {
    super.initState();
    _sourceOptions = OptionsSchema(deleteAfterSeconds: widget.arguments?.options?.deleteAfterSeconds);
    initAsync();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    int burnAfterSeconds = widget.arguments.options?.deleteAfterSeconds;
    if (burnAfterSeconds != null) {
      _burnSelected = true;
      _sliderBurnValue = _burnValueArray.indexWhere((x) => x.inSeconds == burnAfterSeconds).toDouble();
      if (_sliderBurnValue < 0) {
        _sliderBurnValue = 0;
        if (burnAfterSeconds > _burnValueArray.last.inSeconds) {
          _sliderBurnValue = (_burnValueArray.length - 1).toDouble();
        }
      }
    }
    _burnValue = burnAfterSeconds;

    _nameController.text = widget.arguments.name;
    _notesController.text = widget.arguments.notes;
  }

  _setContactOptions() async {
    if (_sourceOptions?.deleteAfterSeconds != _burnValue) {
      var contact = widget.arguments;
      if (_burnSelected) {
        await contact.setBurnOptions(_burnValue);
      } else {
        await contact.setBurnOptions(null);
      }
      var sendMsg = MessageSchema.fromSendData(
        from: Global.currentClient.address,
        to: widget.arguments.clientAddress,
        contentType: ContentType.eventContactOptions,
      );
      sendMsg.isOutbound = true;
      if (_burnSelected) sendMsg.burnAfterSeconds = _burnValue;
      sendMsg.content = sendMsg.toActionContentOptionsData();
      _chatBloc.add(SendMessage(sendMsg));
    }
  }

  @override
  Widget build(BuildContext context) {
    _burnTextArray = <String>[
      NMobileLocalizations.of(context).burn_5_seconds,
      NMobileLocalizations.of(context).burn_10_seconds,
      NMobileLocalizations.of(context).burn_30_seconds,
      NMobileLocalizations.of(context).burn_1_minute,
      NMobileLocalizations.of(context).burn_5_minutes,
      NMobileLocalizations.of(context).burn_10_minutes,
      NMobileLocalizations.of(context).burn_30_minutes,
      NMobileLocalizations.of(context).burn_1_hour,
    ];

    if (widget.arguments.isMe) {
      return Scaffold(
        appBar: Header(
          title: '',
          backgroundColor: DefaultTheme.backgroundColor4,
          action: IconButton(
            icon: loadAssetIconsImage(
              'scan',
              width: 24,
              color: DefaultTheme.backgroundLightColor,
            ),
            onPressed: () async {
              showQRDialog();
            },
          ),
        ),
        body: Container(
          child: Column(
            children: <Widget>[
              Container(
                color: DefaultTheme.backgroundColor4,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    InkWell(
                      onTap: () {
                        if (widget?.arguments?.avatarFilePath != null) {
                          Navigator.push(context, CustomRoute(PhotoPage(arguments: widget.arguments.avatarFilePath)));
                        }
                      },
                      child: widget.arguments.avatarWidget(
                        backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200),
                        size: 60,
                        bottomRight: Button(
                          width: 32,
                          height: 32,
                          backgroundColor: DefaultTheme.primaryColor,
                          child: loadAssetIconsImage('camera', width: 20),
                          onPressed: () async {
                            updatePic();
                          },
                        ),
                      ),
                    ),
                    Label(widget.arguments.name, type: LabelType.h2, dark: true).pad(t: 16, b: 24),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
                  child: BodyBox(
                    padding: EdgeInsets.only(top: 32, left: 20, right: 20),
                    color: DefaultTheme.backgroundLightColor,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Label(
                            NMobileLocalizations.of(context).my_details,
                            type: LabelType.h2,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  loadAssetIconsImage('user', color: DefaultTheme.primaryColor, width: 24).pad(r: 16),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            Label(
                                              NMobileLocalizations.of(context).nickname,
                                              type: LabelType.h3,
                                              textAlign: TextAlign.start,
                                            ),
                                            InkWell(
                                              child: Label(
                                                NMobileLocalizations.of(context).edit,
                                                color: DefaultTheme.primaryColor,
                                                type: LabelType.bodyRegular,
                                              ),
                                              onTap: showChangeNameDialog,
                                            ),
                                          ],
                                        ),
                                        Textbox(
                                          padding: 0.pad(),
                                          controller: _nameController,
                                          readOnly: true,
                                          enabled: false,
                                          textInputAction: TextInputAction.next,
                                          fontSize: DefaultTheme.bodyLargeFontSize,
                                          color: Colours.gray_81,
                                          borderColor: Colours.transparent,
                                        ),
                                      ],
                                    ).pad(t: 2),
                                  ),
                                ],
                              ),
                              Container(
                                color: DefaultTheme.lineColor,
                                constraints: BoxConstraints(maxHeight: 1, minHeight: 1, maxWidth: double.infinity, minWidth: double.infinity),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  loadAssetIconsImage('wallet', color: DefaultTheme.primaryColor, width: 24).pad(r: 16),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Label(
                                              Global.currentWalletName ?? '(${NMobileLocalizations.of(context).wallet_address})',
                                              type: LabelType.h3,
                                              textAlign: TextAlign.start,
                                            ),
                                            InkWell(
                                              child: Label(
                                                NMobileLocalizations.of(context).change_default_chat_wallet,
                                                color: Colours.blue_0f,
                                                type: LabelType.bodyRegular,
                                              ),
                                              onTap: () {
                                                showToast(NMobileLocalizations.of(context).coming_soon);
                                              },
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () {
                                            copyAction(widget.arguments.nknWalletAddress);
                                          },
                                          child: Text(
                                            widget.arguments.nknWalletAddress,
                                            softWrap: false,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colours.gray_81, fontSize: DefaultTheme.bodySmallFontSize),
                                          ).pad(t: 8),
                                        ),
                                      ],
                                    ).pad(t: 2),
                                  ),
                                ],
                              ).pad(t: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  loadAssetIconsImage('key', color: DefaultTheme.primaryColor, width: 24).pad(r: 16),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Label(
                                          NMobileLocalizations.of(context).d_chat_address,
                                          type: LabelType.h4,
                                          textAlign: TextAlign.start,
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: InkWell(
                                                onTap: () {
                                                  copyAction(widget.arguments.clientAddress);
                                                },
                                                child: Text(
                                                  widget.arguments.clientAddress,
                                                  softWrap: false,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: Colours.gray_81, fontSize: DefaultTheme.bodySmallFontSize),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 0,
                                              child: InkWell(
                                                child: Label(
                                                  NMobileLocalizations.of(context).copy,
                                                  color: DefaultTheme.primaryColor,
                                                  type: LabelType.bodyRegular,
                                                ).pad(l: 3),
                                                onTap: () {
                                                  copyAction(widget.arguments.clientAddress);
                                                },
                                              ),
                                            ),
                                          ],
                                        ).pad(t: 8),
                                      ],
                                    ).pad(t: 2),
                                  ),
                                ],
                              ).pad(t: 12, b: 16),
                              Container(
                                color: DefaultTheme.lineColor,
                                constraints: BoxConstraints(maxHeight: 1, minHeight: 1, maxWidth: double.infinity, minWidth: double.infinity),
                              ),
                              Text(
                                NMobileLocalizations.of(context).my_details_desc,
                                softWrap: true,
                                style: TextStyle(color: Colours.gray_81, fontSize: DefaultTheme.bodySmallFontSize),
                              ).pad(l: 40, t: 8)
                            ],
                          ).pad(t: 24)
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
    } else {
      return Scaffold(
        appBar: Header(
          title: '',
          leading: BackButton(
            onPressed: () {
              _setContactOptions();
              Navigator.of(context).pop();
            },
          ),
          backgroundColor: DefaultTheme.backgroundColor4,
          /*action: widget.arguments.type == ContactType.stranger
              ? IconButton(
                  icon: loadAssetIconsImage(
                    'user-plus',
                    color: DefaultTheme.backgroundLightColor,
                    width: 24,
                  ),
                  onPressed: () {
                    showAction(true);
                  },
                )
              : IconButton(
                  icon: loadAssetIconsImage(
                    'user-delete',
                    color: Colours.pink_8,
                    width: 24,
                  ),
                  onPressed: () {
                    showAction(false);
                  },
                ),*/
        ),
        body: Container(
          color: DefaultTheme.backgroundColor4,
          child: Flex(direction: Axis.vertical, children: <Widget>[
            Expanded(
              flex: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(children: [
                    InkWell(
                      onTap: () {
                        if (widget.arguments.avatarFilePath != null) {
                          Navigator.push(context, CustomRoute(PhotoPage(arguments: widget.arguments.avatarFilePath)));
                        }
                      },
                      child: widget.arguments
                          .avatarWidget(
                            backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200),
                            size: 40,
                            bottomRight: Button(
                              width: 24,
                              height: 24,
                              backgroundColor: DefaultTheme.primaryColor,
                              child: loadAssetIconsImage('camera', width: 16),
                              onPressed: () async {
                                File savedImg = await getHeaderImage();
                                setState(() {
                                  widget.arguments.avatar = savedImg;
                                });
                                await widget.arguments.setAvatar(savedImg);
                                _chatBloc.add(RefreshMessages());
                              },
                            ),
                          )
                          .pad(r: 16),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Label(
                          widget.arguments.name +
                              '${_sourceProfile?.name != null && _sourceProfile.name.isNotEmpty && (widget.arguments.firstName != null && widget.arguments.firstName.isNotEmpty || widget.arguments.lastName != null && widget.arguments.lastName.isNotEmpty) ? '(${_sourceProfile?.name})' : ''}',
                          type: LabelType.h2,
                          dark: true),
                      Label(NMobileLocalizations.of(context).updated_at + ' ' + Format.timeFormat(widget.arguments.updatedTime ?? widget.arguments.createdTime),
                              type: LabelType.bodyRegular, color: DefaultTheme.successColor)
                          .pad(t: 4)
                    ]),
                  ]).pad(l: 20, t: 0, r: 20, b: 22)
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  BodyBox(
                    padding: const EdgeInsets.only(top: 40),
                    color: DefaultTheme.backgroundLightColor,
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).nickname,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    InkWell(
                                      child: Label(
                                        NMobileLocalizations.of(context).edit,
                                        color: DefaultTheme.primaryColor,
                                        type: LabelType.bodyRegular,
                                      ),
                                      onTap: () {
                                        _firstNameController.text = widget.arguments.firstName;
                                        _detailChangeName(context);
                                      },
                                    ),
                                  ],
                                ).pad(l: 20, r: 20),
                                Textbox(
                                  controller: _nameController,
                                  readOnly: true,
                                  enabled: false,
                                  color: Colours.gray_81,
                                  fontSize: DefaultTheme.bodyRegularFontSize,
                                  textInputAction: TextInputAction.next,
                                  padding: 0.pad(b: 16),
                                ).pad(l: 20, r: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).d_chat_address,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    InkWell(
                                      child: Label(
                                        NMobileLocalizations.of(context).copy,
                                        color: DefaultTheme.primaryColor,
                                        type: LabelType.bodyRegular,
                                      ),
                                      onTap: () {
                                        copyAction(widget.arguments.publicKey);
                                      },
                                    ),
                                  ],
                                ).pad(l: 20, r: 20),
                                InkWell(
                                  onTap: () {
                                    copyAction(widget.arguments.publicKey);
                                  },
                                  child: Text(
                                    widget.arguments.publicKey,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colours.gray_81, fontSize: DefaultTheme.bodyRegularFontSize),
                                  ).pad(l: 20, r: 20, t: 8, b: 16),
                                ),
                                Container(
                                  color: DefaultTheme.lineColor,
                                  constraints: BoxConstraints(maxHeight: 1, minHeight: 1, maxWidth: double.infinity, minWidth: double.infinity),
                                ).pad(l: 20, r: 20, b: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).notes,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    InkWell(
                                      child: Label(
                                        NMobileLocalizations.of(context).edit,
                                        color: DefaultTheme.primaryColor,
                                        type: LabelType.bodyRegular,
                                      ),
                                      onTap: () {
                                        changeName();
                                      },
                                    ),
                                  ],
                                ).pad(l: 20, r: 20),
                                Textbox(
                                  multi: true,
                                  minLines: 1,
                                  maxLines: 3,
                                  controller: _notesController,
                                  readOnly: true,
                                  padding: 0.pad(b: 16),
                                ).pad(l: 20, r: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).burn_after_reading +
                                          '${_burnValue != null ? ' (${Format.durationFormat(Duration(seconds: _burnValue))})' : ''}',
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    CupertinoSwitch(
                                      value: _burnSelected,
                                      activeColor: DefaultTheme.primaryColor,
                                      onChanged: (value) async {
                                        if (value) {
                                          _burnValue = _burnValueArray[_sliderBurnValue.toInt()].inSeconds;
                                        } else {
                                          _burnValue = null;
                                        }
                                        setState(() {
                                          _burnSelected = value;
                                        });
                                      },
                                    ),
                                  ],
                                ).pad(l: 20, r: 16),
                                Slider(
                                  value: _sliderBurnValue,
                                  onChanged: (v) async {
                                    setState(() {
                                      _burnSelected = true;
                                      _sliderBurnValue = v;
                                      _burnValue = _burnValueArray[_sliderBurnValue.toInt()].inSeconds;
                                    });
                                  },
                                  divisions: _burnTextArray.length - 1,
                                  max: _burnTextArray.length - 1.0,
                                  min: 0,
                                ).pad(l: 4, r: 4),

                                //////////////////////////////////////////////////////////////////
                                Container(
                                  color: DefaultTheme.lineColor,
                                  constraints: BoxConstraints(maxHeight: 1, minHeight: 1, maxWidth: double.infinity, minWidth: double.infinity),
                                ).pad(l: 20, t: 56, r: 20),
                                (widget.arguments.type == ContactType.stranger
                                        ? FlatButton(
                                            padding: 0.pad(),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: <Widget>[
                                                /*loadAssetIconsImage(
                                                  'user-plus',
                                                  color: Colours.gray_81,
                                                  width: 24,
                                                ).pad(r: 8),*/
                                                Text(
                                                  NMobileLocalizations.of(context).add_contact,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                      color: Colours.blue_0f, fontSize: DefaultTheme.bodyRegularFontSize, fontWeight: FontWeight.bold),
                                                )
                                              ],
                                            ),
                                            onPressed: () {
                                              showAction(true);
                                            },
                                          )
                                        : FlatButton(
                                            padding: 0.pad(),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: <Widget>[
                                                Icon(
                                                  Icons.delete,
                                                  color: Colours.pink_f8,
                                                  size: 20,
                                                ).pad(r: 8),
                                                Text(
                                                  NMobileLocalizations.of(context).delete,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                      color: Colours.pink_f8, fontSize: DefaultTheme.bodyRegularFontSize, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            onPressed: () {
                                              showAction(false);
                                            },
                                          ))
                                    .sized(w: double.infinity, h: 48)
                                    .pad(l: 20, r: 20),
                                Container(
                                  color: DefaultTheme.lineColor,
                                  constraints: BoxConstraints(maxHeight: 1, minHeight: 1, maxWidth: double.infinity, minWidth: double.infinity),
                                ).pad(l: 20, r: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).pad(t: 28),
                  Positioned(
                    top: 0,
                    right: 20,
                    child: Button(
                      width: 56,
                      height: 56,
                      backgroundColor: DefaultTheme.primaryColor,
                      child: SvgPicture.asset('assets/icons/chat.svg', width: 24),
                      onPressed: () async {
                        _setContactOptions();
                        Navigator.of(context).pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: widget.arguments));
                      },
                    ),
                  ),
                ],
              ),
            )
          ]),
        ),
      );
    }
  }

  changeName() {
    BottomDialog.of(context).showBottomDialog(
      height: 320,
      title: NMobileLocalizations.of(context).edit_notes,
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
                      NMobileLocalizations.of(context).notes,
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
          text: NMobileLocalizations.of(context).save,
          width: double.infinity,
          onPressed: () async {
            _notesFormValid = (_notesFormKey.currentState as FormState).validate();
            if (_notesFormValid) {
              var contact = widget.arguments;
              contact.notes = _notesController.text.trim();

              await contact.setNotes(contact.notes);
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
      title: NMobileLocalizations.of(context).edit_name,
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
          text: NMobileLocalizations.of(context).save,
          width: double.infinity,
          onPressed: () async {
            _nameFormValid = (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              var contact = widget.arguments;
              contact.firstName = _firstNameController.text.trim();
              await contact.setName(contact.firstName);
              _nameController.text = widget.arguments.name;
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
    File savedImg = await getHeaderImage();
    if (savedImg == null) return;
    await widget.arguments.setAvatar(savedImg);
    setState(() {
      widget.arguments.avatar = savedImg;
    });
  }

  showChangeNameDialog() {
    _firstNameController.text = widget.arguments.firstName;

    BottomDialog.of(context).showBottomDialog(
      title: NMobileLocalizations.of(context).edit_nickname,
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
                      hintText: NMobileLocalizations.of(context).input_nickname,
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
          text: NMobileLocalizations.of(context).save,
          width: double.infinity,
          onPressed: () async {
            _nameFormValid = (_nameFormKey.currentState as FormState).validate();
            if (_nameFormValid) {
              var contact = widget.arguments;
              contact.firstName = _firstNameController.text.trim();
              _nameController.text = widget.arguments.name;
              contact.setName(contact.firstName);
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
            NMobileLocalizations.of(context).scan_show_me_desc,
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
          text: NMobileLocalizations.of(context).close,
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
      await ModalDialog.of(context).confirm(
        height: 350.h,
        title: Label(
          NMobileLocalizations.of(context).delete_friend_confirm_title,
          type: LabelType.h2,
          softWrap: true,
        ),
        content: Container(),
        agree: Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Button(
            child: Label(
              NMobileLocalizations.of(context).delete,
              type: LabelType.h3,
            ),
            backgroundColor: DefaultTheme.strongColor,
            width: double.infinity,
            onPressed: () {
              Navigator.pop(context);
              widget.arguments.setFriend(isFriend: b);
              setState(() {});
            },
          ),
        ),
        reject: Button(
          backgroundColor: DefaultTheme.backgroundLightColor,
          fontColor: DefaultTheme.fontColor2,
          text: NMobileLocalizations.of(context).cancel,
          width: double.infinity,
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      widget.arguments.setFriend(isFriend: b);
      setState(() {});
      showToast(NMobileLocalizations.of(context).success);
    }
  }
}
