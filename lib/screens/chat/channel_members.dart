import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/permission.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class ChannelMembersScreen extends StatefulWidget {
  static const String routeName = '/channel/members';

  final TopicSchema arguments;

  ChannelMembersScreen({this.arguments});

  @override
  _ChannelMembersScreenState createState() => _ChannelMembersScreenState();
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> with AccountDependsBloc {
  ScrollController _scrollController = ScrollController();
  List<ContactSchema> _subs = List<ContactSchema>();
  Permission _permissionHelper;
  ChatBloc _chatBloc;

  _genContactList(List<SubscribersSchema> data) async {
    List<ContactSchema> list = List<ContactSchema>();

    for (int i = 0, length = data.length; i < length; i++) {
      SubscribersSchema item = data[i];
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(item.addr));
      String contactType = ContactType.stranger;
      if (item.addr == accountChatId) {
        contactType = ContactType.me;
      }
      ContactSchema contact = ContactSchema(clientAddress: item.addr, nknWalletAddress: walletAddress, type: contactType);
      await contact.createContact(db);
      var getContact = await ContactSchema.getContactByAddress(db, contact.clientAddress);
      list.add(getContact);
    }

    return list;
  }

  initAsync() async {
    NLog.d('initAsync');
    widget.arguments.querySubscribers(await db).then((data) async {
      List<ContactSchema> list = List<ContactSchema>();

      for (var sub in data) {
        var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(sub.addr));
        String contactType = ContactType.stranger;
        if (sub.addr == accountChatId) {
          contactType = ContactType.me;
        }
        ContactSchema contact = ContactSchema(clientAddress: sub.addr, nknWalletAddress: walletAddress, type: contactType);
        await contact.createContact(db);
        var getContact = await ContactSchema.getContactByAddress(db, contact.clientAddress);
        list.add(getContact);
      }

      if (mounted) {
        setState(() {
          _subs = list;
        });
      }
    });

    await widget.arguments.getTopicCount(account);

    var data = await widget.arguments.querySubscribers(await db);
    _subs = await _genContactList(data);
    if (widget.arguments.type == TopicType.private) {
      // get private meta
      var meta = await widget.arguments.getPrivateOwnerMeta(account);
      print(meta);
      NLog.d('==============$meta');
      _permissionHelper = Permission(accept: meta['accept'] ?? [], reject: meta['reject'] ?? []);
    }
    NLog.d('_permissionHelper');
    if (mounted) {
      setState(() {});
    }
    Global.removeTopicCache(widget.arguments.topic);
  }

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    initAsync();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> topicWidget = <Widget>[
      SizedBox(width: 6.w),
      Label(widget.arguments.topicName, type: LabelType.h3, dark: true),
    ];
    if (widget.arguments.type == TopicType.private) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 22, color: DefaultTheme.fontLightColor));
    }

    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NL10ns.of(context).channel_members,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: FlatButton(
          child: loadAssetChatPng('group_add', width: 20.w),
          onPressed: () async {
            var address = await BottomDialog.of(context).showInputAddressDialog(title: NL10ns.of(context).invite_members, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
            if (address != null) {
              acceptPrivateAction(address);
            }
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(bottom: 20.h, left: 16.w, right: 16.w),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: widget.arguments.avatarWidget(db,
                    backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                    size: 48,
                    fontColor: DefaultTheme.fontLightColor,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: topicWidget,
                    ),
                    Label('${widget.arguments.count ?? 0} ' + NL10ns.of(context).members, type: LabelType.bodyRegular, color: DefaultTheme.successColor)
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              child: BodyBox(
                padding: EdgeInsets.only(left: 16.w, right: 16.w),
                color: DefaultTheme.backgroundLightColor,
                child: Flex(
                  direction: Axis.vertical,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 4, bottom: 32),
                        controller: _scrollController,
                        itemCount: _subs.length,
                        itemExtent: 72,
                        itemBuilder: (BuildContext context, int index) {
                          var contact = _subs[index];
                          return getItemView(contact);
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
    );
  }

  getNameLabel(ContactSchema contact) {
    String name = contact.name;
    if (widget.arguments.type == TopicType.private && contact.clientAddress != accountChatId && widget.arguments.isOwner(accountPubkey)) {
      var permissionStatus = _permissionHelper?.getSubscriberStatus(contact.clientAddress);
      name = name + '(${permissionStatus ?? NL10ns.of(context).loading})';
    }
    return Expanded(
      child: Label(
        name,
        type: LabelType.h4,
        overflow: TextOverflow.fade,
      ),
    );
  }

  getItemView(ContactSchema contact) {
    List<Widget> toolBtns = [];
    if (contact.clientAddress != accountChatId) {
      toolBtns = getToolBtn(contact);
    }
    List<Widget> nameLabel = <Widget>[
      getNameLabel(contact),
    ];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          ContactScreen.routeName,
          arguments: contact,
        );
      },
      child: Container(
        child: Flex(
          direction: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Container(
                padding: EdgeInsets.only(right: 16.w),
                alignment: Alignment.center,
                child: contact.avatarWidget(db,
                  size: 22,
                  backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.only(),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: DefaultTheme.lineColor)),
                ),
                child: Flex(
                  direction: Axis.horizontal,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Row(children: nameLabel),
                            SizedBox(height: 6),
                            Label(
                              contact.clientAddress,
                              type: LabelType.label,
                              overflow: TextOverflow.fade,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 0,
                      child: Container(
                        alignment: Alignment.centerRight,
                        height: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: toolBtns,
                          ),
                        ),
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

  getToolBtn(ContactSchema contact) {
    List<Widget> toolBtns = <Widget>[];
    if (widget.arguments.type == TopicType.private && widget.arguments.isOwner(accountPubkey)) {
      var permissionStatus = _permissionHelper?.getSubscriberStatus(contact.clientAddress);
      Widget checkBtn = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          EasyLoading.show();
          if (permissionStatus == PermissionStatus.rejected) {
            await widget.arguments.removeRejectPrivateMember(account, addr: contact.clientAddress);
          }
          EasyLoading.dismiss();
          showToast(NL10ns.of(context).success);
          setState(() {
            _permissionHelper.reject.removeWhere((x) => x['addr'] == contact.clientAddress);
            if (_permissionHelper.accept == null) {
              _permissionHelper.accept = [];
            }
            _permissionHelper.accept.add({'addr': contact.clientAddress});
          });
          Future.delayed(Duration(milliseconds: 500), () {
            widget.arguments.acceptPrivateMember(account, addr: contact.clientAddress);
          });
        },
        child: loadAssetIconsImage(
          'check',
          width: 20,
          color: DefaultTheme.successColor,
        ).pad(l: 12).sized(w: 32, h: double.infinity),
      );
      Widget trashBtn = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            EasyLoading.show();
            if (permissionStatus == PermissionStatus.accepted) {
              await widget.arguments.removeAcceptPrivateMember(account, addr: contact.clientAddress);
            }
            EasyLoading.dismiss();
            showToast(NL10ns.of(context).success);
            setState(() {
              _permissionHelper.accept.removeWhere((x) => x['addr'] == contact.clientAddress);
              if (_permissionHelper.reject == null) {
                _permissionHelper.reject = [];
              }
              _permissionHelper.reject.add({'addr': contact.clientAddress});
            });
            Future.delayed(Duration(milliseconds: 500), () {
              widget.arguments.rejectPrivateMember(account, addr: contact.clientAddress);
            });
          },
          child: Icon(
            Icons.block,
            size: 20,
            color: Colours.red,
          ).pad(l: 12).sized(w: 32, h: double.infinity));
      if (permissionStatus == PermissionStatus.accepted) {
        toolBtns.add(trashBtn);
      } else if (permissionStatus == PermissionStatus.rejected) {
        toolBtns.add(checkBtn);
      } else if (permissionStatus == PermissionStatus.pending) {
        toolBtns.add(checkBtn);
        toolBtns.add(trashBtn);
      }
    }
    return toolBtns;
  }

  acceptPrivateAction(address) async {
    showToast(NL10ns.of(context).invitation_sent);
    if (widget.arguments.type == TopicType.private) {
      await widget.arguments.acceptPrivateMember(account, addr: address);
    }

    var sendMsg = MessageSchema.fromSendData(from: accountChatId, content: widget.arguments.topic, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;

    var sendMsg1 = MessageSchema.fromSendData(from: accountChatId, topic: widget.arguments.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
    sendMsg1.isOutbound = true;

    try {
      _chatBloc.add(SendMessage(sendMsg));
      _chatBloc.add(SendMessage(sendMsg1));
    } catch (e) {
      print('send message error: $e');
    }
  }
}
