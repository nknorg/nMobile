import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

class IpfsHelper with Tag {
  static List<String> _writeableGateway = [
    'infura-ipfs.io',
    // 'ipfs.infura.io', // vpn
    // 'dweb.link:5001', // only read
    // 'cf-ipfs.com:5001', // only read
  ];

  static List<String> _readableGateway = [
    'infura-ipfs.io',
    'cf-ipfs.com',
    // 'dweb.link', // vpn
    // 'ipfs.infura.io', // vpn
    // 'ipfs.io', // vpn
    // 'gateway.ipfs.io' // disable
    // 'cloudflare-ipfs.com', // disable
  ];

  static const GATEWAY_READ_PORT = "5001";
  static const GATEWAY_WRITE_PORT = "5001";

  static const String _upload_address = "api/v0/add";
  static const String _download_address = "api/v0/cat";
  // static const String _peers = "api/v0/swarm/peers"; // FUTURE: pin

  static const String KEY_SECRET_NONCE_LEN = "secretNonceLen";
  static const String KEY_SECRET_KEY_TEXT = "secretKeyText";
  static const String KEY_SECRET_BOX_MAC_TEXT = "secretBoxMacText";
  static const String KEY_SECRET_BOX_NONCE_TEXT = "secretBoxMacNonceText";

  Dio _dio = Dio();

