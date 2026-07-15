import 'package:flutter/services.dart';
import 'dart:convert';

/// NKN Search Client for Flutter
/// Provides search and profile management functionality via platform channels
class SearchClient {
  static const MethodChannel _channel = MethodChannel('org.nkn.mobile/native/search');

  String? _clientId;
  final String apiBase;
  final Uint8List? seed;
  final bool isAuthMode;

  // Private constructor
  SearchClient._({
    required this.apiBase,
    this.seed,
    required this.isAuthMode,
  });

  /// Create a query-only search client
  /// Does not require authentication, only for querying public data
  static Future<SearchClient> create({
    required String apiBase,
  }) async {
    final client = SearchClient._(
      apiBase: apiBase,
      isAuthMode: false,
    );
    await client._initialize();
    return client;
  }

  /// Create an authenticated search client
  /// Required for writing data and authenticated queries
  /// 
  /// Parameters:
  /// - apiBase: API server address (e.g., "https://search.nkn.org/api/v1")
  /// - seed: NKN wallet seed (32 bytes)
  static Future<SearchClient> createWithAuth({
    required String apiBase,
    required Uint8List seed,
  }) async {
    if (seed.length != 32) {
      throw SearchException(
        'Seed must be exactly 32 bytes',
        code: 'INVALID_SEED',
      );
    }
    
    final client = SearchClient._(
      apiBase: apiBase,
      seed: seed,
      isAuthMode: true,
    );
    await client._initialize();
    return client;
  }

