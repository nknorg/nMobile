# nMobile

“The decisions we make about communication security today will determine the kind of society we live in tomorrow.”
                                 — Dr. Whitfield Diffie, co-creator of public key cryptography and advisor to NKN


nMobile， the world's most secure private and group messsenger


For more detail: 

https://forum.nkn.org/t/nmobile-the-trusted-chat/2358



## Getting Started

https://forum.nkn.org/t/nmobile-pre-beta-community-testing-and-simple-guide/2012


## install
```shelllanguage
$ flutter pub get
```
## Build

### build l10n arb
```shelllanguage
$ flutter pub run intl_translation:extract_to_arb --output-dir=l10n-arb lib/l10n/localization_intl.dart
```

### build l10n dart
```shelllanguage
$ flutter pub run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/localization_intl.dart l10n-arb/intl_*.arb
```
