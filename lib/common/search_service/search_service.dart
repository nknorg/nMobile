import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../native/search.dart';

class SearchService {
  static String _apiBase = dotenv.get('NAME_SERVICE_API_BASE');

  final SearchClient _client;

  SearchService._(this._client);

  /// Create a query-only search service (no authentication required)
  static Future<SearchService> create() async {
    final client = await SearchClient.create(apiBase: _apiBase);
    return SearchService._(client);
  }

  /// Create an authenticated search service
  static Future<SearchService> createWithAuth({required Uint8List seed}) async {
    final client = await SearchClient.createWithAuth(
      apiBase: _apiBase,
      seed: seed,
    );
    return SearchService._(client);
  }

  /// Query by keyword
  Future<List<SearchResult>> query(String keyword) async {
    return await _client.query(keyword);
  }

  /// Submit or update user data (requires authentication)
  /// 
  /// Parameters:
  /// - nknAddress: NKN client address (optional, format: "identifier.publickey" or just publickey)
  ///               If empty, defaults to publickey. Must be either "identifier.publickey" format or equal to publickey.
  /// - customId: Custom identifier (optional, min 3 characters if provided)
  /// - nickname: User nickname (optional)
  /// - phoneNumber: Phone number (optional)
  /// 
  /// If the publicKey already exists, this will UPDATE the user data.
  /// 
  /// Examples:
  /// ```dart
  /// // Option 1: Use default (empty - will use publickey)
  /// await service.submitUserData(nickname: 'Alice');
  /// 
  /// // Option 2: Use publickey directly
  /// final pubKey = await service.getPublicKeyHex();
  /// await service.submitUserData(nknAddress: pubKey, nickname: 'Alice');
  /// 
  /// // Option 3: Use custom identifier.publickey format
  /// await service.submitUserData(
  ///   nknAddress: 'alice.${await service.getPublicKeyHex()}',
  ///   customId: 'user123',
  ///   nickname: 'Alice',
  /// );
  /// ```
  Future<void> submitUserData({
    String? nknAddress,
    String? customId,
    String? nickname,
    String? phoneNumber,
  }) async {
    await _client.submitUserData(
      nknAddress: nknAddress,
      customId: customId,
      nickname: nickname,
      phoneNumber: phoneNumber,
    );
  }

  /// Query by ID (requires authentication and verification)
  Future<SearchResult?> queryByID(String id) async {
    return await _client.queryByID(id);
  }

  /// Verify the client
  Future<void> verify() async {
    await _client.verify();
  }

  /// Check if client is verified
  Future<bool> isVerified() async {
    return await _client.isVerified();
  }

  /// Get public key
  Future<String> getPublicKeyHex() async {
    return await _client.getPublicKeyHex();
  }

  /// Get wallet address
  Future<String> getAddress() async {
    return await _client.getAddress();
  }

  /// Get my own information by querying with nknAddress
  /// 
  /// Parameters:
  /// - nknAddress: (Optional) The NKN address to query. If not provided, uses the authenticated client's publickey.
  ///               Can be in "identifier.publickey" format or just the publickey.
  /// 
  /// Returns the user's information if found, or null if not found.
  /// 
  /// Example:
  /// ```dart
  /// // Query using the authenticated client's publickey (recommended)
  /// final myInfo = await service.getMyInfo();
  /// 
  /// // Or query with a specific nknAddress
  /// final pubKey = await service.getPublicKeyHex();
  /// final myInfo = await service.getMyInfo(nknAddress: pubKey);
  /// 
  /// // Or with identifier.publickey format
  /// final myInfo = await service.getMyInfo(nknAddress: 'alice.$pubKey');
  /// ```
  Future<SearchResult?> getMyInfo({String? nknAddress}) async {
    // If nknAddress not provided, get the public key from the authenticated client
    final address = nknAddress ?? await _client.getPublicKeyHex();
    
    // Call the native getMyInfo method
    return await _client.getMyInfo(address);
  }

  /// Dispose the client and free resources
  Future<void> dispose() async {
    await _client.dispose();
  }
}
