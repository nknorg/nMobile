import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bip39/src/wordlists/english.dart' show WORDLIST;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/balance_cache_service.dart';
import '../services/mnemonic_service.dart';
import '../services/token_database_service.dart';
import '../services/wallet_service.dart';
import '../wallet/wallet_provider.dart';
import '../wallet/wallet_mode.dart';

class CCTPSettingsScreen extends StatefulWidget {
  const CCTPSettingsScreen({super.key});

  @override
  State<CCTPSettingsScreen> createState() => _CCTPSettingsScreenState();
}

class _CCTPSettingsScreenState extends State<CCTPSettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _borderAnimController;
  static const _secureSeedKey = 'primary_seed_b64';
  static const _secureMnemonicKey = 'primary_mnemonic';
  // PIN storage (salted SHA-256)
  static const _securePinSaltKey = 'seed_pin_salt_b64';
  static const _securePinHashKey = 'seed_pin_hash_hex';
  // PIN rate limiting
  static const _securePinAttemptsKey = 'seed_pin_attempts';
  static const _securePinLockUntilKey = 'seed_pin_lock_until_ms';

  final _secureStorage = const FlutterSecureStorage();

  String? _savedMnemonicPreview;
  bool _loadingSaved = true;
  // When entropy collection is active, disable parent scroll
  bool _entropyCollecting = false;
  // Configurable endpoints
  static const _priceApiBaseKey = 'nride_price_api_base';
  final TextEditingController _priceApiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _borderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadSaved();
  }

  Future<void> _loadSaved() async {
    final m = await _secureStorage.read(key: _secureMnemonicKey);
    final prefs = await SharedPreferences.getInstance();
    // Read saved base; migrate deprecated provider if found
    String? savedBase = prefs.getString(_priceApiBaseKey);
    if (savedBase != null && savedBase.contains('akash-palmito')) {
      savedBase = 'http://provider.europlots.com:31642/';
      await prefs.setString(_priceApiBaseKey, savedBase);
    }
    final apiBase = savedBase ?? 'http://provider.europlots.com:31642/';
    setState(() {
      _savedMnemonicPreview = m;
      _loadingSaved = false;
      _priceApiController.text = apiBase;
    });
  }

  Future<void> _savePrimarySeedToSecureStorage(String mnemonic) async {
    // Derive 64-byte BIP39 seed and store as base64 in secure storage
    final seed = bip39.mnemonicToSeed(mnemonic);
    final b64 = base64Encode(seed);
    await _secureStorage.write(key: _secureSeedKey, value: b64);
    // Also store the mnemonic itself securely for components that require words
    await _secureStorage.write(key: _secureMnemonicKey, value: mnemonic);
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  // ---------- PIN utilities ----------
  Future<bool> _hasPin() async {
    final salt = await _secureStorage.read(key: _securePinSaltKey);
    final hash = await _secureStorage.read(key: _securePinHashKey);
    return salt != null && hash != null && salt.isNotEmpty && hash.isNotEmpty;
  }

  String _hashPin(String pin, List<int> salt) {
    final bytes =
        <int>[]
          ..addAll(salt)
          ..addAll(utf8.encode(pin));
    final digest = crypto.sha256.convert(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _setPin(String pin) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hash = _hashPin(pin, salt);
    await _secureStorage.write(
      key: _securePinSaltKey,
      value: base64Encode(salt),
    );
    await _secureStorage.write(key: _securePinHashKey, value: hash);
    await _clearPinFailures();
  }

  Future<String?> _showPinPadDialog(String title) async {
    String value = '';
    String? error;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setLocal) => AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < value.length;
                          return Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  filled
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 260,
                        child: Column(
                          children: [
                            for (final row in const [
                              ['1', '2', '3'],
                              ['4', '5', '6'],
                              ['7', '8', '9'],
                            ])
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children:
                                    row
                                        .map(
                                          (d) => _pinKeyButton(
                                            d,
                                            onTap: () {
                                              if (value.length < 4)
                                                setLocal(() {
                                                  value += d;
                                                  error = null;
                                                });
                                            },
                                          ),
                                        )
                                        .toList(),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _pinActionButton(
                                  Icons.backspace_outlined,
                                  onTap: () {
                                    if (value.isNotEmpty)
                                      setLocal(() {
                                        value = value.substring(
                                          0,
                                          value.length - 1,
                                        );
                                      });
                                  },
                                ),
                                _pinKeyButton(
                                  '0',
                                  onTap: () {
                                    if (value.length < 4)
                                      setLocal(() {
                                        value += '0';
                                        error = null;
                                      });
                                  },
                                ),
                                _pinActionButton(
                                  Icons.clear,
                                  onTap: () {
                                    setLocal(() {
                                      value = '';
                                      error = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          value.length == 4
                              ? () => Navigator.of(ctx).pop(value)
                              : null,
                      child: const Text('OK'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _pinKeyButton(String label, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: SizedBox(
        width: 60,
        height: 44,
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _pinActionButton(IconData icon, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: SizedBox(
        width: 60,
        height: 44,
        child: OutlinedButton(onPressed: onTap, child: Icon(icon)),
      ),
    );
  }

  Future<void> _clearPinFailures() async {
    await _secureStorage.write(key: _securePinAttemptsKey, value: '0');
    await _secureStorage.delete(key: _securePinLockUntilKey);
  }

  Future<bool> _recordFailedAttempt({
    int maxAttempts = 3,
    int lockMs = 60000,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attemptsStr = await _secureStorage.read(key: _securePinAttemptsKey);
    int attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
    attempts += 1;
    if (attempts >= maxAttempts) {
      final lockUntil = now + lockMs;
      await _secureStorage.write(
        key: _securePinLockUntilKey,
        value: lockUntil.toString(),
      );
      await _secureStorage.write(key: _securePinAttemptsKey, value: '0');
      return true; // locked
    } else {
      await _secureStorage.write(
        key: _securePinAttemptsKey,
        value: attempts.toString(),
      );
      return false;
    }
  }

  Future<bool> _createPinFlow() async {
    final p1 = await _showPinPadDialog('Set 4-digit PIN');
    if (p1 == null) return false;
    if (p1.length != 4 || int.tryParse(p1) == null) return false;
    final p2 = await _showPinPadDialog('Confirm PIN');
    if (p2 == null) return false;
    if (p1 != p2) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PINs do not match')));
      }
      return false;
    }
    await _setPin(p1);
    return true;
  }

  Future<bool> _verifyPinFlow() async {
    final has = await _hasPin();
    if (!has) {
      final created = await _createPinFlow();
      if (!created) return false;
    }
    // Check lock status
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockStr = await _secureStorage.read(key: _securePinLockUntilKey);
    final lockUntil = int.tryParse(lockStr ?? '') ?? 0;
    if (now < lockUntil) {
      final remaining = ((lockUntil - now) / 1000).ceil();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN locked. Try again in ${remaining}s')),
      );
      return false;
    }
    final saltB64 = await _secureStorage.read(key: _securePinSaltKey);
    final hashHex = await _secureStorage.read(key: _securePinHashKey);
    if (saltB64 == null || hashHex == null) return false;
    final salt = base64Decode(saltB64);

    final entered = await _showPinPadDialog('Enter PIN');
    if (entered == null) return false;
    if (entered.length != 4 || int.tryParse(entered) == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      }
      return false;
    }
    final calc = _hashPin(entered, salt);
    if (calc != hashHex) {
      final locked = await _recordFailedAttempt();
      if (locked) {
        if (mounted) {
          final lockStr2 = await _secureStorage.read(
            key: _securePinLockUntilKey,
          );
          final until = int.tryParse(lockStr2 ?? '') ?? 0;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final remaining =
              until > nowMs ? ((until - nowMs) / 1000).ceil() : 60;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Too many attempts. Locked for ${remaining}s'),
            ),
          );
        }
        return false;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
        }
        return false;
      }
    }
    await _clearPinFailures();
    return true;
  }

  Future<String?> _readSavedMnemonic() async {
    return await _secureStorage.read(key: _secureMnemonicKey);
  }

  Future<void> _exportSeedWithPin() async {
    final ok = await _verifyPinFlow();
    if (!ok) return;
    final mnemonic = await _readSavedMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo seedphrase fallback mode')),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Your Seed Phrase'),
            content: SingleChildScrollView(
              child: SelectableText(
                mnemonic,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _copyToClipboard(mnemonic);
                  if (mounted) Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final updated = await _createPinFlow();
                  if (!mounted) return;
                  if (updated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN updated successfully')),
                    );
                  }
                },
                icon: const Icon(Icons.password),
                label: const Text('Renew PIN'),
              ),
            ],
          ),
    );
  }

  Future<void> _scanQRCode(TextEditingController controller) async {
    String? scannedText;
    final mobileScannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    try {
      await showDialog<void>(
        context: context,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Scan QR Code'),
                  content: SizedBox(
                    height: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Camera preview
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: MobileScanner(
                                controller: mobileScannerController,
                                onDetect: (capture) {
                                  final barcodes = capture.barcodes;
                                  if (barcodes.isNotEmpty) {
                                    final barcode = barcodes.first;
                                    if (barcode.rawValue != null) {
                                      scannedText = barcode.rawValue;
                                      setState(() {}); // Update the UI
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Scanned text display
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Scanned Seed Phrase',
                            border: OutlineInputBorder(),
                            hintText: 'QR code content will appear here',
                          ),
                          controller: TextEditingController(
                            text: scannedText ?? '',
                          ),
                          readOnly: true,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Point the camera at a QR code containing a seed phrase',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          scannedText != null
                              ? () => Navigator.of(context).pop(scannedText)
                              : null,
                      child: const Text('Use This'),
                    ),
                  ],
                );
              },
            ),
      );

      if (scannedText != null && scannedText!.isNotEmpty) {
        controller.text = scannedText!;
      }
    } finally {
      // Always dispose the controller when done
      await mobileScannerController.dispose();
    }
  }

  Future<void> _openImportDialog({String? prefilledMnemonic}) async {
    final controller = TextEditingController(text: prefilledMnemonic ?? '');
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Import Seed Phrase'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'BIP39 mnemonic',
                      hintText: 'Enter your seed phrase',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          await _scanQRCode(controller);
                        },
                        tooltip: 'Scan QR Code',
                      ),
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your seed phrase will be stored securely on this device (Secure Storage).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final input = controller.text.trim();
                    if (input.isEmpty) {
                      setLocalState(
                        () => errorText = 'Seed phrase cannot be empty',
                      );
                      return;
                    }
                    if (!WalletService.validateMnemonic(input)) {
                      setLocalState(() => errorText = 'Invalid BIP39 mnemonic');
                      return;
                    }
                    // Enforce PIN exists; if not, require creation before saving
                    final hasPin = await _hasPin();
                    if (!hasPin) {
                      final created = await _createPinFlow();
                      if (!created) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'PIN setup required to save the seed',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    await _savePrimarySeedToSecureStorage(input);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Seed saved (secure). PIN set/enforced.'),
                      ),
                    );
                    _loadSaved();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Load derived addresses from the mnemonic or connected wallet (EVM and Solana only)
  Future<Map<String, String>> _loadDerivedAddresses() async {
    final addresses = <String, String>{};

    try {
      // Check wallet provider first
      final walletProvider = Provider.of<WalletProvider>(
        context,
        listen: false,
      );

      if ((walletProvider.mode == WalletMode.externalWallet ||
              walletProvider.mode == WalletMode.seedVault) &&
          walletProvider.isWalletConnected &&
          walletProvider.walletAddress != null) {
        // Use connected wallet Solana address
        addresses['solana'] = walletProvider.walletAddress!;

        // For EVM, we still need the mnemonic
        final mnemonic = await MnemonicService.getMnemonic();
        if (mnemonic != null && WalletService.validateMnemonic(mnemonic)) {
          final wallet = WalletService(mnemonic: mnemonic);
          addresses['ethereum'] = await wallet.getEthereumAddress();
        } else {
          addresses['ethereum'] = 'Import seed for EVM';
        }
      } else {
        // Use local wallet from mnemonic
        final mnemonic = await MnemonicService.getMnemonic();
        if (mnemonic != null && WalletService.validateMnemonic(mnemonic)) {
          final wallet = WalletService(mnemonic: mnemonic);
          addresses['solana'] = await wallet.getSolanaAddress();
          addresses['ethereum'] = await wallet.getEthereumAddress();
        }
      }
    } catch (e) {
      debugPrint('Error loading derived addresses: $e');
    }

    return addresses;
  }

  /// Build a row showing a blockchain name and its address with copy button
  Widget _buildAddressRow(String chain, String address, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chainColors = <String, Color>{
      'Solana': Colors.purple,
      'Ethereum': Colors.blue,
    };
    final chainIcons = <String, IconData>{
      'Solana': Icons.flash_on,
      'Ethereum': Icons.hexagon_outlined,
    };
    final color = chainColors[chain] ?? colorScheme.primary;
    final icon = chainIcons[chain] ?? Icons.account_balance_wallet;
    final isPlaceholder =
        address.startsWith('Import') || address.startsWith('N/A');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chain,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color:
                        isPlaceholder
                            ? Colors.orange
                            : colorScheme.onSurface.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isPlaceholder)
            IconButton(
              icon: Icon(Icons.copy, size: 16, color: color),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$chain address copied')),
                );
              },
              tooltip: 'Copy $chain address',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  /// Wraps a child widget in an animated rotating gradient border
  Widget _buildAnimatedBorderCard({
    required Widget child,
    double borderWidth = 2.0,
    double borderRadius = 16.0,
    List<Color>? colors,
  }) {
    final gradientColors =
        colors ??
        [Colors.blue, Colors.purple, Colors.pink, Colors.orange, Colors.blue];
    return AnimatedBuilder(
      animation: _borderAnimController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: 0.0,
              endAngle: 2 * pi,
              transform: GradientRotation(_borderAnimController.value * 2 * pi),
              colors: gradientColors,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(borderWidth),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(borderRadius - borderWidth),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Gradient header matching the map popup style
  Widget _buildGradientHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    List<Color>? gradientColors,
  }) {
    final colors =
        gradientColors ?? [Colors.indigo.shade600, Colors.blue.shade700];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCTP Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loadingSaved
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seed Phrase Management Section
                    _buildAnimatedBorderCard(
                      child: Column(
                        children: [
                          _buildGradientHeader(
                            icon: Icons.vpn_key,
                            title: 'Seed Phrase Management',
                            subtitle: 'Import and manage your wallet seed',
                            gradientColors: [Colors.deepPurple, Colors.purple],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                if (_savedMnemonicPreview != null) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, 
                                           color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      const Text('Seed phrase imported'),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _exportSeedWithPin,
                                        child: const Text('View'),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Icon(Icons.warning, 
                                           color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      const Text('No seed phrase imported'),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        onPressed: _openImportDialog,
                                        icon: const Icon(Icons.import_export),
                                        label: const Text('Import'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Derived Addresses Section
                    FutureBuilder<Map<String, String>>(
                      future: _loadDerivedAddresses(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final addresses = snapshot.data ?? {};
                        
                        return _buildAnimatedBorderCard(
                          child: Column(
                            children: [
                              _buildGradientHeader(
                                icon: Icons.account_balance_wallet,
                                title: 'Derived Addresses',
                                subtitle: 'EVM and Solana addresses from your seed',
                                gradientColors: [Colors.blue, Colors.cyan],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildAddressRow('Ethereum', 
                                                     addresses['ethereum'] ?? 'Import seed', 
                                                     context),
                                    const SizedBox(height: 8),
                                    _buildAddressRow('Solana', 
                                                     addresses['solana'] ?? 'Import seed', 
                                                     context),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Settings Section
                    _buildAnimatedBorderCard(
                      child: Column(
                        children: [
                          _buildGradientHeader(
                            icon: Icons.settings,
                            title: 'Settings',
                            subtitle: 'Application preferences',
                            gradientColors: [Colors.green, Colors.teal],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.api),
                                  title: const Text('Price API Base'),
                                  subtitle: Text(_priceApiController.text),
                                  trailing: const Icon(Icons.edit),
                                  onTap: () async {
                                    final result = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Edit Price API Base URL'),
                                        content: TextField(
                                          controller: _priceApiController,
                                          decoration: const InputDecoration(
                                            labelText: 'API Base URL',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, _priceApiController.text),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    );
                                    
                                    if (result != null) {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setString(_priceApiBaseKey, result);
                                      setState(() {});
                                    }
                                  },
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.security),
                                  title: const Text('PIN Security'),
                                  subtitle: const Text('Manage your PIN for seed access'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    final hasPin = await _hasPin();
                                    if (hasPin) {
                                      await _createPinFlow();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No PIN set yet')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _borderAnimController.dispose();
    _priceApiController.dispose();
    super.dispose();
  }
}
