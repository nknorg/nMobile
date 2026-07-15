import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/search_service/search_service.dart';

/// Custom ID state model
/// Stores multiple customIds mapped by nknAddress
class CustomIdState {
  // Map of nknAddress -> customId
  final Map<String, String?> customIdMap;
  final bool isLoading;
  final String? error;

  const CustomIdState({
    Map<String, String?>? customIdMap,
    this.isLoading = false,
    this.error,
  }) : customIdMap = customIdMap ?? const {};

  CustomIdState copyWith({
    Map<String, String?>? customIdMap,
    bool? isLoading,
    String? error,
  }) {
    return CustomIdState(
      customIdMap: customIdMap ?? this.customIdMap,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get customId for a given nknAddress
  /// Returns null if not found
  String? getCustomId(String? nknAddress) {
    if (nknAddress == null || nknAddress.isEmpty) return null;
    
    // Try exact match first
    if (customIdMap.containsKey(nknAddress)) {
      return customIdMap[nknAddress];
    }
    
    // Try matching by publickey (handle "identifier.publickey" format)
    final publicKey = nknAddress.contains('.') ? nknAddress.split('.').last : nknAddress;
    
    // Check all keys for matching publickey
    for (final key in customIdMap.keys) {
      final keyPublicKey = key.contains('.') ? key.split('.').last : key;
      if (keyPublicKey == publicKey) {
        return customIdMap[key];
      }
    }
    
    return null;
  }
}

/// Custom ID Notifier - Riverpod 3.0 API (without code generation)
class CustomIdNotifier extends Notifier<CustomIdState> {
  @override
  CustomIdState build() {
    return const CustomIdState();
  }

  /// Load custom ID from server
  /// Parameters:
  /// - seed: User's seed for authentication
  /// - nknAddress: NKN client address (can be "identifier.publickey" format or just publickey)
  Future<void> loadCustomId(Uint8List seed, String nknAddress) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create authenticated search service
      final service = await SearchService.createWithAuth(seed: seed);

      // Get my info using the nknAddress
      final myInfo = await service.getMyInfo(nknAddress: nknAddress);

      
      // Dispose the service
      await service.dispose();

      // Update the map with the new customId for this nknAddress
      final updatedMap = Map<String, String?>.from(state.customIdMap);
      updatedMap[nknAddress] = myInfo?.customId;

      if (myInfo == null) {
        // No data found - user hasn't submitted custom ID yet (not an error)
        state = state.copyWith(
          customIdMap: updatedMap,
          isLoading: false,
          error: null,
        );
      } else {
        // Update state with custom ID (can be null if not set) and associated nknAddress
        state = state.copyWith(
          customIdMap: updatedMap,
          isLoading: false,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update custom ID (after user submits)
  /// Parameters:
  /// - customId: The custom ID to set
  /// - nknAddress: The NKN address associated with this customId
  void setCustomId(String? customId, String? nknAddress) {
    if (nknAddress?.isNotEmpty != true) return;
    
    final updatedMap = Map<String, String?>.from(state.customIdMap);
    updatedMap[nknAddress!] = customId;
    state = state.copyWith(customIdMap: updatedMap);
  }

  /// Clear custom ID for a specific address
  void clearCustomId(String? nknAddress) {
    if (nknAddress == null || nknAddress.isEmpty) return;
    
    final updatedMap = Map<String, String?>.from(state.customIdMap);
    updatedMap.remove(nknAddress);
    state = state.copyWith(customIdMap: updatedMap);
  }

  /// Clear all custom IDs
  void clear() {
    state = const CustomIdState();
  }
}

/// Custom ID Provider - Riverpod 3.0 API
final customIdProvider = NotifierProvider<CustomIdNotifier, CustomIdState>(() {
  return CustomIdNotifier();
});

