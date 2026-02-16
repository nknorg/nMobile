import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing mnemonic phrases with fallback to default
class MnemonicService {
  static const String _secureMnemonicKey = 'primary_mnemonic';
  static const String _defaultMnemonicKey = 'default_mnemonic_set';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Default mnemonic from mnemonic.txt
  static const String _defaultMnemonic = 'all inflict taxi era caught season network helmet mobile busy pipe bicycle';
  
  /// Get the active mnemonic (user's custom one or default)
  static Future<String?> getMnemonic() async {
    try {
      // First check if user has set a custom mnemonic in secure storage
      final customMnemonic = await _secureStorage.read(key: _secureMnemonicKey);
      if (customMnemonic != null && customMnemonic.trim().isNotEmpty) {
        return customMnemonic.trim();
      }
      
      // If no custom mnemonic, ensure default is set in SharedPreferences and return it
      await _ensureDefaultMnemonicSet();
      return _defaultMnemonic;
    } catch (e) {
      print('Error getting mnemonic: $e');
      // Fallback to default mnemonic
      return _defaultMnemonic;
    }
  }
  
  /// Set a custom mnemonic (overrides default)
  static Future<void> setCustomMnemonic(String mnemonic) async {
    await _secureStorage.write(key: _secureMnemonicKey, value: mnemonic.trim());
  }
  
  /// Check if user has set a custom mnemonic
  static Future<bool> hasCustomMnemonic() async {
    try {
      final customMnemonic = await _secureStorage.read(key: _secureMnemonicKey);
      return customMnemonic != null && customMnemonic.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Remove custom mnemonic (falls back to default)
  static Future<void> removeCustomMnemonic() async {
    await _secureStorage.delete(key: _secureMnemonicKey);
  }
  
  /// Get the default mnemonic
  static String getDefaultMnemonic() {
    return _defaultMnemonic;
  }
  
  /// Ensure default mnemonic is marked as set in SharedPreferences
  static Future<void> _ensureDefaultMnemonicSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSet = prefs.getBool(_defaultMnemonicKey) ?? false;
      if (!isSet) {
        await prefs.setBool(_defaultMnemonicKey, true);
        print('Default mnemonic initialized from build');
      }
    } catch (e) {
      print('Error setting default mnemonic flag: $e');
    }
  }
  
  /// Check if this is the first run (no mnemonic set yet)
  static Future<bool> isFirstRun() async {
    try {
      final hasCustom = await hasCustomMnemonic();
      if (hasCustom) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final defaultSet = prefs.getBool(_defaultMnemonicKey) ?? false;
      return !defaultSet;
    } catch (e) {
      return true;
    }
  }
}
