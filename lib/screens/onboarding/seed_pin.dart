import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/settings/terms.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class SeedPinOnboardingScreen extends BaseStateFulWidget {
  static const String routeName = '/onboarding/seed_pin';

  static Future go(BuildContext? context) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _SeedPinOnboardingScreenState createState() => _SeedPinOnboardingScreenState();
}

class _SeedPinOnboardingScreenState extends BaseStateFulWidgetState<SeedPinOnboardingScreen> with Tag {
  final GlobalKey _formKey = GlobalKey<FormState>();

  WalletBloc? _walletBloc;

  String _mnemonic = '';
  bool _formValid = false;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _pinConfirmController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _pinConfirmFocusNode = FocusNode();
  bool _termsChecked = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
    _generateMnemonic();
  }

  void _generateMnemonic() {
    setState(() {
      _mnemonic = bip39.generateMnemonic(strength: 128);
    });
  }

  Future _create() async {
    if (!_termsChecked) {
      Toast.show(Settings.locale((s) => s.read_and_agree_terms, ctx: context));
      return;
    }
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();

      final pin = _pinController.text;
      logger.i("$TAG - create with pin: ****, mnemonic: $_mnemonic");

      // Create wallet; we let SDK derive from random seed by default
      // We use PIN as the keystore password
      final Wallet nkn = await Wallet.create(null, config: WalletConfig(password: pin));
      logger.i("$TAG - wallet create - nkn:${nkn.toString()}");
      if (nkn.address.isEmpty || nkn.keystore.isEmpty) return;

      // Default name
      final WalletSchema wallet = WalletSchema(
        type: WalletType.nkn,
        address: nkn.address,
        publicKey: hexEncode(nkn.publicKey),
        name: 'Account',
      );

      _walletBloc?.add(AddWallet(wallet, nkn.keystore, pin, hexEncode(nkn.seed)));
      AppScreen.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double headIconSize = Settings.screenWidth() / 2.5;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        title: 'Create account',
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: Container(
        color: application.theme.backgroundColor4,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Asset.image('wallet/create-wallet.png', width: headIconSize),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints.expand(
                  height: Settings.screenHeight() - Header.height - headIconSize - 24 * 2 - 30,
                ),
                decoration: BoxDecoration(
                  color: application.theme.backgroundLightColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.always,
                  onChanged: () {
                    setState(() {
                      final pin = _pinController.text;
                      final pin2 = _pinConfirmController.text;
                      _formValid = pin.length >= 6 && pin == pin2 && _mnemonic.isNotEmpty && _termsChecked;
                    });
                  },
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          children: [
                            Label('Your recovery phrase', type: LabelType.h3),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: application.theme.backgroundColor2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _mnemonic
                                    .split(' ')
                                    .map((w) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: application.theme.backgroundColor3,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(w, style: application.theme.bodyText2),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _generateMnemonic,
                                child: const Text('Regenerate'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Label('Set a 6+ digit PIN', type: LabelType.h3),
                            const SizedBox(height: 8),
                            FormText(
                              controller: _pinController,
                              focusNode: _pinFocusNode,
                              hintText: 'Enter PIN',
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              password: true,
                              validator: (v) {
                                if ((v ?? '').length < 6) return 'PIN must be at least 6 digits';
                                return null;
                              },
                              onEditingComplete: () => FocusScope.of(context).requestFocus(_pinConfirmFocusNode),
                            ),
                            const SizedBox(height: 12),
                            FormText(
                              controller: _pinConfirmController,
                              focusNode: _pinConfirmFocusNode,
                              hintText: 'Confirm PIN',
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.number,
                              password: true,
                              validator: (v) {
                                if (v != _pinController.text) return 'PINs do not match';
                                return null;
                              },
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Checkbox(
                                  value: _termsChecked,
                                  onChanged: (checked) => setState(() => _termsChecked = checked ?? false),
                                ),
                                Label(
                                  Settings.locale((s) => s.read_and_agree_terms_01, ctx: context),
                                  type: LabelType.bodyRegular,
                                ),
                                Button(
                                  child: Label(
                                    Settings.locale((s) => s.read_and_agree_terms_02, ctx: context),
                                    color: Colors.blue,
                                    type: LabelType.bodyRegular,
                                    decoration: TextDecoration.underline,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  onPressed: () {
                                    Navigator.pushNamed(context, SettingsTermsScreen.routeName);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                          child: Button(
                            text: 'Create account',
                            width: double.infinity,
                            disabled: !_formValid,
                            onPressed: _create,
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
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }
}
