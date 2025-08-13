# nMobile - the world's most secure private and group messenger

“The decisions we make about communication security today will determine the kind of society we live in tomorrow.”
                                 — Dr. Whitfield Diffie, co-creator of public key cryptography and advisor to NKN


For more detail: 

https://forum.nkn.org/t/nmobile-the-trusted-chat/2358



## Getting Started

https://forum.nkn.org/t/nmobile-pre-beta-community-testing-and-simple-guide/2012


## Dependencies

* Flutter sdk: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
* golang (>= 1.18.0): [https://golang.org/dl/](https://golang.org/dl/)
* gomobile: [https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile)
> Android need NDK (>= 21.x) [https://developer.android.com/studio/projects/install-ndk](https://developer.android.com/studio/projects/install-ndk)

## Build

### build application icon
```
$ flutter pub run flutter_launcher_icons:main
```

### Golib

> Every time you modify go code, you need to recompile.

gomobile will generate dependencies for android and ios. `Android` is `nkn.aar` and `nkn-sources.jar`, `iOS` is `Nkn.xcframework`.

```
$ cd golib
```

* Build `Android` dependencies

```
$ make android
```

* Build `iOS` dependencies

```
$ make ios
```

## Flutter

* Updating package dependencies

```
$ flutter pub get
```

* If it is `iOS`, you also need to run the following command for update `iOS` dependencies

```
$ cd ios
$ pod install
```

### Run the app in device

> [https://flutter.dev/docs/get-started/test-drive](https://flutter.dev/docs/get-started/test-drive)

```
$ flutter run
```

### Generate intl using plugin

* Using Flutter Intl plugin for generate intl files: [https://plugins.jetbrains.com/plugin/13666-flutter-intl](https://plugins.jetbrains.com/plugin/13666-flutter-intl)

## Account & Wallet Onboarding

### First-Time Registration (Passwordless)

- On your first launch, you can create an account without a password.
- The app generates a default, device-only account automatically so you can start using it immediately.
- No data is uploaded to any server during this step.

### Using Your Own Account (Import a Wallet)

- If you prefer to use your own account, you can import an existing wallet at any time.
- Open the app and go to: Settings → Account → Import Wallet.
- Follow the on-screen steps to complete the import.
- After import, your wallet becomes your active account.

### Notes

- Your keys are stored locally on your device. Make sure you back them up safely.
- You can keep using the default account or switch to your own wallet later—your choice.
- If you import a wallet, ensure you’re in a private, secure environment.
