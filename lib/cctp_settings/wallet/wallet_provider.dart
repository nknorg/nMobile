import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'wallet_mode.dart';

class WalletProvider extends ChangeNotifier {
  WalletMode _mode = WalletMode.localWallet;
  bool _isLoading = true;

  WalletMode get mode => _mode;
  bool get isLoading => _isLoading;

  // External wallet getters (simplified for EVM/Solana only)
  bool get isExternalWalletConnected => false; // Simplified
  String? get externalWalletAddress => null; // Simplified

  // Seed Vault getters (simplified for EVM/Solana only)
  bool get isSeedVaultConnected => false; // Simplified
  String? get seedVaultAddress => null; // Simplified

  // Unified wallet address getter
  String? get walletAddress {
    switch (_mode) {
      case WalletMode.externalWallet:
        return externalWalletAddress;
      case WalletMode.seedVault:
        return seedVaultAddress;
      case WalletMode.localWallet:
        return null; // Local wallet uses mnemonic service
    }
  }

  // Unified connection status
  bool get isWalletConnected {
    switch (_mode) {
      case WalletMode.externalWallet:
        return isExternalWalletConnected;
      case WalletMode.seedVault:
        return isSeedVaultConnected;
      case WalletMode.localWallet:
        return true; // Local wallet is always "connected" if mnemonic exists
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simplified initialization for EVM/Solana only
      _mode = WalletMode.localWallet; // Default to local wallet
    } catch (e) {
      debugPrint('WalletProvider initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setMode(WalletMode newMode) async {
    if (_mode == newMode) return;

    // Clear existing sessions (simplified)
    _mode = newMode;
    notifyListeners();
  }

  Future<bool> connectExternalWallet(BuildContext context) async {
    // Simplified external wallet connection for EVM/Solana only
    notifyListeners();
    return false; // Not implemented in simplified version
  }

  Future<bool> disconnectExternalWallet() async {
    // Simplified external wallet disconnection
    notifyListeners();
    return true;
  }

  Future<bool> connectSeedVault(BuildContext context) async {
    // Simplified Seed Vault connection for EVM/Solana only
    notifyListeners();
    return false; // Not implemented in simplified version
  }

  Future<bool> disconnectSeedVault() async {
    // Simplified Seed Vault disconnection
    notifyListeners();
    return true;
  }

  Future<Uint8List?> signTransaction(
    Uint8List transaction,
    String cluster,
  ) async {
    if (_mode == WalletMode.externalWallet) {
      // Simplified signing for EVM/Solana only
      return null;
    }
    // Local wallet and Seed Vault signing not implemented in this provider
    return null;
  }
}
