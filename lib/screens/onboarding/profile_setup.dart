import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/avatar_editable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class ProfileSetupScreen extends BaseStateFulWidget {
  static const String routeName = '/profile/setup';

  static Future go(BuildContext? context) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState
    extends BaseStateFulWidgetState<ProfileSetupScreen> with Tag {
  ContactSchema? _myContact;

  @override
  void onRefreshArguments() {
    // No arguments to refresh
  }

  Future<void> _loadMyContact() async {
    try {
      WalletSchema? wallet = await walletCommon.getDefault();
      if (wallet != null) {
        ContactSchema? contact =
            await contactCommon.getMe(fetchWalletAddress: true);
        setState(() {
          _myContact = contact;
        });
      }
    } catch (e) {
      logger.e("$TAG - Error loading contact: $e");
    }
  }

  Future<void> _selectAvatarPicture() async {
    try {
      if (_myContact == null) return;

      String remarkAvatarPath = await Path.getRandomFile(
          clientCommon.getPublicKey(), DirType.profile,
          subPath: _myContact?.address, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      String? remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
      if (remarkAvatarPath.isEmpty ||
          remarkAvatarLocalPath == null ||
          remarkAvatarLocalPath.isEmpty) return;

      application.inSystemSelecting = true;
      File? picked = await MediaPicker.pickImage(
        cropStyle: CropStyle.rectangle,
        cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        maxSize: Settings.sizeAvatarMax,
        bestSize: Settings.sizeAvatarBest,
        savePath: remarkAvatarPath,
      );
      application.inSystemSelecting = false;

      if (picked == null) {
        return;
      } else {
        remarkAvatarPath = picked.path;
        remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
      }

      if (remarkAvatarPath.isEmpty ||
          remarkAvatarLocalPath == null ||
          remarkAvatarLocalPath.isEmpty) return;

      if (_myContact?.type == ContactType.me) {
        await contactCommon.setSelfAvatar(
            _myContact?.address, remarkAvatarLocalPath,
            notify: true);
      } else {
        await contactCommon.setOtherRemarkAvatar(
            _myContact?.address, remarkAvatarLocalPath,
            notify: true);
      }
      await _loadMyContact();
    } catch (e, st) {
      handleError(e, st);
    }
  }

  Future<void> _modifyNickname() async {
    if (_myContact == null) return;

    String? newName = await BottomDialog.of(Settings.appContext).showInput(
      title: "Set Your Nickname",
      inputTip: "Enter your chat nickname",
      inputHint: "Nickname",
      actionText: "Save",
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Nickname cannot be empty";
        }
        return null;
      },
    );

    if (newName != null && newName.trim().isNotEmpty) {
      Loading.show();
      try {
        await contactCommon.setOtherRemarkName(
            _myContact?.address, newName.trim(),
            notify: true);
        await _loadMyContact();
        Loading.dismiss();
      } catch (e, st) {
        Loading.dismiss();
        handleError(e, st);
      }
    }
  }

  void _skipSetup() {
    // Navigate to main app
    AppScreen.go(context);
  }

  void _completeSetup() {
    // Navigate to main app
    AppScreen.go(context);
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: "Setup Your Profile",
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 32),
              decoration: BoxDecoration(
                color: application.theme.backgroundColor4,
              ),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Label(
                      "Let's personalize your profile",
                      type: LabelType.h4,
                      color: application.theme.fontColor1,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Label(
                      "Set a nickname and profile photo that other users will see in chat",
                      type: LabelType.bodySmall,
                      color: application.theme.fontColor2,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),

                    /// avatar
                    _myContact != null
                        ? ContactAvatarEditable(
                            radius: 48,
                            contact: _myContact!,
                            placeHolder: false,
                            onSelect: _selectAvatarPicture,
                          )
                        : SizedBox.shrink(),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _selectAvatarPicture,
                      child: Label(
                        "Change Photo",
                        type: LabelType.bodyRegular,
                        color: application.theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Stack(
              children: [
                Container(
                  height: 32,
                  decoration:
                      BoxDecoration(color: application.theme.backgroundColor4),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: application.theme.backgroundColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding:
                      EdgeInsets.only(left: 16, right: 16, top: 26, bottom: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(
                        "Your Nickname",
                        type: LabelType.h3,
                      ),
                      SizedBox(height: 24),

                      /// name
                      TextButton(
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                              vertical: 15, horizontal: 16)),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                  bottom: Radius.circular(0)))),
                          backgroundColor: WidgetStateProperty.all(
                              application.theme.backgroundLightColor),
                        ),
                        onPressed: _modifyNickname,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(
                                  "Nickname",
                                  type: LabelType.bodySmall,
                                  color: application.theme.fontColor2,
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: Settings.screenWidth() - 100,
                                      child: Label(
                                        _myContact?.firstName ??
                                            "Set your nickname",
                                        type: LabelType.bodyRegular,
                                        color: _myContact?.firstName != null
                                            ? application.theme.fontColor1
                                            : application.theme.fontColor2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Asset.iconSvg('right',
                                width: 24, color: application.theme.fontColor2),
                          ],
                        ),
                      ),
                      Container(
                        height: 0.5,
                        color: application.theme.dividerColor,
                      ),
                      TextButton(
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16)),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(0),
                                  bottom: Radius.circular(12)))),
                          backgroundColor: WidgetStateProperty.all(
                              application.theme.backgroundLightColor),
                        ),
                        onPressed: _modifyNickname,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Label(
                              "Edit Nickname",
                              type: LabelType.bodyRegular,
                              color: application.theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Action buttons
                      Column(
                        children: [
                          Button(
                            text: "Complete Setup",
                            width: double.infinity,
                            backgroundColor: application.theme.primaryColor,
                            fontColor: Colors.white,
                            onPressed: _completeSetup,
                          ),
                          SizedBox(height: 12),
                          Button(
                            text: "Skip for Now",
                            width: double.infinity,
                            backgroundColor:
                                application.theme.primaryColor.withAlpha(20),
                            fontColor: application.theme.primaryColor,
                            onPressed: _skipSetup,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
