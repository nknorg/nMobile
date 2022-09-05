import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/native/crypto.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class IpfsHelper with Tag {
  static List<String> _writeableGateway = [
    '64.225.88.71',
    'infura-ipfs.io:5001',
    // 'ipfs.infura.io:5001', // vpn
    // 'dweb.link:5001', // only read
    // 'cf-ipfs.com:5001', // only read
  ];

  static List<String> _readableGateway = [
    '64.225.88.71',
    'infura-ipfs.io:5001',
    // 'cf-ipfs.com:5001', // ??
    // 'dweb.link:5001', // vpn
    // 'ipfs.infura.io:5001', // vpn
    // 'ipfs.io:5001', // vpn
    // 'gateway.ipfs.io:5001' // disable
    // 'cloudflare-ipfs.com:5001', // disable
  ];

  static const String _upload_address = "api/v0/add";
  static const String _download_address = "api/v0/cat";
  // static const String _peers = "api/v0/swarm/peers"; // FUTURE: pin

  static const String KEY_IP = "ip";
  static const String KEY_HASH = "Hash";
  static const String KEY_ENCRYPT = "encrypt";
  static const String KEY_ENCRYPT_ALGORITHM = "encryptAlgorithm";
  static const String KEY_ENCRYPT_KEY_BYTES = "encryptKeyBytes";
  static const String KEY_ENCRYPT_NONCE_SIZE = "encryptNonceSize";

  Dio _dio = Dio();
  ParallelQueue _uploadQueue = ParallelQueue("ipfs_upload", interval: Duration(seconds: 1), onLog: (log, error) => error ? logger.w(log) : null);
  ParallelQueue _downloadQueue = ParallelQueue("ipfs_download", interval: Duration(seconds: 1), onLog: (log, error) => error ? logger.w(log) : null);

  IpfsHelper(bool log) {
    _dio.options.connectTimeout = 1 * 60 * 1000; // 1m
    _dio.options.receiveTimeout = 0; // no limit
    if (log) {
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

  Future uploadFile(
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
    Map<String, dynamic>? cryptParams;
    if (encrypt) {
      final Map<String, Map<String, dynamic>>? result = await _encryption(await file.readAsBytes());
      if ((result?["data"]?["cipherText"] != null) && (result?["data"]?["cipherText"].isNotEmpty)) {
        try {
          File encryptFile = File(filePath + ".aes");
          if (!encryptFile.existsSync()) {
            await encryptFile.create(recursive: true);
          } else {
            await encryptFile.delete();
            await encryptFile.create(recursive: true);
          }
          await encryptFile.writeAsBytes(result!["data"]!["cipherText"], flush: true);
          filePath = encryptFile.path;
        } catch (e, st) {
          handleError(e, st);
          onError?.call("encrypt copy fail");
          return null;
        }
        result["data"]?["cipherText"] = null;
        result.remove("data");
        cryptParams = result["params"];
      } else {
        onError?.call("encrypt create fail");
        return null;
      }
    }

    // FUTURE: use best ip_address by pin
    String? ipAddress;

    // http
    _uploadQueue.add(
      () => _uploadFile(
        id,
        filePath,
        fileLen,
        ipAddress: ipAddress,
        onProgress: (msgId, total, count) {
          double percent = total > 0 ? (count / total) : -1;
          onProgress?.call(msgId, percent);
        },
        onSuccess: (msgId, result) {
          if (encrypt) result.addAll({KEY_ENCRYPT: 1}..addAll(cryptParams ?? Map()));
          onSuccess?.call(msgId, result);
          if (encrypt) File(filePath).delete(); // await
        },
        onError: (msgId) {
          onError?.call(msgId);
          if (encrypt) File(filePath).delete(); // await
        },
      ),
      id: id,
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
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    if (ipfsHash.isEmpty || savePath.isEmpty) {
      onError?.call("hash is empty");
      return null;
    }

    // TODO:GG FUTURE: if(receive_at - send_at < 30s) just use params ip_address, other use best ip_address
    // TODO:GG 还要有失败切换ip的功能
    ipAddress = ipAddress ?? (await _getGateway2Read());
    if (!_isReadIp(ipAddress)) {
      onError?.call("ip_address error");
      return null;
    }

    if (ipAddress.contains("infura") && !ipAddress.contains(":")) {
      ipAddress = ipAddress + ":5001";
    }

    var headers = {
      HttpHeaders.authorizationHeader: "Basic ${base64Encode(utf8.encode('$INFURA_PROJECT_ID:$INFURA_API_KEY_SECRET'))}",
      // Headers.contentLengthHeader: ipfsLength,
    };

    // http
    _downloadQueue.add(
      () => _downloadFile(
        id,
        ipfsHash,
        ipfsLength,
        ipAddress: ipAddress,
        headerParams: headers,
        onProgress: (msgId, total, count) {
          double percent = total > 0 ? (count / total) : -1;
          onProgress?.call(msgId, percent);
        },
        onSuccess: (msgId, data, result) async {
          // decrypt
          List<int>? finalData;
          if (decrypt && decryptParams != null) {
            finalData = await _decrypt(
              data,
              decryptParams[KEY_ENCRYPT_ALGORITHM],
              decryptParams[KEY_ENCRYPT_KEY_BYTES],
              decryptParams[KEY_ENCRYPT_NONCE_SIZE],
            );
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
              onSuccess?.call(msgId);
            } catch (e, st) {
              handleError(e, st);
              onError?.call("save file fail");
            }
          }
        },
        onError: (msgId) => onError?.call(msgId),
      ),
      id: id,
    );
  }

  Future<Map<String, dynamic>?> _uploadFile(
    String id,
    String filePath,
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
    String uri = 'https://$ipAddress/$_upload_address';

    // http
    Response? response;
    try {
      response = await _dio.post(
        uri,
        data: FormData.fromMap({'path': MultipartFile.fromFileSync(filePath)}),
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: "Basic ${base64Encode(utf8.encode('$INFURA_PROJECT_ID:$INFURA_API_KEY_SECRET'))}",
            // Headers.contentLengthHeader: ipfsLength,
          },
          // responseType: ResponseType.json,
        ),
        onSendProgress: (count, total) {
          logger.v("$TAG - _uploadFile - onSendProgress - count:$count - total:$total - id:$id");
          onProgress?.call(id, total, count);
        },
      );
    } on DioError catch (e, st) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        handleError(e.response?.data, st);
      } else {
        handleError(response?.statusMessage, st);
      }
      onError?.call(id);
      return null;
    } catch (e, st) {
      handleError(e, st);
      onError?.call(id);
      return null;
    }

    // response
    Map<String, dynamic>? results = response.data;
    if ((results == null) || (results.isEmpty)) {
      logger.e("$TAG - uploadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri");
      onError?.call("response is empty");
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
    Map<String, dynamic>? headerParams,
    Function(String, int, int)? onProgress,
    Function(String, Uint8List, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    // uri
    if ((ipAddress == null) || ipAddress.isEmpty) {
      onError?.call("ip_address empty");
      return null;
    }
    String uri = 'https://$ipAddress/$_download_address';

    // header
    Map<String, dynamic> headers = {
      // Headers.contentLengthHeader: ipfsLength,
    }..addAll(headerParams ?? Map());

    // http
    Response? response;
    try {
      response = await _dio.post(
        uri,
        queryParameters: {'arg': ipfsHash},
        options: Options(headers: headers, responseType: ResponseType.bytes),
        onReceiveProgress: (count, total) {
          int totalCount = (total > 0) ? total : ipfsLength;
          logger.v("$TAG - _downloadFile - onReceiveProgress - count:$count - total:$totalCount - id:$id");
          onProgress?.call(id, totalCount, count);
        },
      );
    } on DioError catch (e, st) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        handleError(e.response?.data, st);
      } else {
        handleError(response?.statusMessage, st);
      }
      onError?.call(id);
      return null;
    } catch (e, st) {
      handleError(e, st);
      onError?.call(id);
      return null;
    }

    // response
    Uint8List? responseData = response.data;
    if ((responseData == null) || (responseData.isEmpty)) {
      logger.e("$TAG - _downloadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri");
      onError?.call("response is empty");
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

  Future<Map<String, Map<String, dynamic>>?> _encryption(Uint8List fileBytes) async {
    if (fileBytes.isEmpty) return null;
    try {
      int nonceSize = 12;
      Random generator = Random.secure();
      Uint8List key = Uint8List(16);
      for (int i = 0; i < key.length; i++) {
        key[i] = generator.nextInt(255);
      }
      Uint8List cipherText = await Crypto.gcmEncrypt(fileBytes, key, nonceSize);
      return {
        "data": {"cipherText": cipherText},
        "params": {
          KEY_ENCRYPT_ALGORITHM: "AES/GCM/NoPadding",
          KEY_ENCRYPT_KEY_BYTES: key,
          KEY_ENCRYPT_NONCE_SIZE: nonceSize,
        }
      };
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<int>?> _decrypt(Uint8List data, String algorithm, Uint8List key, int nonceSize) async {
    if (data.isEmpty || key.isEmpty || nonceSize <= 0) return null;
    try {
      if (algorithm.toLowerCase().contains("aes/gcm")) {
        return await Crypto.gcmDecrypt(data, key, nonceSize);
      }
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }
}
