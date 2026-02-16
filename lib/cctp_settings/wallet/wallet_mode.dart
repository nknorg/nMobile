enum WalletMode {
  localWallet,
  externalWallet,
  seedVault,
}

extension WalletModeStorage on WalletMode {
  String get storageValue {
    switch (this) {
      case WalletMode.localWallet:
        return 'local';
      case WalletMode.externalWallet:
        return 'external';
      case WalletMode.seedVault:
        return 'seedVault';
    }
  }

  String get displayName {
    switch (this) {
      case WalletMode.localWallet:
        return 'Local Wallet (Mnemonic)';
      case WalletMode.externalWallet:
        return 'External Wallet (Solflare/Phantom)';
      case WalletMode.seedVault:
        return 'Seed Vault';
    }
  }
}

extension WalletModeParsing on String {
  WalletMode toWalletMode() {
    switch (this) {
      case 'external':
        return WalletMode.externalWallet;
      case 'seedVault':
        return WalletMode.seedVault;
      case 'local':
      default:
        return WalletMode.localWallet;
    }
  }
}
