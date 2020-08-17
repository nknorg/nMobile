import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  final TopicSchema topic;

  ChannelMembersScreen({this.topic});

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
//    widget.topic.querySubscribers(await db).then((data) async {
//      List<ContactSchema> list = List<ContactSchema>();
//
//      for (var sub in data) {
//        var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(sub.addr));
//        String contactType = ContactType.stranger;
//        if (sub.addr == accountChatId) {
//          contactType = ContactType.me;
//        }
//        ContactSchema contact = ContactSchema(clientAddress: sub.addr, nknWalletAddress: walletAddress, type: contactType);
//        await contact.createContact(db);
//        var getContact = await ContactSchema.getContactByAddress(db, contact.clientAddress);
//        list.add(getContact);
//      }
//
//      if (mounted) {
//        setState(() {
//          _subs = list;
//        });
//      }
//    });
//    await widget.topic.getTopicCount(account);

    var data = await widget.topic.querySubscribers(await db);
    _subs = await _genContactList(data);
    _subs = _subs.toSet().toList();
    if (widget.topic.type == TopicType.private) {
      // get private meta
      var meta = await widget.topic.getPrivateOwnerMeta(account);
      print(meta);
      NLog.d('==============$meta');
      _permissionHelper = Permission(accept: meta['accept'] ?? [], reject: meta['reject'] ?? []);
    }
    NLog.d('_permissionHelper');
    if (mounted) {
      setState(() {});
    }
    Global.removeTopicCache(widget.topic.topic);
  }

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    initAsync();
  }

  @override
  Widget build(BuildContext context) {
    if (_subs.length > 0) {
      ContactSchema owner = widget.topic.type == TopicType.public ? null : _subs.firstWhere((c) => widget.topic.isOwner(c.clientAddress), orElse: () => null);
      if (owner != null) _subs.remove(owner);
      ContactSchema me = _subs.firstWhere((c) => c.clientAddress == accountChatId, orElse: () => null);
      if (me != null) _subs.remove(me);
      _subs.sort((a, b) => a.name.compareTo(b.name));
      if (me != null) _subs.insert(0, me);
      if (owner != null && owner != me) _subs.insert(0, owner);
    }
    List<Widget> topicWidget = [Label(widget.topic.shortName, type: LabelType.h3, dark: true)];
    if (widget.topic.type == TopicType.private) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 18, color: DefaultTheme.fontLightColor).pad(r: 2));
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
            child: loadAssetChatPng('group_add', width: 20),
            onPressed: () async {
              var address = await BottomDialog.of(context)
                  .showInputAddressDialog(title: NL10ns.of(context).invite_members, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
              if (address != null) {
                acceptPrivateAction(address);
              }
            },
          ).sized(w: 72)),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 20.h, left: 16.w, right: 16.w),
            child: Row(
              children: [
                widget.topic
                    .avatarWidget(
                      db,
                      backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                      size: 48,
                      fontColor: DefaultTheme.fontLightColor,
                    )
                    .pad(r: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: topicWidget),
                    Label(
                      '${_subs?.length ?? '--'} ' + NL10ns.of(context).members,
                      type: LabelType.bodyRegular,
                      color: DefaultTheme.successColor,
                    ).pad(l: widget.topic.type == TopicType.private ? 20 : 0)
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              child: BodyBox(
                padding: 0.pad(),
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
                          return getItemView(_subs[index]);
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

  getItemView(ContactSchema contact) {
    List<Widget> nameLabel = getNameLabels(contact);
    List<Widget> toolBtns = getToolBtns(contact);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: contact);
      },
      child: Container(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            contact
                .avatarWidget(
                  db,
                  size: 24,
                  backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                )
                .pad(l: 16, r: 16)
                .center,
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: nameLabel).pad(b: 6),
                          Label(
                            contact.clientAddress,
                            type: LabelType.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ).pad(r: toolBtns.isEmpty ? 16 : 0),
                    ),
                    Row(children: toolBtns),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> getNameLabels(ContactSchema contact) {
    String name = contact.name;
    String option;
    if (widget.topic.type == TopicType.private) {
      if (widget.topic.isOwner(contact.clientAddress /*.toPubkey*/)) {
        if (contact.clientAddress == accountChatId) {
          option = '(${NL10ns.of(context).you}, ${NL10ns.of(context).owner})';
        } else {
          option = '(${NL10ns.of(context).owner})';
        }
      } else if (contact.clientAddress == accountChatId) {
        option = '(${NL10ns.of(context).you})';
      } else if (widget.topic.isOwner(accountPubkey)) {
        // Me is owner, but current user is not me.
        String permissionStatus = _permissionHelper?.getSubscriberStatus(contact.clientAddress);
        option = permissionStatus == PermissionStatus.accepted ? null : '(${permissionStatus ?? NL10ns.of(context).loading})';
      }
    } else if (contact.clientAddress == accountChatId) {
      option = '(${NL10ns.of(context).you})';
    }
    return [
      Label(name, type: LabelType.h4, overflow: TextOverflow.ellipsis),
      option == null
          ? Space.empty
          : option.contains(PermissionStatus.rejected)
              ? Text(
                  option,
                  style: TextStyle(
                    fontSize: DefaultTheme.h4FontSize,
                    color: Colours.pink_f8,
                    fontWeight: FontWeight.w600,
//                    decoration: TextDecoration.lineThrough,
//                    decorationStyle: TextDecorationStyle.solid,
//                    decorationThickness: 1.5,
                  ),
                ).pad(l: 4)
              : Label(option, type: LabelType.h4, color: Colours.gray_81, fontWeight: FontWeight.w600).pad(l: 4),
    ];
  }

  List<Widget> getToolBtns(ContactSchema contact) {
    List<Widget> toolBtns = <Widget>[];
    if (widget.topic.type == TopicType.private && widget.topic.isOwner(accountPubkey) && contact.clientAddress != accountChatId) {
      var permissionStatus = _permissionHelper?.getSubscriberStatus(contact.clientAddress);

      acceptAction() async {
        EasyLoading.show();
        if (permissionStatus == PermissionStatus.rejected) {
          await widget.topic.removeRejectPrivateMember(account, addr: contact.clientAddress);
        }
        setState(() {
          _permissionHelper.reject.removeWhere((x) => x['addr'] == contact.clientAddress);
          if (_permissionHelper.accept == null) {
            _permissionHelper.accept = [];
          }
          _permissionHelper.accept.add({'addr': contact.clientAddress});
        });
        Future.delayed(Duration(milliseconds: 500), () {
          widget.topic.acceptPrivateMember(account, addr: contact.clientAddress);
        });
        EasyLoading.dismiss();
        showToast(NL10ns.of(context).accepted);
      }

      rejectAction() async {
        EasyLoading.show();
        if (permissionStatus == PermissionStatus.accepted) {
          await widget.topic.removeAcceptPrivateMember(account, addr: contact.clientAddress);
        }
        setState(() {
          _permissionHelper.accept.removeWhere((x) => x['addr'] == contact.clientAddress);
          if (_permissionHelper.reject == null) {
            _permissionHelper.reject = [];
          }
          _permissionHelper.reject.add({'addr': contact.clientAddress});
        });
        Future.delayed(Duration(milliseconds: 500), () {
          widget.topic.rejectPrivateMember(account, addr: contact.clientAddress);
        });
        EasyLoading.dismiss();
        showToast(NL10ns.of(context).rejected);
      }

      ;
      Widget acceptIcon = loadAssetIconsImage('check', width: 20, color: DefaultTheme.successColor);
      Widget rejectIcon = Icon(Icons.block, size: 20, color: Colours.red);
      if (permissionStatus == PermissionStatus.accepted) {
        toolBtns.add(InkWell(child: rejectIcon.pad(l: 6, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
      } else if (permissionStatus == PermissionStatus.rejected) {
        toolBtns.add(InkWell(child: acceptIcon.pad(l: 6, r: 16).center.sized(h: double.infinity), onTap: acceptAction));
      } else if (permissionStatus == PermissionStatus.pending) {
        toolBtns.add(InkWell(child: acceptIcon.pad(l: 6, r: 8).center.sized(h: double.infinity), onTap: acceptAction));
        toolBtns.add(InkWell(child: rejectIcon.pad(l: 8, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
      }
    }
    return toolBtns;
  }

  acceptPrivateAction(address) async {
    showToast(NL10ns.of(context).invitation_sent);
    if (widget.topic.type == TopicType.private) {
      await widget.topic.acceptPrivateMember(account, addr: address);
    }

    var sendMsg = MessageSchema.fromSendData(from: accountChatId, content: widget.topic.topic, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;

    var sendMsg1 =
        MessageSchema.fromSendData(from: accountChatId, topic: widget.topic.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
    sendMsg1.isOutbound = true;

    try {
      _chatBloc.add(SendMessage(sendMsg));
      _chatBloc.add(SendMessage(sendMsg1));
    } catch (e) {
      print('send message error: $e');
    }
  }
}
