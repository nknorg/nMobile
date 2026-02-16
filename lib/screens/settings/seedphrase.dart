import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class SeedphraseDisplayScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/seedphrase';

  static Future go(BuildContext? context) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _SeedphraseDisplayScreenState createState() =>
      _SeedphraseDisplayScreenState();
}

class _SeedphraseDisplayScreenState
    extends BaseStateFulWidgetState<SeedphraseDisplayScreen> with Tag {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _seedphraseVisible = false;
  String? _seedphrase;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  void onRefreshArguments() {
    // No arguments to refresh
  }

  Future<void> _verifyPinAndShowSeedphrase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get wallet for password verification
      WalletSchema? wallet = await walletCommon.getDefault();
      if (wallet == null || wallet.address.isEmpty) {
        Toast.show("No wallet found");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Verify password (using wallet password as security)
      bool isPasswordCorrect = await walletCommon.isPasswordRight(
          wallet.address, _pinController.text);
      if (!isPasswordCorrect) {
        Toast.show("Incorrect password");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get seedphrase from secure storage
      WalletStorage storage = WalletStorage();
      String? seed = await storage.getSeed(wallet.address);
      if (seed != null && seed.isNotEmpty) {
        setState(() {
          _seedphrase = seed;
          _seedphraseVisible = true;
        });
      } else {
        Toast.show("Seedphrase not available");
      }
    } catch (e) {
      logger.e("$TAG - Error retrieving seedphrase: $e");
      Toast.show("Error retrieving seedphrase");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copySeedphrase() async {
    if (_seedphrase != null) {
      await Clipboard.setData(ClipboardData(text: _seedphrase!));
      Toast.show("Seedphrase copied to clipboard");
    }
  }

  void _hideSeedphrase() {
    setState(() {
      _seedphraseVisible = false;
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: "Show Seedphrase",
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_seedphraseVisible) ...[
                // Warning message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Label(
                            "Security Warning",
                            type: LabelType.h4,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Label(
                        "Your seedphrase gives full access to your funds. Only show it when necessary and never share it with anyone.",
                        type: LabelType.bodySmall,
                        color: application.theme.fontColor1,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // PIN input form
                Label(
                  "Enter your PIN to continue",
                  type: LabelType.h4,
                  color: application.theme.fontColor1,
                ),
                SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      hintStyle: TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: application.theme.primaryColor, width: 2),
                      ),
                    ),
                    validator: Validator.of(context).password(),
                  ),
                ),
                SizedBox(height: 24),

                // Show button
                Button(
                  text: _isLoading ? "Verifying..." : "Show Seedphrase",
                  width: double.infinity,
                  backgroundColor: application.theme.primaryColor,
                  fontColor: Colors.white,
                  onPressed: _isLoading ? null : _verifyPinAndShowSeedphrase,
                ),
              ] else ...[
                // Seedphrase display
                Label(
                  "Your Seedphrase",
                  type: LabelType.h4,
                  color: application.theme.fontColor1,
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: application.theme.backgroundLightColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: application.theme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _seedphrase ?? "",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: application.theme.fontColor1,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.content_copy,
                              size: 16, color: application.theme.fontColor2),
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: _copySeedphrase,
                            child: Label(
                              "Tap to copy",
                              type: LabelType.bodySmall,
                              color: application.theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Security reminder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Label(
                            "Important Security Notice",
                            type: LabelType.h4,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Label(
                        "• Write down your seedphrase and store it safely\n• Never store it digitally or take screenshots\n• Anyone with this seedphrase can steal your funds\n• This is the only way to recover your wallet",
                        type: LabelType.bodySmall,
                        color: application.theme.fontColor1,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Hide button
                Button(
                  text: "Hide Seedphrase",
                  width: double.infinity,
                  backgroundColor: application.theme.primaryColor.withAlpha(20),
                  fontColor: application.theme.primaryColor,
                  onPressed: _hideSeedphrase,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
