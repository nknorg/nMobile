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
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
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
import 'package:nmobile/screens/view/dialog_confirm.dart';
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
  String nickName;

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

    nickName = widget.arguments.name;
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
//    NLog.d(widget.arguments.name);
//    NLog.d(widget.arguments.firstName);
//    NLog.d(widget.arguments.sourceProfile.name);
//    NLog.d(widget.arguments.sourceProfile.firstName);
//    NLog.d(widget.arguments.toEntity());
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
                              updatePic();
                            },
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 40)
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
                  child: BodyBox(
                    padding: EdgeInsets.only(
                      top: 10,
                    ),
                    color: DefaultTheme.backgroundLightColor,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: showChangeSelfNameDialog,
                                      child: Row(
                                        children: <Widget>[
                                          Label(
                                            NMobileLocalizations.of(context).nickname,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                          SizedBox(width: 60),
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
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.edit,
                                            color: DefaultTheme.fontColor2,
                                            size: 18,
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: showQRDialog,
                                      child: Row(
                                        children: <Widget>[
                                          Label(
                                            'QR Code',
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                          Spacer(),
                                          loadAssetIconsImage(
                                            'scan',
                                            width: 22,
                                            color: DefaultTheme.fontColor2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                child: InkWell(
                                  onTap: () {
                                    copyAction(Global.currentClient.address);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Label(
                                            NMobileLocalizations.of(context).d_chat_address,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                          Icon(
                                            Icons.content_copy,
                                            color: DefaultTheme.fontColor2,
                                            size: 18,
                                          )
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Label(
                                              Global.currentClient.address,
                                              type: LabelType.bodyRegular,
                                              color: DefaultTheme.fontColor2,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                child: InkWell(
                                  onTap: () {
                                    copyAction(widget.arguments.nknWalletAddress);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Label(
                                            NMobileLocalizations.of(context).wallet_address,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                          Icon(
                                            Icons.content_copy,
                                            size: 16,
                                            color: DefaultTheme.fontColor2,
                                          )
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Label(
                                              widget.arguments.nknWalletAddress,
                                              type: LabelType.bodyRegular,
                                              color: DefaultTheme.fontColor2,
                                              overflow: TextOverflow.fade,
                                              textAlign: TextAlign.left,
                                              height: 1,
                                            ),
                                          ),
//                                            SvgPicture.asset(
//                                              'assets/icons/right.svg',
//                                              width: 24,
//                                              color: DefaultTheme.fontColor2,
//                                            )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
        ),
        body: Container(
          color: DefaultTheme.backgroundColor4,
          child: Flex(direction: Axis.vertical, children: <Widget>[
            Expanded(
              flex: 0,
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
                            File savedImg = await getHeaderImage();
                            setState(() {
                              widget.arguments.avatar = savedImg;
                            });
                            await widget.arguments.setAvatar(savedImg);
                            _chatBloc.add(RefreshMessages());
                          },
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      _firstNameController.text = widget.arguments.name;
                      _detailChangeName(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Label(
                          getName(),
                          type: LabelType.bodyLarge,
                          color: Colors.white,
                          overflow: TextOverflow.fade,
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(width: 10),
                        Icon(
                          Icons.edit,
                          color: DefaultTheme.fontColor2,
                          size: 18,
                        ),
                      ],
                    ),
                  )
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
                                Container(
                                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Label(
                                            NMobileLocalizations.of(context).nickname,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                          SizedBox(width: 60),
                                          Expanded(
                                            child: Label(
                                              widget.arguments.nickName,
                                              type: LabelType.bodyRegular,
                                              color: DefaultTheme.fontColor2,
                                              overflow: TextOverflow.fade,
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
                                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.lineColor))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Label(
                                                NMobileLocalizations.of(context).d_chat_address,
                                                type: LabelType.bodyRegular,
                                                color: DefaultTheme.fontColor1,
                                                height: 1,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  copyAction(widget.arguments.publicKey);
                                                },
                                                child: Icon(
                                                  Icons.content_copy,
                                                  color: DefaultTheme.fontColor2,
                                                  size: 18,
                                                ),
                                              )
                                            ],
                                          ),
                                          SizedBox(height: 20),
                                          InkWell(
                                            onTap: () {
                                              copyAction(widget.arguments.publicKey);
                                            },
                                            child: Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Label(
                                                    widget.arguments.clientAddress,
                                                    type: LabelType.bodyRegular,
                                                    color: DefaultTheme.fontColor2,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                                  child: Column(
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Label(
                                            NMobileLocalizations.of(context).notes,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor1,
                                            height: 1,
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () {
                                          changeNotes();
                                        },
                                        child: Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Textbox(
                                                multi: true,
                                                minLines: 1,
                                                enabled: false,
                                                maxLines: 3,
                                                controller: _notesController,
                                                readOnly: true,
                                                color: DefaultTheme.fontColor2,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Icon(
                                              Icons.edit,
                                              color: DefaultTheme.fontColor2,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).burn_after_reading + '${_burnValue != null ? ' (${Format.durationFormat(Duration(seconds: _burnValue))})' : ''}',
                                      type: LabelType.bodyRegular,
                                      color: DefaultTheme.fontColor1,
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
                                SizedBox(height: 40),
                                Container(
                                  color: DefaultTheme.lineColor,
                                  width: double.infinity,
                                  height: 0.8,
                                ),
                                getStatusView(),
                                Container(
                                  color: DefaultTheme.lineColor,
                                  width: double.infinity,
                                  height: 0.8,
                                ),
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
                      padding: const EdgeInsets.all(0),
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

  changeNotes() {
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
    File savedImg = await getHeaderImage();
    if (savedImg == null) return;
    await widget.arguments.setAvatar(savedImg);
    setState(() {
      widget.arguments.avatar = savedImg;
    });
  }

  showChangeSelfNameDialog() {
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
              setState(() {
                nickName = widget.arguments.name;
              });
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
      //delete
      SimpleConfirm(
          context: context,
          content: NMobileLocalizations.of(context).delete_friend_confirm_title,
          buttonText: NMobileLocalizations.of(context).delete,
          buttonColor: Colors.red,
          callback: (v) {
            if (v) {
              widget.arguments.setFriend(isFriend: false);
              setState(() {});
            }
          }).show();
    } else {
      widget.arguments.setFriend(isFriend: b);
      setState(() {});
      showToast(NMobileLocalizations.of(context).success);
    }
  }

  getStatusView() {
    if (widget.arguments.type == ContactType.stranger) {
      return FlatButton(
        padding: EdgeInsets.zero,
        child: Text(
          NMobileLocalizations.of(context).add_contact,
          textAlign: TextAlign.center,
          style: TextStyle(color: DefaultTheme.primaryColor, fontSize: DefaultTheme.bodyRegularFontSize),
        ),
        onPressed: () {
          showAction(true);
        },
      ).sized(h: 50, w: double.infinity);
    } else {
      return FlatButton(
        padding: EdgeInsets.zero,
        child: Text(
          NMobileLocalizations.of(context).delete,
          softWrap: false,
          textAlign: TextAlign.left,
          style: TextStyle(color: Colors.red, fontSize: DefaultTheme.bodyRegularFontSize),
        ),
        onPressed: () {
          showAction(false);
        },
      ).sized(h: 50, w: double.infinity);
    }
  }

  String getName() {
    String name = '${_sourceProfile?.name != null && _sourceProfile.name.isNotEmpty && (widget.arguments.firstName != null && widget.arguments.firstName.isNotEmpty || widget.arguments.lastName != null && widget.arguments.lastName.isNotEmpty) ? '(${_sourceProfile?.name})' : ''}';
    return widget.arguments.name;
  }
}
