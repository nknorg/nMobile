# nMobile - the world's most secure private and group messenger

"The decisions we make about communication security today will determine the kind of society we live in tomorrow."
                                 — Dr. Whitfield Diffie, co-creator of public key cryptography and advisor to NKN

## 🆕 2026 Edition Features

This enhanced version includes significant improvements to the onboarding experience and user interface:

### ✨ Enhanced Onboarding Experience

- **🔤 BIP39 Word Editing**: Interactive seedphrase word editing with real-time validation
- **👤 Profile Setup**: Material Design username and avatar setup immediately after wallet creation
- **🔗 Address Display**: Shows both NKN and EVM addresses derived from your seedphrase
- **🎨 Modern UI**: Light grey heading text and improved visual hierarchy throughout the app
- **📱 Streamlined Flow**: Simplified wallet creation process focused on security and usability

### 🖼️ App Screenshots

#### Welcome Screen
![Welcome Screen](screenshots/Screenshot%20from%202026-02-16%2017-39-27.png)

#### Seedphrase Generation with Word Editing
![Seedphrase Editing](screenshots/Screenshot%20from%202026-02-16%2017-39-33.png)

#### Address Display
![Address Display](screenshots/Screenshot%20from%202026-02-16%2017-40-51.png)

#### PIN Setup
![PIN Setup](screenshots/Screenshot%20from%202026-02-16%2017-40-59.png)

#### Profile Setup
![Profile Setup](screenshots/Screenshot%20from%202026-02-16%2017-45-57.png)

#### Avatar Selection
![Avatar Selection](screenshots/Screenshot%20from%202026-02-16%2017-48-15.png)

#### Complete Setup
![Complete Setup](screenshots/Screenshot%20from%202026-02-16%2017-59-31.png)

---

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

## Account & Wallet Onboarding (2026 Edition)

### Enhanced First-Time Registration

The 2026 edition provides a completely redesigned onboarding experience:

1. **🌟 Welcome Screen** - Clean, focused interface to begin wallet creation
2. **🔤 Seedphrase Generation** - Automatic BIP39 seedphrase generation with:
   - Interactive word editing capabilities
   - Real-time BIP39 validation
   - Copy-to-clipboard functionality
   - NKN and EVM address display
3. **🔐 PIN Setup** - Secure PIN creation for wallet protection
4. **👤 Profile Setup** - Personalize your chat identity:
   - Username selection with Material Design input fields
   - Avatar upload and cropping
   - Skip option for later setup
5. **🎉 Complete Setup** - Ready to start chatting with your new identity

### Key Onboarding Features

- **🔤 BIP39 Word Editing**: Tap any word (1-11) to edit from the complete BIP39 wordlist
- **🔗 Address Generation**: See both NKN and EVM addresses derived from your seedphrase
- **👤 Material Design Profile**: Modern input fields for username and avatar setup
- **🎨 Enhanced UI**: Light grey headings and improved visual hierarchy
- **🔒 Security First**: Proper wallet integration with account management system

### Using Your Own Account (Import a Wallet)

- If you prefer to use your own account, you can import an existing wallet at any time.
- Open the app and go to: Settings → Account → Import Wallet.
- Follow the on-screen steps to complete the import.
- After import, your wallet becomes your active account.

### Notes

- Your keys are stored locally on your device. Make sure you back them up safely.
- The enhanced onboarding ensures proper wallet integration with the internal account management system.
- Profile setup is optional but recommended for the best chat experience.
- If you import a wallet, ensure you're in a private, secure environment.
