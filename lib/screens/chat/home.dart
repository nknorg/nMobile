// import 'dart:ui';
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
// import 'package:nmobile/blocs/chat/auth_bloc.dart';
// import 'package:nmobile/blocs/chat/auth_state.dart';
// import 'package:nmobile/blocs/client/client_state.dart';
// import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
// import 'package:nmobile/components/CommonUI.dart';
// import 'package:nmobile/components/button.dart';
// import 'package:nmobile/components/dialog/bottom.dart';
// import 'package:nmobile/components/dialog/create_input_group.dart';
// import 'package:nmobile/components/header/header.dart';
// import 'package:nmobile/components/label.dart';
// import 'package:nmobile/consts/colors.dart';
// import 'package:nmobile/consts/theme.dart';
// import 'package:nmobile/helpers/global.dart';
// import 'package:nmobile/l10n/localization_intl.dart';
// import 'package:nmobile/schemas/chat.dart';
// import 'package:nmobile/schemas/contact.dart';
// import 'package:nmobile/screens/chat/authentication_helper.dart';
// import 'package:nmobile/screens/chat/message.dart';
// import 'package:nmobile/screens/chat/messages.dart';
// import 'package:nmobile/screens/contact/contact.dart';
// import 'package:nmobile/screens/contact/home.dart';
// import 'package:nmobile/utils/extensions.dart';
// import 'package:nmobile/utils/image_utils.dart';
// import 'package:nmobile/utils/log_tag.dart';
//
// class ChatHome extends StatefulWidget {
//   static const String routeName = '/chat/home';
//
//   final TimerAuth timerAuth;
//
//   const ChatHome(this.timerAuth);
//
//   @override
//   _ChatHomeState createState() => _ChatHomeState();
// }
//
// class _ChatHomeState extends State<ChatHome> with SingleTickerProviderStateMixin, Tag {
//   GlobalKey _floatingActionKey = GlobalKey();
//
//   ContactSchema currentUser;
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//   Widget _blocHeader(){
//     return Header(
//       titleChild: GestureDetector(
//         onTap: () async {
//           if (TimerAuth.authed) {
//             ContactSchema currentUser = await ContactSchema.fetchCurrentUser();
//             Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: currentUser);
//           } else {
//             widget.timerAuth.onCheckAuthGetPassword(context);
//           }
//         },
//         child: Container(
//           margin: EdgeInsets.only(left: 12),
//           child: Flex(
//             direction: Axis.horizontal,
//             mainAxisAlignment: MainAxisAlignment.start,
//             children: <Widget>[
//               Container(
//                 margin: EdgeInsets.only(right: 12),
//                 child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state){
//                   if (state is AuthToUserState){
//                     currentUser = state.currentUser;
//                   }
//                   if (currentUser != null){
//                     return CommonUI.avatarWidget(
//                       radiusSize: 24,
//                       contact: currentUser,
//                     );
//                   }
//                   return Container();
//                 }),
//               ),
//               Expanded(
//                 flex: 1,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: <Widget>[
//                     BlocBuilder<AuthBloc, AuthState>(builder: (context, state){
//                       if (currentUser != null){
//                         return Label(currentUser.name, type: LabelType.h3, dark: true);
//                       }
//                       return Container();
//                     }),
//                     BlocBuilder<NKNClientBloc, NKNClientState>(
//                       builder: (context, clientState) {
//                         if (clientState is NKNConnectedState) {
//                           return Label(NL10ns.of(context).connected, type: LabelType.bodySmall, color: DefaultTheme.riseColor);
//                         } else {
//                           return Row(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: <Widget>[
//                               Label(NL10ns.of(context).connecting, type: LabelType.bodySmall, color: DefaultTheme.fontLightColor.withAlpha(200)),
//                               Padding(
//                                 padding: const EdgeInsets.only(bottom: 2, left: 4),
//                                 child: SpinKitThreeBounce(
//                                   color: DefaultTheme.loadingColor,
//                                   size: 10,
//                                 ),
//                               ),
//                             ],
//                           );
//                         }
//                       },
//                     ),
//                   ],
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//       hasBack: false,
//       backgroundColor: DefaultTheme.primaryColor,
//       action: IconButton(
//         icon: loadAssetIconsImage('addbook', color: Colors.white, width: 24),
//         onPressed: () {
//           if (TimerAuth.authed) {
//             Global.debugLog('route to Contact 1');
//             Navigator.of(context).pushNamed(ContactHome.routeName);
//           } else {
//             widget.timerAuth.onCheckAuthGetPassword(context);
//           }
//         },
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: DefaultTheme.primaryColor,
//       appBar: _blocHeader(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//       floatingActionButton: FloatingActionButton(
//         key: _floatingActionKey,
//         elevation: 12,
//         backgroundColor: DefaultTheme.primaryColor,
//         child: loadAssetIconsImage('pencil', width: 24),
//         onPressed: () {
//           if (TimerAuth.authed) {
//             showBottomMenu();
//           } else {
//             widget.timerAuth.onCheckAuthGetPassword(context);
//           }
//         },
//       ).pad(b: MediaQuery.of(context).padding.bottom, r: 4),
//       body: Container(
//         child: ConstrainedBox(
//           constraints: BoxConstraints.expand(),
//           child: GestureDetector(
//             onTap: () {
//               FocusScope.of(context).requestFocus(FocusNode());
//             },
//             child: Stack(
//               alignment: Alignment.bottomCenter,
//               children: <Widget>[
//                 ConstrainedBox(
//                   constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
//                   child: Container(
//                     constraints: BoxConstraints.expand(),
//                     color: DefaultTheme.primaryColor,
//                     child: Flex(
//                       direction: Axis.vertical,
//                       children: <Widget>[
//                         Expanded(
//                           flex: 1,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: DefaultTheme.backgroundLightColor,
// //                              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
//                             ),
//                             child: Flex(
//                               direction: Axis.vertical,
//                               children: <Widget>[
//                                 Expanded(
//                                   flex: 1,
//                                   child: Padding(
//                                     padding: EdgeInsets.only(top: 0.2),
//                                     child: MessagesTab(widget.timerAuth),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   showBottomMenu() {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return GestureDetector(
//           onTap: () {
//             Navigator.of(context).pop();
//           },
//           child: Scaffold(
//             backgroundColor: Colors.transparent,
//             body: Padding(
//               padding: EdgeInsets.only(bottom: 76, right: 16),
//               child: Align(
//                 alignment: Alignment.bottomRight,
//                 child: Container(
//                   height: 136,
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 1,
//                         child: Container(
//                           padding: EdgeInsets.only(bottom: 12, top: 12, right: 8),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               SizedBox(
//                                 height: 48,
//                                 child: Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     padding: EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.all(Radius.circular(12)),
//                                       color: Colours.dark_0f_a3p,
//                                     ),
//                                     child: Label(
//                                       NL10ns.of(context).new_group,
//                                       height: 1.2,
//                                       type: LabelType.h4,
//                                       dark: true,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(
//                                 height: 48,
//                                 child: Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     padding: EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.all(Radius.circular(12)),
//                                       color: Colours.dark_0f_a3p,
//                                     ),
//                                     child: Label(
//                                       NL10ns.of(context).new_whisper,
//                                       height: 1.2,
//                                       type: LabelType.h4,
//                                       dark: true,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 0,
//                         child: Container(
//                           padding: EdgeInsets.only(bottom: 12, top: 12),
//                           width: 64,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.all(Radius.circular(32)),
//                             color: DefaultTheme.primaryColor,
//                           ),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: <Widget>[
//                               Button(
//                                 child: loadAssetChatPng('group', width: 22, color: DefaultTheme.fontLightColor),
//                                 fontColor: DefaultTheme.fontLightColor,
//                                 backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
//                                 width: 48,
//                                 height: 48,
//                                 onPressed: () async {
//                                   Navigator.of(context).pop();
//                                   showModalBottomSheet(
//                                       context: context,
//                                       isScrollControlled: true,
//                                       shape:
//                                           RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
//                                       builder: (context) {
//                                         return CreateGroupDialog();
//                                       });
// //                                  await BottomDialog.of(context).showInputChannelDialog(title: NMobileLocalizations.of(context).create_channel);
//                                 },
//                               ),
//                               Button(
//                                 child: loadAssetIconsImage('user', width: 24, color: DefaultTheme.fontLightColor),
//                                 fontColor: DefaultTheme.fontLightColor,
//                                 backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
//                                 width: 48,
//                                 height: 48,
//                                 onPressed: () async {
//                                   var address = await BottomDialog.of(context)
//                                       .showInputAddressDialog(title: NL10ns.of(context).new_whisper, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
//                                   if (address != null) {
//                                     ContactSchema contact = ContactSchema(type: ContactType.stranger, clientAddress: address);
//                                     await contact.insertContact();
//                                     var c = await ContactSchema.fetchContactByAddress(address);
//                                     if (c != null) {
//                                       Navigator.of(context)
//                                           .pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: c));
//                                     } else {
//                                       Navigator.of(context)
//                                           .pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
//                                     }
//                                   } else {
//                                     Navigator.of(context).pop();
//                                   }
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