  /// Initialize the native client
  Future<void> _initialize() async {
    try {
      if (isAuthMode) {
        final result = await _channel.invokeMethod('newSearchClientWithAuth', {
          'apiBase': apiBase,
          'seed': seed,
        });
        _clientId = result['clientId'];
      } else {
        final result = await _channel.invokeMethod('newSearchClient', {
          'apiBase': apiBase,
        });
        _clientId = result['clientId'];
      }
    } on PlatformException catch (e) {
      throw SearchException(
        'Failed to create search client: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Query data by keyword
  /// Returns a list of search results
  /// 
  /// Example:
  /// ```dart
  /// final results = await client.query('alice');
  /// for (var item in results) {
  ///   print('${item.customId}: ${item.nickname}');
  /// }
  /// ```
  Future<List<SearchResult>> query(String keyword) async {
    _ensureInitialized();

    try {
      final jsonStr = await _channel.invokeMethod('query', {
        'clientId': _clientId,
        'keyword': keyword,
      });

      final response = json.decode(jsonStr);
      
      if (response['success'] == false) {
        throw SearchException(
          response['error'] ?? 'Query failed',
          code: 'QUERY_FAILED',
        );
      }

      // Parse results - server returns { success: true, data: { results: [...], pagination: {...} } }
      final data = response['data'];
      if (data == null) return [];
      
      // Check if data has results array (new format)
      if (data is Map<String, dynamic> && data.containsKey('results')) {
        final results = data['results'];
        // Handle null results (no data found)
        if (results == null) return [];
        // Handle array results
        if (results is List) {
          return results.map((item) => SearchResult.fromJson(item as Map<String, dynamic>)).toList();
        }
        // Handle single result as map
        if (results is Map<String, dynamic>) {
          return [SearchResult.fromJson(results)];
        }
        return [];
      }
      
      // Legacy: If data is a List, process it normally
      if (data is List) {
        return data.map((item) => SearchResult.fromJson(item as Map<String, dynamic>)).toList();
      }
      
      // Legacy: If data is a Map without results key (single result), wrap it in a list
      if (data is Map<String, dynamic> && !data.containsKey('pagination')) {
        return [SearchResult.fromJson(data)];
      }
      
      // Unknown format or empty
      return [];
    } on PlatformException catch (e) {
      throw SearchException(
        'Query failed: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SearchException(
        'Query failed: $e',
        code: 'QUERY_ERROR',
      );
    }
  }

  /// Submit or update user data
  /// Automatically performs Proof of Work (PoW) - may take several seconds
  /// 
  /// Parameters:
  /// - nknAddress: NKN client address (optional, format: "identifier.publickey" or just publickey)
  ///               If empty, defaults to publickey. Must be either "identifier.publickey" format or equal to publickey.
  /// - customId: Custom identifier (optional, min 3 characters if provided, alphanumeric + underscore only)
  /// - nickname: User nickname (optional)
  /// - phoneNumber: Phone number (optional)
  /// 
  /// Important:
  /// - Each call performs fresh PoW (1-5 seconds on mobile)
  /// - Rate limit: 10 submits per minute
  /// - NO need to call verify() first
  /// - If publicKey already exists, will UPDATE the user data
  /// - nknAddress validation: must be empty, equal to publickey, or in "identifier.publickey" format
  /// 
  /// Example:
  /// ```dart
  /// // Option 1: Use default (empty - will use publickey)
  /// await client.submitUserData();
  /// 
  /// // Option 2: Use publickey directly
  /// final pubKey = await client.getPublicKeyHex();
  /// await client.submitUserData(nknAddress: pubKey);
  /// 
  /// // Option 3: Use custom identifier.publickey format
  /// await client.submitUserData(
  ///   nknAddress: 'alice.$pubKey',   // Custom identifier + publickey
  ///   customId: 'user123',           // Optional, min 3 chars
  ///   nickname: 'Alice',             // Optional
  ///   phoneNumber: '13800138000',    // Optional
  /// );
  /// ```
  Future<void> submitUserData({
    String? nknAddress,
    String? customId,
    String? nickname,
    String? phoneNumber,
  }) async {
    _ensureInitialized();
    _ensureAuthMode();

    // Get publicKey for validation and default
    final publicKeyHex = await getPublicKeyHex();
    
    // Process nknAddress: if not provided or invalid, use publicKey
    String finalNknAddress = nknAddress ?? publicKeyHex;
    
    // Validate nknAddress format if it contains a dot
    if (finalNknAddress.contains('.')) {
      final parts = finalNknAddress.split('.');
      if (parts.length != 2) {
        throw SearchException(
          'Invalid nknAddress format. Expected: "identifier.publickey"',
          code: 'INVALID_PARAMETER',
        );
      }
      final providedPubKey = parts[1];
      if (providedPubKey.toLowerCase() != publicKeyHex.toLowerCase()) {
        throw SearchException(
          'nknAddress publickey suffix must match your actual publicKey',
          code: 'INVALID_PARAMETER',
        );
      }
    } else {
      // If no dot, must equal publicKey
      if (finalNknAddress.toLowerCase() != publicKeyHex.toLowerCase()) {
        throw SearchException(
          'nknAddress must be either "identifier.publickey" format or equal to publicKey',
          code: 'INVALID_PARAMETER',
        );
      }
    }

    // Validate customId if provided
    if (customId != null && customId.isNotEmpty && customId.length < 5) {
      throw SearchException(
        'customId must be at least 5 characters if provided',
        code: 'INVALID_PARAMETER',
      );
    }

    try {
      await _channel.invokeMethod('submitUserData', {
        'clientId': _clientId,
        'nknAddress': finalNknAddress,
        'customId': customId ?? '',
        'nickname': nickname ?? '',
        'phoneNumber': phoneNumber ?? '',
      });
    } on PlatformException catch (e) {
      if (e.code == 'SUBMIT_FAILED' && e.message?.contains('429') == true) {
        throw SearchException(
          'Rate limit exceeded. Max 10 submits per minute. Please wait and retry.',
          code: 'RATE_LIMIT_EXCEEDED',
        );
      }
      throw SearchException(
        'Submit failed: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Verify the client (optional)
  /// Completes PoW challenge to get 2-hour query access
  /// 
  /// Only useful if you need to do many query operations.
  /// WriteProfile does NOT require verification.
  Future<void> verify() async {
    _ensureInitialized();
    _ensureAuthMode();

    try {
      await _channel.invokeMethod('verify', {
        'clientId': _clientId,
      });
    } on PlatformException catch (e) {
      throw SearchException(
        'Verification failed: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Query data by ID
  /// Requires verification first
  Future<SearchResult?> queryByID(String id) async {
    _ensureInitialized();
    _ensureAuthMode();

    try {
      final jsonStr = await _channel.invokeMethod('queryByID', {
        'clientId': _clientId,
        'id': id,
      });


      final response = json.decode(jsonStr);
      
      if (response['success'] == false) {
        throw SearchException(
          response['error'] ?? 'Query failed',
          code: 'QUERY_FAILED',
        );
      }

      final data = response['data'];
      if (data == null) return null;
      
      // Handle new format: { results: [...], pagination: {...} }
      if (data is Map<String, dynamic> && data.containsKey('results')) {
        final results = data['results'];
        // Handle null or empty results
        if (results == null) return null;
        if (results is List && results.isEmpty) return null;
        // Return first result if available
        if (results is List && results.isNotEmpty) {
          return SearchResult.fromJson(results[0] as Map<String, dynamic>);
        }
        return null;
      }
      
      // Legacy: data is a Map (single result)
      if (data is Map<String, dynamic> && !data.containsKey('pagination')) {
        return SearchResult.fromJson(data);
      }
      
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'QUERY_BY_ID_FAILED' && 
          e.message?.contains('not verified') == true) {
        throw SearchException(
          'Not verified. Please call verify() first.',
          code: 'NOT_VERIFIED',
        );
      }
      throw SearchException(
        'Query by ID failed: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SearchException(
        'Query by ID failed: $e',
        code: 'QUERY_ERROR',
      );
    }
  }

  /// Get my own information by nknAddress
  /// 
  /// Parameters:
  /// - address: The NKN address to query (can be "identifier.publickey" format or just publickey)
  /// 
  /// Returns the user's information if found, or null if not found.
  Future<SearchResult?> getMyInfo(String address) async {
    _ensureInitialized();

    try {
      final jsonStr = await _channel.invokeMethod('getMyInfo', {
        'clientId': _clientId,
        'address': address,
      });

      final response = json.decode(jsonStr);
      
      if (response['success'] == false) {
        throw SearchException(
          response['error'] ?? 'Query failed',
          code: 'QUERY_FAILED',
        );
      }

      final data = response['data'];
      if (data == null) return null;
      
      // Handle new format: { results: [...], pagination: {...} }
      if (data is Map<String, dynamic> && data.containsKey('results')) {
        final results = data['results'];
        // Handle null or empty results
        if (results == null) return null;
        if (results is List && results.isEmpty) return null;
        // Return first result if available
        if (results is List && results.isNotEmpty) {
          final firstResult = results[0];
          if (firstResult is Map<String, dynamic>) {
            return SearchResult.fromJson(firstResult);
          }
        }
        return null;
      }
      
      // Legacy: data is a Map (single result)
      if (data is Map<String, dynamic> && !data.containsKey('pagination')) {
        return SearchResult.fromJson(data);
      }
      
      return null;
    } on PlatformException catch (e) {
      throw SearchException(
        'Get my info failed: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw SearchException(
        'Get my info failed: $e',
        code: 'QUERY_ERROR',
      );
    }
  }

  /// Get the public key in hex format
  Future<String> getPublicKeyHex() async {
    _ensureInitialized();
    _ensureAuthMode();

    try {
      final result = await _channel.invokeMethod('getPublicKeyHex', {
        'clientId': _clientId,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw SearchException(
        'Failed to get public key: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Get the wallet address
  Future<String> getAddress() async {
    _ensureInitialized();
    _ensureAuthMode();

    try {
      final result = await _channel.invokeMethod('getAddress', {
        'clientId': _clientId,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw SearchException(
        'Failed to get address: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Check if the client is verified
  Future<bool> isVerified() async {
    _ensureInitialized();
    _ensureAuthMode();

    try {
      final result = await _channel.invokeMethod('isVerified', {
        'clientId': _clientId,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw SearchException(
        'Failed to check verification: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Dispose the client and free resources
  /// Should be called when done using the client
  Future<void> dispose() async {
    if (_clientId == null) return;

    try {
      await _channel.invokeMethod('disposeClient', {
        'clientId': _clientId,
      });
      _clientId = null;
    } on PlatformException catch (e) {
      // Ignore disposal errors
      print('Warning: Failed to dispose client: ${e.message}');
    }
  }

  void _ensureInitialized() {
    if (_clientId == null) {
      throw SearchException(
        'Client not initialized',
        code: 'NOT_INITIALIZED',
      );
    }
  }

  void _ensureAuthMode() {
    if (!isAuthMode) {
      throw SearchException(
        'This operation requires an authenticated client. Use createWithAuth() instead.',
        code: 'AUTH_REQUIRED',
      );
    }
  }
}

/// Search result item (User data)
class SearchResult {
  final String? id;
  final String? publicKey;
  final String? nknAddress;
  final String? customId;
  final String? nickname;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SearchResult({
    this.id,
    this.publicKey,
    this.nknAddress,
    this.customId,
    this.nickname,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      publicKey: json['publicKey']?.toString(),
      nknAddress: json['nknAddress']?.toString(),
      customId: json['customId']?.toString(),
      nickname: json['nickname']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'publicKey': publicKey,
      'nknAddress': nknAddress,
      'customId': customId,
      'nickname': nickname,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SearchResult(id: $id, customId: $customId, nickname: $nickname, nknAddress: $nknAddress)';
  }
}

/// Search exception
class SearchException implements Exception {
  final String message;
  final String? code;

  SearchException(this.message, {this.code});

  @override
  String toString() {
    if (code != null) {
      return 'SearchException($code): $message';
    }
    return 'SearchException: $message';
  }
}
