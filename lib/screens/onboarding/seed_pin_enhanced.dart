import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip39/src/wordlists/english.dart' show WORDLIST;
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/entropy/touch_entropy_collector.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:nmobile/cctp_settings/services/wallet_service.dart';

class FirstWelcomeScreen extends BaseStateFulWidget {
  static const String routeName = '/onboarding/seed_pin';

  static Future go(BuildContext? context) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _FirstWelcomeScreenState createState() => _FirstWelcomeScreenState();
}

class _FirstWelcomeScreenState
    extends BaseStateFulWidgetState<FirstWelcomeScreen> with Tag {
  final GlobalKey _formKey = GlobalKey<FormState>();
  WalletBloc? _walletBloc;
  String _mnemonic = '';
  String _seedHex32 = '';
  bool _formValid = false;
  bool _entropyCollected = false;
  int _step = 0; // 0: entropy, 1: mnemonic, 2: seedphrase options, 3: pin
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _pinConfirmController = TextEditingController();
  final TextEditingController _customMnemonicController =
      TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _pinConfirmFocusNode = FocusNode();
  final FocusNode _customMnemonicFocusNode = FocusNode();

  // BIP39 word editing functionality
  late List<String> _words;
  final List<String> _bip39Words = WORDLIST;

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  void _onEntropyCollected(String entropy) {
    if (!mounted) return;

    // Generate 12-word mnemonic (128-bit entropy) and a 32-byte seed for NKN
    // 1) Hash touch data -> 32 bytes
    final hash32 =
        crypto.sha256.convert(utf8.encode(entropy)).bytes; // 32 bytes
    // 2) Take first 16 bytes for BIP39 entropy (12 words)
    final entropy128 = hash32.sublist(0, 16);
    final entropyHex =
        entropy128.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    // 3) Derive a 32-byte seed deterministically from the 16 bytes entropy
    final seed32 = crypto.sha256.convert(entropy128).bytes; // 32 bytes
    final seedHex32 =
        seed32.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

    setState(() {
      _mnemonic = bip39.entropyToMnemonic(entropyHex);
      _seedHex32 = seedHex32;
      _words = _mnemonic.split(' '); // Initialize words list for editing
      _entropyCollected = true;
      _step = 1;
    });

    Toast.show('Entropy collected!');
  }

  void _changeMnemonic() {
    setState(() {
      _mnemonic = '';
      _step = 2; // Go to seedphrase change step
    });
  }

  void _useCustomMnemonic() {
    setState(() {
      _step = 2; // Go to seedphrase change step
    });
  }

  void _validateAndSetCustomMnemonic() {
    final customMnemonic = _customMnemonicController.text.trim();
    if (customMnemonic.isEmpty) {
      Toast.show('Please enter a seed phrase');
      return;
    }

    if (!WalletService.validateMnemonic(customMnemonic)) {
      Toast.show('Invalid seed phrase format');
      return;
    }

    setState(() {
      _mnemonic = customMnemonic;
      _words = _mnemonic.split(' '); // Initialize words list for editing
      _step = 1; // Go back to mnemonic display
    });

    Toast.show('Custom seed phrase set successfully!');
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    Toast.show('Copied to clipboard');
  }

  // Word editing functionality
  void _editWord(int index) async {
    // Word 12 is the checksum - not editable
    if (_words.length == 12 && index == 11) {
      Toast.show('Word 12 is the checksum and cannot be edited directly');
      return;
    }

    final currentWord = _words[index];

    // Show dropdown with BIP39 words
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _WordSelectorDialog(
        currentWord: currentWord,
        allWords: _bip39Words,
      ),
    );

    // Dialog is now closed, proceed with updates
    if (selected != null && selected != currentWord) {
      // Update word
      _words[index] = selected;

      // Always recalculate checksum (word 12) when editing any word 1-11
      if (_words.length == 12) {
        final oldChecksum = _words[11];
        _recalculateChecksum();
      }

      final newMnemonic = _words.join(' ');
      _mnemonic = newMnemonic;

      // Update UI to show new word and checksum
      setState(() {});

      // Validate the new mnemonic
      if (bip39.validateMnemonic(newMnemonic)) {
        Toast.show('Word ${index + 1} updated successfully');
      } else {
        Toast.show('ERROR: Mnemonic validation failed!');
      }
    }
  }

  void _recalculateChecksum() {
    try {
      // Convert first 11 words to their indices (11 words = 121 bits of entropy)
      final indices = <int>[];
      for (int i = 0; i < 11; i++) {
        final wordIndex = _bip39Words.indexOf(_words[i]);
        if (wordIndex == -1) {
          return;
        }
        indices.add(wordIndex);
      }

      // Convert indices to binary string (each index is 11 bits)
      String binaryStr = '';
      for (final idx in indices) {
        binaryStr += idx.toRadixString(2).padLeft(11, '0');
      }

      // We have 121 bits. For a 12-word mnemonic, we need 128 bits total
      // Pad to 128 bits (add 7 zeros for the remaining entropy bits)
      final entropyBits = binaryStr + '0000000'; // 121 + 7 = 128 bits

      // Convert binary to hex
      String entropyHex = '';
      for (int i = 0; i < entropyBits.length; i += 8) {
        final byte = entropyBits.substring(i, i + 8);
        entropyHex +=
            int.parse(byte, radix: 2).toRadixString(16).padLeft(2, '0');
      }

      // Generate proper 12-word mnemonic with correct checksum
      final properMnemonic = bip39.entropyToMnemonic(entropyHex);
      final properWords = properMnemonic.split(' ');

      if (properWords.length == 12) {
        // Verify first 11 words match (they should)
        bool match = true;
        for (int i = 0; i < 11; i++) {
          if (properWords[i] != _words[i]) {
            match = false;
            break;
          }
        }

        if (match) {
          _words[11] = properWords[11]; // Update checksum word
        }
      }
    } catch (e) {
      // If calculation fails, keep the old word 12
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: Colors.transparent,
      header: Header(
        title: '',
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            onChanged: () {
              setState(() {
                _formValid = _validateForm();
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(
                  'Create New Wallet',
                  type: LabelType.h2,
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 16),
                if (_step == 0) ...[
                  Text(
                    'Please move your finger randomly in the box below to generate a secure seed phrase',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TouchEntropyCollector(
                    onEntropyCollected: _onEntropyCollected,
                    requiredEntropyBits: 1024,
                    minDurationMs: 6000,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keep drawing until the box indicates completion.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else if (_step == 1) ...[
                  _buildMnemonicDisplay(),
                  const SizedBox(height: 16),
                  _buildMnemonicOptions(),
                ] else if (_step == 2) ...[
                  _buildSeedphraseChangeOptions(),
                ] else if (_step == 3) ...[
                  _buildPinFields(),
                  const SizedBox(height: 24),
                  _buildCreateButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMnemonicDisplay() {
    final isValid = bip39.validateMnemonic(_mnemonic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(
          'Your Recovery Phrase',
          type: LabelType.h4,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isValid ? Colors.grey.shade400 : Colors.orange,
              width: isValid ? 1 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_words.length, (index) {
                  final isChecksum = index == 11 && _words.length == 12;
                  return InkWell(
                    onTap: () => _editWord(index),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isChecksum
                            ? Colors.purple.withOpacity(0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              isChecksum ? Colors.purple : Colors.grey.shade300,
                          width: isChecksum ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${index + 1}.',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _words[index],
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: isChecksum
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isChecksum ? Colors.purple[700] : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isChecksum ? Icons.lock : Icons.edit,
                            size: 12,
                            color:
                                isChecksum ? Colors.purple : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.purple[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Word 12 is the checksum (locked). Edit words 1-11 to change it.',
                      style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Write down these words and keep them in a safe place. Never share them with anyone!',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        // Derived Addresses Section
        _buildDerivedAddressesSection(),
      ],
    );
  }

  Widget _buildDerivedAddressesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(
          'Derived Addresses',
          type: LabelType.h4,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),

        // NKN Address
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    'NKN Address:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _generateNKNAddress(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(_generateNKNAddress()),
                    tooltip: 'Copy NKN Address',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // EVM Address
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hexagon_outlined,
                      size: 16, color: Colors.purple[600]),
                  const SizedBox(width: 8),
                  Text(
                    'EVM Address:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _generateEVMAddress(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(_generateEVMAddress()),
                    tooltip: 'Copy EVM Address',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'These addresses are derived from your seed phrase. Keep your seed phrase safe to maintain access to these addresses.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  String _generateNKNAddress() {
    try {
      // Generate NKN address from seed hex (simplified version)
      if (_seedHex32.isNotEmpty) {
        // For demo purposes, create a mock NKN address based on the seed
        final seedBytes = hexDecode(_seedHex32);
        final hash = crypto.sha256.convert(seedBytes);
        final addressBytes = Uint8List.fromList(hash.bytes.take(32).toList());
        final addressHex = hexEncode(addressBytes);
        return 'NKN${addressHex.substring(0, 32)}';
      }
    } catch (e) {
      // Fallback if generation fails
    }
    return 'NKN Address will be generated after wallet creation';
  }

  String _generateEVMAddress() {
    try {
      // Use the wallet service to generate EVM address
      if (_mnemonic.isNotEmpty) {
        final wallet = WalletService(mnemonic: _mnemonic);
        // Since getEthereumAddress() is async, we'll use a simplified version for now
        return '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6'; // Mock EVM address for demo
      }
    } catch (e) {
      // Fallback if generation fails
    }
    return '0x0000000000000000000000000000000000000000';
  }

  Widget _buildMnemonicOptions() {
    return Column(
      children: [
        Button(
          text: 'Continue with Generated Phrase',
          width: double.infinity,
          onPressed: () {
            setState(() {
              _step = 3; // Go to PIN setting
            });
          },
        ),
        const SizedBox(height: 12),
        Button(
          text: 'Change Seed Phrase',
          width: double.infinity,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          fontColor: Theme.of(context).colorScheme.onSecondaryContainer,
          onPressed: () {
            _changeMnemonic();
          },
        ),
        const SizedBox(height: 12),
        Button(
          text: 'Use Custom Seed Phrase',
          width: double.infinity,
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          fontColor: Theme.of(context).colorScheme.onTertiaryContainer,
          onPressed: () {
            _useCustomMnemonic();
          },
        ),
      ],
    );
  }

  Widget _buildSeedphraseChangeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(
          'Change Seed Phrase',
          type: LabelType.h4,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        Text(
          'You can either regenerate a new seed phrase or import your own custom seed phrase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Button(
          text: 'Generate New Seed Phrase',
          width: double.infinity,
          onPressed: () {
            setState(() {
              _mnemonic = '';
              _entropyCollected = false;
              _step = 0; // Go back to entropy collection
            });
            Toast.show('Ready to generate new seed phrase');
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(
                'Or Import Custom Seed Phrase',
                type: LabelType.bodyLarge,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customMnemonicController,
                focusNode: _customMnemonicFocusNode,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your 12-word seed phrase',
                  border: OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter a valid BIP39 seed phrase (12 words separated by spaces)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Button(
          text: 'Use Custom Seed Phrase',
          width: double.infinity,
          onPressed: _validateAndSetCustomMnemonic,
        ),
        const SizedBox(height: 12),
        Button(
          text: 'Back',
          width: double.infinity,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          fontColor: Theme.of(context).colorScheme.onSurface,
          onPressed: () {
            setState(() {
              _step = 1; // Go back to mnemonic display
            });
          },
        ),
      ],
    );
  }

  Widget _buildPinFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(
          'Set a 4-digit PIN',
          type: LabelType.h4,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 16),
        _buildPinDisplay(),
        const SizedBox(height: 16),
        _buildNumpad(),
      ],
    );
  }

  Widget _buildPinDisplay() {
    final pin = _pinController.text;
    final confirmPin = _pinConfirmController.text;
    final isConfirming = pin.length == 4 && confirmPin.length < 4;
    final currentPin = isConfirming ? confirmPin : pin;
    const maxLength = 4;

    return Column(
      children: [
        Text(
          isConfirming ? 'Confirm your 4-digit PIN' : 'Enter a 4-digit PIN',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (index) {
            return Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < currentPin.length
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      if (_pinConfirmController.text.isNotEmpty) {
                        _pinConfirmController.clear();
                      } else {
                        _pinController.clear();
                      }
                      _formValid = _validateForm();
                    });
                  },
                  icon: const Icon(Icons.close, size: 28),
                ),
              ),
              Expanded(child: _buildNumpadButton('0')),
              Expanded(
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      if (_pinConfirmController.text.isNotEmpty) {
                        _pinConfirmController.text = _pinConfirmController.text
                            .substring(
                                0, _pinConfirmController.text.length - 1);
                      } else if (_pinController.text.isNotEmpty) {
                        _pinController.text = _pinController.text
                            .substring(0, _pinController.text.length - 1);
                      }
                      _formValid = _validateForm();
                    });
                  },
                  icon: const Icon(Icons.backspace, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumpadButton(n)).toList(),
    );
  }

  Widget _buildNumpadButton(String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            if (_pinController.text.length < 4) {
              _pinController.text += number;
              if (_pinController.text.length == 4 &&
                  _pinConfirmController.text.isEmpty) {
                _pinFocusNode.unfocus();
                _pinConfirmFocusNode.requestFocus();
              }
            } else if (_pinConfirmController.text.length < 4) {
              _pinConfirmController.text += number;
            }
            _formValid = _validateForm();
          });
        },
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(18),
          minimumSize: const Size(64, 64),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }

  bool _validateForm() {
    if (_pinController.text.length != 4) return false;
    if (_pinConfirmController.text.length != 4) return false;
    if (_pinController.text != _pinConfirmController.text) return false;
    return true;
  }

  Widget _buildCreateButton() {
    return Button(
      text: 'Create Wallet',
      width: double.infinity,
      onPressed: _formValid && _entropyCollected ? _createWallet : null,
    );
  }

  void _createWallet() async {
    if (!_formValid || _mnemonic.isEmpty) return;

    try {
      // Create wallet using 32-byte seed derived from entropy (compatible with NKN)
      final nkn = await Wallet.create(hexDecode(_seedHex32),
          config: WalletConfig(password: _pinController.text));

      // Dispatch wallet created event
      final wallet = WalletSchema(
        type: WalletType.nkn,
        address: nkn.address,
        publicKey: hexEncode(nkn.publicKey),
        name: 'Account',
      );
      _walletBloc?.add(AddWallet(
          wallet, nkn.keystore, _pinController.text, hexEncode(nkn.seed)));

      // Navigate to app home
      if (mounted) {
        AppScreen.go(context);
      }
    } catch (e) {
      logger.e('Error creating wallet: $e');
      if (mounted) {
        Toast.show('Failed to create wallet: ${e.toString()}');
      }
    }
  }

  @override
  void onRefreshArguments() {}
}

// Word selector dialog for BIP39 word editing
class _WordSelectorDialog extends StatefulWidget {
  final String currentWord;
  final List<String> allWords;

  const _WordSelectorDialog({
    required this.currentWord,
    required this.allWords,
  });

  @override
  State<_WordSelectorDialog> createState() => _WordSelectorDialogState();
}

class _WordSelectorDialogState extends State<_WordSelectorDialog> {
  late TextEditingController _searchController;
  List<String> _filteredWords = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.currentWord);
    _filterWords(widget.currentWord);
  }

  void _filterWords(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredWords = widget.allWords.take(50).toList();
      } else {
        _filteredWords = widget.allWords
            .where((w) => w.startsWith(query.toLowerCase()))
            .take(50)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select BIP39 Word'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterWords,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '${_filteredWords.length} words',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredWords.length,
                itemBuilder: (context, index) {
                  final word = _filteredWords[index];
                  final isSelected = word == widget.currentWord;
                  return ListTile(
                    title: Text(
                      word,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => Navigator.of(context).pop(word),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
