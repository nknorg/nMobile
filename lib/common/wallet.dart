import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/storages/wallet.dart';

import 'locator.dart';

Future<String> getWalletPassword(BuildContext context, String walletAddress) {
  if (walletAddress == null || walletAddress.isEmpty) {
    return Future.value(null);
  }
  S _localizations = S.of(context);
  return Future(() async {
    if (Settings.biometricsAuthentication) {
      return authorization.authenticationIfCan();
    }
    return false;
  }).then((bool authOk) async {
    String pwd = await WalletStorage().getPassword(walletAddress);
    if (!authOk || pwd == null || pwd.isEmpty) {
      return BottomDialog.of(context).showInput(
        title: _localizations.verify_wallet_password,
        inputTip: _localizations.wallet_password,
        inputHint: _localizations.input_password,
        actionText: _localizations.continue_text,
        password: true,
      );
    }
    return pwd;
  });
}
