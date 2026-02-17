import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/app.dart';

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
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  File? _selectedAvatar;
  bool _isUploading = false;

  @override
  void onRefreshArguments() {
    // No arguments to refresh
  }

  @override
  void initState() {
    super.initState();
    _loadMyContact();
  }

  Future<void> _loadMyContact() async {
    try {
      WalletSchema? wallet = await walletCommon.getDefault();
      if (wallet != null) {
        ContactSchema? contact =
            await contactCommon.getMe(fetchWalletAddress: true);

        // If no contact exists, create a temporary one for setup
        if (contact == null) {
          contact = ContactSchema(
            address: wallet.address,
            firstName: "",
            type: ContactType.me,
          );
        }

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
      // Get wallet address for path generation - retry a few times
      WalletSchema? wallet;
      for (int i = 0; i < 3; i++) {
        wallet = await walletCommon.getDefault();
        if (wallet != null) break;
        if (i < 2) {
          logger.d("Wallet not found, retrying... (${i + 1}/3)");
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (wallet == null) {
        logger.e("No wallet found for avatar selection after retries");
        Toast.show('Please wait a moment and try again');
        return;
      }

      String remarkAvatarPath = await Path.getRandomFile(
          clientCommon.getPublicKey(), DirType.profile,
          subPath: wallet.address, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      String? remarkAvatarLocalPath = Path.convert2Local(remarkAvatarPath);
      if (remarkAvatarPath.isEmpty ||
          remarkAvatarLocalPath == null ||
          remarkAvatarLocalPath.isEmpty) {
        logger.e("Failed to create avatar file path");
        Toast.show('Failed to prepare image storage');
        return;
      }

      logger.d("Starting image picker with save path: $remarkAvatarPath");
      application.inSystemSelecting = true;

      File? picked = await MediaPicker.pickImage(
        cropStyle: CropStyle.rectangle,
        cropRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        maxSize: Settings.sizeAvatarMax,
        bestSize: Settings.sizeAvatarBest,
        savePath: remarkAvatarPath,
      );

      application.inSystemSelecting = false;
      logger.d("Image picker completed. Picked: ${picked?.path}");

      if (picked == null) {
        logger.d("User cancelled image selection");
        return;
      }

      setState(() {
        _selectedAvatar = picked;
      });

      Toast.show('Photo selected successfully!');
    } catch (e, st) {
      logger.e("Error selecting avatar: $e");
      logger.e("Stack trace: $st");
      Toast.show('Failed to select photo: ${e.toString()}');
    }
  }

  Future<void> _saveUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      Toast.show('Please enter a username');
      return;
    }

    // Get wallet address for saving - retry a few times
    WalletSchema? wallet;
    for (int i = 0; i < 3; i++) {
      wallet = await walletCommon.getDefault();
      if (wallet != null) break;
      if (i < 2) {
        logger.d("Wallet not found, retrying... (${i + 1}/3)");
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    if (wallet == null) {
      Toast.show('Please wait a moment and try again');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Save avatar first if selected
      if (_selectedAvatar != null) {
        String? remarkAvatarLocalPath =
            Path.convert2Local(_selectedAvatar!.path);
        if (remarkAvatarLocalPath != null) {
          await contactCommon.setSelfAvatar(
              wallet.address, remarkAvatarLocalPath,
              notify: true);
        }
      }

      // Save username for self profile
      await contactCommon.setSelfFullName(
          wallet.address, _usernameController.text.trim(), null,
          notify: true);

      await _loadMyContact();

      Toast.show('Profile saved successfully!');
    } catch (e, st) {
      logger.e("Error saving profile: $e");
      logger.e("Stack trace: $st");
      Toast.show('Failed to save profile: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _skipSetup() {
    // Navigate to main app
    AppScreen.go(context);
  }

  void _completeSetup() {
    _saveUsername().then((_) {
      AppScreen.go(context);
    });
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
                      "Set a username and profile photo that other users will see in chat",
                      type: LabelType.bodySmall,
                      color: application.theme.fontColor2,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),

                    /// avatar
                    GestureDetector(
                      onTap: _selectAvatarPicture,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: application.theme.backgroundLightColor,
                          border: Border.all(
                            color: application.theme.primaryColor,
                            width: 2,
                          ),
                        ),
                        child: _selectedAvatar != null
                            ? ClipOval(
                                child: Image.file(
                                  _selectedAvatar!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _myContact != null
                                ? ContactAvatarEditable(
                                    radius: 48,
                                    contact: _myContact!,
                                    placeHolder: false,
                                    onSelect: _selectAvatarPicture,
                                  )
                                : Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: application.theme.fontColor2,
                                  ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _selectAvatarPicture,
                      child: Label(
                        "Tap to change photo",
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
                        "Your Username",
                        type: LabelType.h3,
                      ),
                      SizedBox(height: 8),
                      Label(
                        "Choose a username that other users will see",
                        type: LabelType.bodySmall,
                        color: application.theme.fontColor2,
                      ),
                      SizedBox(height: 16),

                      /// username input field
                      TextField(
                        controller: _usernameController,
                        focusNode: _usernameFocusNode,
                        decoration: InputDecoration(
                          hintText: "Enter your username",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: application.theme.dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: application.theme.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: application.theme.backgroundLightColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: application.theme.fontColor1,
                        ),
                        maxLength: 30,
                        textInputAction: TextInputAction.done,
                      ),
                      SizedBox(height: 32),

                      // Action buttons
                      Column(
                        children: [
                          Button(
                            text: _isUploading ? "Saving..." : "Complete Setup",
                            width: double.infinity,
                            backgroundColor: application.theme.primaryColor,
                            fontColor: Colors.white,
                            onPressed: _isUploading ? null : _completeSetup,
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
