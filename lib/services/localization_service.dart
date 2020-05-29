import 'package:flutter/material.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class LocalizationService {
  BuildContext context;


  NMobileLocalizations get message {
    return NMobileLocalizations.of(context);
  }


}
