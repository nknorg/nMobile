import 'package:flutter/material.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class LocalizationService {
  BuildContext context;


  NL10ns get message {
    return NL10ns.of(context);
  }


}
