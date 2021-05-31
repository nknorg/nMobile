import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:web3dart/credentials.dart';

class Validator {
  final BuildContext context;

  Validator.of(context) : this(context);

  S? _localizations;

  Validator(this.context) {
    _localizations = S.of(context);
  }

  walletName() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations?.error_required;
    };
  }

  pubKey() {
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

  seed() {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (value.trim().length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value) ? _localizations?.error_seed_format : null);
    };
  }

  identifierNKN() {
    return (value) {
      return value.trim().length == 0 ? _localizations?.error_required : (!RegExp(r'^[^.]*.?[0-9a-f]{64}$').hasMatch(value) ? _localizations?.error_client_address_format : null);
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
      }

      return value.trim().length == 0 ? _localizations?.error_required : (!jsonOk ? _localizations?.error_keystore_format : null);
    };
  }

  keystoreETH() {
    return (value) {
      bool isValid = false;
      try {
        // TODO:GG eth keystore
        // isValid = Ethereum.isKeystoreValid(value.trim());
      } catch (e) {}
      return value.trim().length == 0 ? _localizations?.error_required : (!isValid ? _localizations?.error_keystore_format : null);
    };
  }

  addressNKN() {
    return (value) {
      bool addressFormat = false;
      try {
        addressFormat = verifyAddress(value.trim());
      } catch (e) {
        debugPrintStack(label: e.toString());
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!addressFormat ? _localizations?.error_nkn_address_format : null);
    };
  }

  addressNKNOrEmpty() {
    return (value) {
      bool addressFormat = false;
      try {
        addressFormat = verifyAddress(value.trim());
      } catch (e) {
        debugPrintStack(label: e.toString());
      }
      return (value.trim().length != 0 && !addressFormat) ? _localizations?.error_nkn_address_format : null;
    };
  }

  addressETH() {
    return (value) {
      bool addressFormat = false;
      try {
        EthereumAddress.fromHex(value.trim());
        addressFormat = true;
      } catch (e) {
        //debugPrintStack(label: e?.toString());
      }
      return value.trim().length == 0 ? _localizations?.error_required : (!addressFormat ? _localizations?.error_nkn_address_format : null);
    };
  }
}
