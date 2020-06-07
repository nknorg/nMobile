# nMobile Pro

nMobile Pro

## Getting Started


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