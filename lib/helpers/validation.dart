import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:web3dart/credentials.dart';

class Validator {
  final BuildContext context;

  Validator.of(context) : this(context);

  S _localizations;
  Validator(this.context) {
    _localizations = S.of(context);
  }

  keystore() {
    return (value) {
      var jsonFormat;
      try {
        jsonDecode(value.trim());
        jsonFormat = true;
      } on FormatException catch (e) {
        jsonFormat = false;
      }

      return value.trim().length == 0
          ? _localizations.error_required
          : !jsonFormat
              ? _localizations.error_keystore_format
              : null;
    };
  }

  // TODO:GG keystoreEth
  // keystoreEth() {
  //   return (value) {
  //     bool isValid = false;
  //     try {
  //       isValid = Ethereum.isKeystoreValid(value.trim());
  //     } catch (e) {}
  //     return value.trim().length == 0
  //         ? _localizations.error_required
  //         : !isValid
  //             ? _localizations.error_keystore_format
  //             : null;
  //   };
  // }

  seed() {
    return (value) {
      return value.trim().length == 0
          ? _localizations.error_required
          : value.trim().length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)
              ? _localizations.error_seed_format
              : null;
    };
  }

  walletName() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  pubKey() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  contactName() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  amount() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  required() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  nknAddress() {
    return (value) {
      bool addressFormat = false;
      try {
        addressFormat = verifyAddress(value.trim());
      } catch (e) {
        debugPrintStack(label: e?.toString());
      }
      return value.trim().length == 0
          ? _localizations.error_required
          : !addressFormat
              ? _localizations.error_nkn_address_format
              : null;
    };
  }

  ethAddress() {
    return (value) {
      bool addressFormat = false;
      try {
        EthereumAddress.fromHex(value.trim());
        addressFormat = true;
      } catch (e) {
        //debugPrintStack(label: e?.toString());
      }
      return value.trim().length == 0
          ? _localizations.error_required
          : !addressFormat
              ? _localizations.error_nkn_address_format
              : null;
    };
  }

  nknIdentifier() {
    return (value) {
      return value.trim().length == 0
          ? _localizations.error_required
          : !RegExp(r'^[^.]*.?[0-9a-f]{64}$').hasMatch(value)
              ? _localizations.error_client_address_format
              : null;
    };
  }

  password() {
    return (value) {
      return value.trim().length > 0 ? null : _localizations.error_required;
    };
  }

  confirmPassword(password) {
    return (value) {
      return value.trim().length == 0
          ? _localizations.error_required
          : value != password
              ? _localizations.error_confirm_password
              : null;
    };
  }
}