  IpfsHelper() {
    _dio.options.connectTimeout = 1 * 60 * 1000; // 1m
    _dio.options.receiveTimeout = 0; // no limit
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: false,
      responseHeader: true,
      responseBody: false,
      error: true,
      logPrint: (log) => logger.i(log),
    ));
  }

  Future<String> _getGateway2Write() async {
    return _writeableGateway[0];
  }

  Future<String> _getGateway2Read() async {
    return _readableGateway[0];
  }

  bool _isWriteIp(String ip) {
    return _writeableGateway.contains(ip);
  }

  bool _isReadIp(String ip) {
    return _readableGateway.contains(ip);
  }

  void uploadFile(
    String id,
    String filePath, {
    bool encrypt = true,
    Function(String, double)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    File file = File(filePath);
    int fileLen = file.lengthSync();
    if (filePath.isEmpty || !file.existsSync()) {
      onError?.call("file no exist");
      return null;
    }

    // encrypt
    List<int>? fileBytes;
    Map<String, dynamic>? encResult;
    if (encrypt) {
      encResult = await _encryption(file);
      fileBytes = encResult?["data"];
      encResult?.remove("data");
    } else {
      fileBytes = file.readAsBytesSync();
    }
    if (fileBytes == null || fileBytes.isEmpty) {
      onError?.call("encrypt fail");
      return null;
    }

    // FUTURE: use best ip_address by pin
    String? ipAddress;

    // http
    _uploadFile(
      id,
      fileBytes,
      fileLen,
      ipAddress: ipAddress,
      onProgress: (msgId, total, count) {
        double percent = total > 0 ? (count / total) : -1;
        onProgress?.call(msgId, percent);
      },
      onSuccess: (msgId, result) {
        result.addAll(encResult ?? Map());
        onSuccess?.call(msgId, result);
      },
      onError: (msgId) => onError?.call(msgId),
    );
  }

  void downloadFile(
    String id,
    String ipfsHash,
    int ipfsLength,
    String savePath, {
    String? ipAddress,
    bool decrypt = true,
    Map<String, dynamic>? decryptParams,
    Function(String, double)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    if (ipfsHash.isEmpty || savePath.isEmpty) {
      onError?.call("hash is empty");
      return null;
    }

    // FUTURE: if(receive_at - send_at < 30s) just use params ip_address, other use best ip_address
    ipAddress = ipAddress;

    // http
    _downloadFile(
      id,
      ipfsHash,
      ipfsLength,
      ipAddress: ipAddress,
      onProgress: (msgId, total, count) {
        double percent = total > 0 ? (count / total) : -1;
        onProgress?.call(msgId, percent);
      },
      onSuccess: (msgId, data, result) async {
        // decrypt
        List<int>? finalData;
        if (decrypt && decryptParams != null) {
          finalData = await _decrypt(data, decryptParams);
        } else {
          finalData = data;
        }
        // save
        if (finalData == null || finalData.isEmpty) {
          onError?.call("decrypt fail");
        } else {
          try {
            File file = File(savePath);
            if (!file.existsSync()) {
              await file.create(recursive: true);
            } else {
              await file.delete();
              await file.create(recursive: true);
            }
            await file.writeAsBytes(finalData, flush: true);
            onSuccess?.call(msgId, result);
          } catch (e) {
            handleError(e);
            onError?.call("save file fail");
          }
        }
      },
      onError: (msgId) => onError?.call(msgId),
    );
  }

  Future<Map<String, dynamic>?> _uploadFile(
    String id,
    List<int> fileBytes,
    int ipfsLength, {
    String? ipAddress,
    Function(String, int, int)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    // uri
    ipAddress = ipAddress ?? (await _getGateway2Write());
    if (!_isWriteIp(ipAddress)) {
      onError?.call("ip_address error");
      return null;
    }
    String uri = 'https://$ipAddress${GATEWAY_WRITE_PORT.isNotEmpty ? ":$GATEWAY_WRITE_PORT" : ""}/$_upload_address';

    // http
    Response? response;
    try {
      response = await _dio.post(
        uri,
        data: FormData.fromMap({'path': MultipartFile.fromBytes(fileBytes)}),
        options: Options(
            // headers: {Headers.contentLengthHeader: fileLength},
            // responseType: ResponseType.json,
            ),
        onSendProgress: (count, total) {
          logger.v("$TAG - _uploadFile - onSendProgress - count:$count - total:$total - id:$id");
          onProgress?.call(id, total, count);
        },
      );
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        handleError(e.response?.data);
      } else {
        handleError(response?.statusMessage);
      }
      onError?.call(id);
    } catch (e) {
      handleError(e);
      onError?.call(id);
    }

    // response
    Map<String, dynamic>? results = response?.data;
    if ((response == null) || (results == null) || (results.isEmpty)) {
      logger.w("$TAG - uploadFile - fail - state_code:${response?.statusCode} - state_msg:${response?.statusMessage} - uri:$uri");
      onError?.call("response is null");
      return null;
    }
    logger.i("$TAG - uploadFile - success - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri - result:$results");

    // result
    results["id"] = id;
    results["ip"] = ipAddress;
    onSuccess?.call(id, results); // await
    return results;
  }

  Future<Map<String, dynamic>?> _downloadFile(
    String id,
    String ipfsHash,
    int ipfsLength, {
    String? ipAddress,
    Function(String, int, int)? onProgress,
    Function(String, Uint8List, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    // uri
    ipAddress = ipAddress ?? (await _getGateway2Read());
    if (!_isReadIp(ipAddress)) {
      onError?.call("ip_address error");
      return null;
    }
    String uri = 'https://$ipAddress${GATEWAY_READ_PORT.isNotEmpty ? ":$GATEWAY_READ_PORT" : ""}/$_download_address';

    // http
    Response? response;
    try {
      response = await _dio.post(
        uri,
        queryParameters: {'arg': ipfsHash},
        options: Options(
          // headers: {Headers.contentLengthHeader: ipfsLength},
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (count, total) {
          int totalCount = (total > 0) ? total : ipfsLength;
          logger.v("$TAG - _downloadFile - onReceiveProgress - count:$count - total:$totalCount - id:$id");
          onProgress?.call(id, totalCount, count);
        },
      );
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        handleError(e.response?.data);
      } else {
        handleError(response?.statusMessage);
      }
      onError?.call(id);
    } catch (e) {
      handleError(e);
      onError?.call(id);
    }

    // response
    Uint8List? responseData = response?.data;
    if ((response == null) || (responseData == null) || (responseData.isEmpty)) {
      logger.w("$TAG - _downloadFile - fail - state_code:${response?.statusCode} - state_msg:${response?.statusMessage} - uri:$uri");
      onError?.call("response is null");
      return null;
    }
    logger.i("$TAG - _downloadFile - success - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri - options:${response.requestOptions}");

    // result
    Map<String, dynamic> results = Map();
    results["id"] = id;
    results["ip"] = ipAddress;
    onSuccess?.call(id, responseData, results); // await
    return results;
  }

  Future<Map<String, dynamic>?> _encryption(File file) async {
    try {
      int encryptNonceLen = 12;
      Uint8List fileBytes = await file.readAsBytes();
      AesGcm aesGcm = AesGcm.with128bits(nonceLength: encryptNonceLen);
      SecretKey secretKey = await aesGcm.newSecretKey();
      List<int> secretKeyBytes = await secretKey.extractBytes();
      SecretBox secretBox = await aesGcm.encrypt(fileBytes, secretKey: secretKey);
      return {
        "data": secretBox.cipherText,
        KEY_SECRET_NONCE_LEN: encryptNonceLen,
        KEY_SECRET_KEY_TEXT: utf8.decode(secretKeyBytes),
        KEY_SECRET_BOX_MAC_TEXT: utf8.decode(secretBox.nonce),
        KEY_SECRET_BOX_NONCE_TEXT: utf8.decode(secretBox.mac.bytes),
      };
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<int>?> _decrypt(List<int> data, Map<String, dynamic> params) async {
    int secretLen = int.tryParse(params[KEY_SECRET_NONCE_LEN]?.toString() ?? "") ?? 12;
    List<int> secretKeyBytes = utf8.encode(params[KEY_SECRET_KEY_TEXT]?.toString() ?? "");
    List<int> secretBoxMacBytes = utf8.encode(params[KEY_SECRET_BOX_MAC_TEXT]?.toString() ?? "");
    List<int> secretBoxMacNonce = utf8.encode(params[KEY_SECRET_BOX_NONCE_TEXT]?.toString() ?? "");
    if (secretKeyBytes.isNotEmpty && secretBoxMacBytes.isNotEmpty && secretBoxMacNonce.isNotEmpty) {
      try {
        AesGcm aesGcm = AesGcm.with128bits(nonceLength: secretLen);
        SecretKey secretKey = SecretKey(secretKeyBytes);
        SecretBox secretBox = SecretBox(data, mac: Mac(secretBoxMacBytes), nonce: secretBoxMacNonce);
        List<int> result = await aesGcm.decrypt(secretBox, secretKey: secretKey);
        return result;
      } catch (e) {
        handleError(e);
      }
    } else {
      logger.w("$TAG - _decrypt - params is empty - params:$params");
    }
    return null;
  }
}
