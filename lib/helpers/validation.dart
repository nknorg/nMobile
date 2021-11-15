import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validate.dart';

class Validator {
  Validator.of(context) : this();

  S? _localizations;

  Validator() {
    _localizations = S.of(Global.appContext);
  }

  walletName() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  contactName() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  amount() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  required() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  password() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  confirmPassword(password) {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (value != password ? _localizations?.error_confirm_password : null);
    };
  }

  pubKeyNKN() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  identifierNKN() {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (!Validate.isNknChatIdentifierOk(value) ? _localizations?.error_client_address_format : null);
    };
  }

  keystoreNKN() {
    return (value) {
      var jsonOk;
      try {
        jsonDecode(value.trim());
        jsonOk = true;
      } on FormatException catch (e) {
        jsonOk = false;
        debugPrintStack(label: e.toString());
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!jsonOk ? _localizations?.error_keystore_format : null);
    };
  }

  keystoreETH() {
    return (value) {
      bool isValid = false;
      if (value.trim().length != 0) {
        try {
          isValid = Ethereum.isKeystoreValid(value.trim());
        } catch (e) {
          debugPrintStack(label: e.toString());
        }
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!isValid ? _localizations?.error_keystore_format : null);
    };
  }

  seedNKN() {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (!Validate.isNknSeedOk(value) ? _localizations?.error_seed_format : null);
    };
  }

  seedETH() {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (!Validate.isEthSeedOk(value) ? _localizations?.error_seed_format : null);
    };
  }

  addressNKN() {
    return (value) {
      bool addressFormat = false;
      if (value.trim().length != 0) {
        try {
          addressFormat = Validate.isNknAddressOk(value.trim());
        } catch (e) {
          debugPrintStack(label: e.toString());
        }
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!addressFormat ? _localizations?.error_nkn_address_format : null);
    };
  }

  addressNKNOrEmpty() {
    return (value) {
      bool addressFormat = false;
      try {
        addressFormat = Validate.isNknAddressOk(value.trim());
      } catch (e) {
        debugPrintStack(label: e.toString());
      }
      return (value.trim().length != 0 && !addressFormat) ? _localizations?.error_nkn_address_format : null;
    };
  }

  addressETH() {
    return (value) {
      bool addressFormat = false;
      if (value.trim().length != 0) {
        try {
          addressFormat = Validate.isEthAddressOk(value);
        } catch (e) {
          debugPrintStack(label: e.toString());
        }
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!addressFormat ? _localizations?.error_nkn_address_format : null);
    };
  }
}
