import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/util.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/search_service/search_service.dart';
import '../../components/dialog/bottom.dart';
import '../../components/dialog/loading.dart';
import '../../components/tip/toast.dart';
import '../../providers/custom_id_provider.dart';
import '../../utils/asset.dart';
import 'more_profile.dart';

class ContactChatProfileScreen extends BaseStateFulWidget {
  static final String routeName = "/contact/chat_profile";
  static final String argContactSchema = "contact_schema";

  static Future go(BuildContext? context, ContactSchema schema) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argContactSchema: schema,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactChatProfileScreen({Key? key, this.arguments}) : super(key: key);

  @override
  ContactChatProfileScreenState createState() => new ContactChatProfileScreenState();
}

class ContactChatProfileScreenState extends BaseStateFulWidgetState<ContactChatProfileScreen> {
  late ContactSchema _contact;

  @override
  void initState() {
    super.initState();
  }

  @override
  void onRefreshArguments() {
    _contact = widget.arguments?[ContactChatProfileScreen.argContactSchema];
  }

  _buttonStyle({bool topRadius = true, bool botRadius = true, double topPad = 12, double botPad = 12}) {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((state) => application.theme.backgroundLightColor),
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16, top: topPad, bottom: botPad)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: topRadius ? Radius.circular(12) : Radius.zero,
            bottom: botRadius ? Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }

  _modifyCustomId() async {
    // Get necessary credentials first
    String? walletAddress = await walletCommon.getDefaultAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      Toast.show(Settings.locale((s) => s.d_chat_not_login, ctx: context));
      return;
    }

    String? seedHex = await walletCommon.getSeed(walletAddress);
    if (seedHex == null || seedHex.isEmpty) {
      Toast.show(Settings.locale((s) => s.d_chat_not_login, ctx: context));
      return;
    }

    Uint8List seed;
    try {
      seed = hexDecode(seedHex);
    } catch (e) {
      Toast.show(Settings.locale((s) => s.d_chat_not_login, ctx: context));
      return;
    }

    String? nknAddress = clientCommon.address;
    if (nknAddress == null || nknAddress.isEmpty) {
      Toast.show(Settings.locale((s) => s.d_chat_not_login, ctx: context));
      return;
    }

    // Show input dialog with async validation
    String? customId = await BottomDialog.of(Settings.appContext).showInput(
      title: Settings.locale((s) => s.edit_custom_id, ctx: context),
      inputTip: Settings.locale((s) => s.custom_id, ctx: context),
      inputHint: Settings.locale((s) => s.input_custom_id, ctx: context),
      value: '',
      actionText: Settings.locale((s) => s.save, ctx: context),
      minLength: 5,
      maxLength: 30,
      canTapClose: true,
      asyncValidator: (value) async {
        // First, validate format: only letters, numbers, and underscores
        final formatRegex = RegExp(r'^[a-zA-Z0-9_]+$');
        if (!formatRegex.hasMatch(value)) {
          return Settings.locale((s) => s.tip_custom_id_format, ctx: context);
        }

        // Then check if the customId is already taken by someone else
        try {
          var service = await SearchService.createWithAuth(seed: seed);
          final existingUser = await service.queryByID(value);

          // If found and it's not the current user, the ID is taken
          if (existingUser != null) {
            // Check if it's the current user's own ID
            final myPublicKey = await service.getPublicKeyHex();
            if (existingUser?.publicKey?.toLowerCase() != myPublicKey.toLowerCase()) {
              // ID is taken by another user
              await service.dispose();
              return Settings.locale((s) => s.tip_custom_id_taken, ctx: context);
            } else {
              // ID is already set for current user
              await service.dispose();
              return Settings.locale((s) => s.tip_custom_id_already_set, ctx: context);
            }
          }

          await service.dispose();
          return null; // Validation passed
        } catch (e) {
          return Settings.locale((s) => s.tip_submit_failed, ctx: context) + ': $e';
        }
      },
    );

    if (customId == null || customId.isEmpty) return;

    // If we reach here, validation passed. Now submit the data.
    Loading.show(text: Settings.locale((s) => s.submitting, ctx: context));

    try {
      // Create authenticated search service
      var service = await SearchService.createWithAuth(seed: seed);

      // Submit user data with custom ID
      await service.submitUserData(
        nknAddress: nknAddress,
        customId: customId,
      );

      // Dispose the service
      await service.dispose();

      // Dismiss loading
      Loading.dismiss();

      // Update provider with new custom ID and associated nknAddress
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(customIdProvider.notifier).setCustomId(customId, nknAddress);

      // Show success message
      Toast.show(Settings.locale((s) => s.success, ctx: context));
    } catch (e) {
      // Dismiss loading
      Loading.dismiss();

      // Show error message
      Toast.show(Settings.locale((s) => s.tip_submit_failed, ctx: context) + ': $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Settings.locale((s) => s.profile, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg('more', color: Colors.white, width: 24),
            onPressed: () {
              ContactMoreProfileScreen.go(context, this._contact);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 30, bottom: 30, left: 20, right: 20),
        child: Consumer(
          builder: (context, ref, child) {
            final customIdState = ref.watch(customIdProvider);
            
            // Get customId for this contact's address
            final customId = customIdState.getCustomId(this._contact.address);
            final hasCustomId = customId != null && customId.isNotEmpty;

            // Display customId if available, otherwise display full address
            final displayId = hasCustomId ? customId! : this._contact.address;

            return Column(
              children: <Widget>[
                // ID
                TextButton(
                  style: _buttonStyle(topRadius: true, botRadius: false, topPad: 20, botPad: 10),
                  onPressed: () {
                    if (this._contact.isMe) _modifyCustomId();
                  },
                  child: Row(
                    children: <Widget>[
                      // Show fingerprint icon for custom ID, chat-id icon for D-Chat address
                      Asset.image('chat/chat-id.png', color: application.theme.primaryColor, width: 24),
                      SizedBox(width: 10),
                      Label(
                        Settings.locale((s) => s.id, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      Spacer(),

                      this._contact.isMe
                          ? Icon(
                              Icons.edit,
                              color: application.theme.fontColor2,
                              size: 18,
                            )
                          : SizedBox.shrink(),
                    ],
                  ),
                ),
                TextButton(
                  style: _buttonStyle(topRadius: false, botRadius: true, topPad: 10, botPad: 20),
                  onPressed: () {
                    Util.copyText(displayId);
                    Toast.show(Settings.locale((s) => s.copied, ctx: context));
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Label(
                          displayId,
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor2,
                          softWrap: true,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(
                        Icons.content_copy,
                        color: application.theme.fontColor2,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // QR Code section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.only(left: 16, right: 16, top: 30, bottom: 30),
                  child: Column(
                    children: <Widget>[
                      ContactAvatar(
                        contact: this._contact,
                        radius: 24,
                      ),
                      SizedBox(height: 20),
                      this._contact.address.isNotEmpty
                          ? Center(
                              child: QrImageView(
                                data: this._contact.address,
                                backgroundColor: application.theme.backgroundLightColor,
                                foregroundColor: application.theme.primaryColor,
                                version: QrVersions.auto,
                                size: 240.0,
                              ),
                            )
                          : SizedBox.shrink(),
                      SizedBox(height: 20),
                      Label(
                        Settings.locale((s) => s.scan_show_me_desc, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor2,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.left,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
