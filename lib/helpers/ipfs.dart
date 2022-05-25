import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart' as Sync;

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

  static const String KEY_RESULT_IP = "ip";
  static const String KEY_RESULT_HASH = "Hash";
  static const String KEY_RESULT_SIZE = "Size";
  static const String KEY_RESULT_NAME = "Name";
  static const String KEY_RESULT_ENCRYPT = "encrypt";
  static const String KEY_RESULT_ENCRYPT_TYPE = "encrypt_type";
  static const String KEY_SECRET_NONCE_LEN = "secretNonceLen";
  static const String KEY_SECRET_KEY_BYTES = "secretKeyBytes";
  static const String KEY_SECRET_BOX_MAC_BYTES = "secretBoxMacBytes";
  static const String KEY_SECRET_BOX_NONCE_BYTES = "secretBoxMacNonceBytes";

  Dio _dio = Dio();

  Sync.Lock _uploadLock = Sync.Lock();
  Sync.Lock _downloadLock = Sync.Lock();

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

  Future uploadFile(
    String id,
    String filePath, {
    bool encrypt = true,
    Function(String, double)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    return _uploadLock.synchronized(() async {
      return await uploadFileWithNoLock(
        id,
        filePath,
        encrypt: encrypt,
        onProgress: onProgress,
        onSuccess: onSuccess,
        onError: onError,
      );
    });
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
    return _downloadLock.synchronized(() {
      return downloadFileWithNoLock(
        id,
        ipfsHash,
        ipfsLength,
        savePath,
        ipAddress: ipAddress,
        decrypt: decrypt,
        decryptParams: decryptParams,
        onProgress: onProgress,
        onSuccess: onSuccess,
        onError: onError,
      );
    });
  }

  Future uploadFileWithNoLock(
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
    Map<String, dynamic>? encParams;
    if (encrypt) {
      final Map<String, Map<String, dynamic>>? result = await _encryption(await file.readAsBytes());
      encParams = result?["params"];
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
        } catch (e) {
          handleError(e);
          onError?.call("encrypt copy fail");
          return null;
        }
      } else {
        onError?.call("encrypt create fail");
        return null;
      }
    }

    // FUTURE: use best ip_address by pin
    String? ipAddress;

    // http
    _uploadFile(
      id,
      filePath,
      fileLen,
      ipAddress: ipAddress,
      onProgress: (msgId, total, count) {
        double percent = total > 0 ? (count / total) : -1;
        onProgress?.call(msgId, percent);
      },
      onSuccess: (msgId, result) {
        if (encrypt) result.addAll({KEY_RESULT_ENCRYPT: 1}..addAll(encParams ?? Map()));
        onSuccess?.call(msgId, result);
        if (encrypt) File(filePath).delete(); // await
      },
      onError: (msgId) {
        onError?.call(msgId);
        if (encrypt) File(filePath).delete(); // await
      },
    );
  }

  void downloadFileWithNoLock(
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
  }) {
    if (ipfsHash.isEmpty || savePath.isEmpty) {
      onError?.call("hash is empty");
      return null;
    }

    // FUTURE: if(receive_at - send_at < 30s) just use params ip_address, other use best ip_address
    ipAddress = null;

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
    String uri = 'https://$ipAddress${GATEWAY_WRITE_PORT.isNotEmpty ? ":$GATEWAY_WRITE_PORT" : ""}/$_upload_address';

    // http
    Response? response;
    try {
      response = await _dio.post(
        uri,
        data: FormData.fromMap({'path': MultipartFile.fromFileSync(filePath)}),
        options: Options(
            // headers: {Headers.contentLengthHeader: ipfsLength},
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
      return null;
    } catch (e) {
      handleError(e);
      onError?.call(id);
      return null;
    }

    // response
    Map<String, dynamic>? results = response.data;
    if ((results == null) || (results.isEmpty)) {
      logger.w("$TAG - uploadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri");
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
      return null;
    } catch (e) {
      handleError(e);
      onError?.call(id);
      return null;
    }

    // response
    Uint8List? responseData = response.data;
    if ((responseData == null) || (responseData.isEmpty)) {
      logger.w("$TAG - _downloadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - uri:$uri");
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

  Future<Map<String, Map<String, dynamic>>?> _encryption(Uint8List fileBytes) async {
    try {
      int encryptNonceLen = 12;
      AesCbc aesCbc = AesCbc.with128bits(macAlgorithm: Hmac.sha256());
      SecretKey secretKey = await aesCbc.newSecretKey();

      ReceivePort receivePort = ReceivePort();
      await Isolate.spawn(_ipfsEncrypt, receivePort.sendPort);
      // The 'echo' isolate sends its SendPort as the first message
      SendPort sendPort = await receivePort.first;
      // send message to isolate thread
      ReceivePort response = ReceivePort();
      sendPort.send([response.sendPort, aesCbc, secretKey, fileBytes]);
      // get result from UI thread port
      SecretBox secretBox = await response.first;

      return {
        "data": {
          "cipherText": secretBox.cipherText,
        },
        "params": {
          KEY_RESULT_ENCRYPT_TYPE: "aes-cbc",
          KEY_SECRET_NONCE_LEN: encryptNonceLen,
          KEY_SECRET_KEY_BYTES: await secretKey.extractBytes(),
          KEY_SECRET_BOX_MAC_BYTES: secretBox.mac.bytes,
          KEY_SECRET_BOX_NONCE_BYTES: secretBox.nonce,
        }
      };
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<int>?> _decrypt(List<int> data, Map<String, dynamic> params) async {
    try {
      ReceivePort receivePort = ReceivePort();
      await Isolate.spawn(_ipfsDecrypt, receivePort.sendPort);
      // The 'echo' isolate sends its SendPort as the first message
      SendPort sendPort = await receivePort.first;
      // send message to isolate thread
      ReceivePort response = ReceivePort();
      sendPort.send([response.sendPort, params, data]);
      // get result from UI thread port
      List<int> result = await response.first;
      return result;
    } catch (e) {
      handleError(e);
    }
    return null;
  }
}

_ipfsEncrypt(SendPort sendPort) async {
  // Open the ReceivePort for incoming messages.
  ReceivePort port = ReceivePort();
  // Notify any other isolates what port this isolate listens to.
  sendPort.send(port.sendPort);

  // get response
  var msg = (await port.first) as List;
  SendPort replyTo = msg[0];
  AesCbc aesCbc = msg[1];
  SecretKey secretKey = msg[2];
  List<int> fileBytes = msg[3];

  SecretBox secretBox = await aesCbc.encrypt(fileBytes, secretKey: secretKey);

  // get keystore
  replyTo.send(secretBox);
  // close
  port.close();
}

_ipfsDecrypt(SendPort sendPort) async {
  // Open the ReceivePort for incoming messages.
  ReceivePort port = ReceivePort();
  // Notify any other isolates what port this isolate listens to.
  sendPort.send(port.sendPort);

  // get response
  var msg = (await port.first) as List;
  SendPort replyTo = msg[0];
  Map<String, dynamic> params = msg[1];
  List<int> data = msg[2];

  String encryptType = params[IpfsHelper.KEY_RESULT_ENCRYPT_TYPE]?.toString() ?? "";
  List<int> secretKeyBytes = params[IpfsHelper.KEY_SECRET_KEY_BYTES] ?? [];
  List<int> secretBoxMacBytes = params[IpfsHelper.KEY_SECRET_BOX_MAC_BYTES] ?? [];
  List<int> secretBoxNonceBytes = params[IpfsHelper.KEY_SECRET_BOX_NONCE_BYTES] ?? [];

  List<int>? result;
  if (secretKeyBytes.isNotEmpty && secretBoxMacBytes.isNotEmpty && secretBoxNonceBytes.isNotEmpty) {
    if (encryptType == "aes-cbc") {
      AesCbc aesCbc = AesCbc.with128bits(macAlgorithm: Hmac.sha256());
      SecretKey secretKey = SecretKey(secretKeyBytes);
      SecretBox secretBox = SecretBox(data, mac: Mac(secretBoxMacBytes), nonce: secretBoxNonceBytes);
      result = await aesCbc.decrypt(secretBox, secretKey: secretKey);
    } else if (encryptType == "aes-ctr") {
      AesCtr aesCtr = AesCtr.with128bits(macAlgorithm: Hmac.sha256());
      SecretKey secretKey = SecretKey(secretKeyBytes);
      SecretBox secretBox = SecretBox(data, mac: Mac(secretBoxMacBytes), nonce: secretBoxNonceBytes);
      result = await aesCtr.decrypt(secretBox, secretKey: secretKey);
    } else if (encryptType == "aes-gcm") {
      int secretLen = int.tryParse(params[IpfsHelper.KEY_SECRET_NONCE_LEN]?.toString() ?? "") ?? 12;
      AesGcm aesGcm = AesGcm.with128bits(nonceLength: secretLen);
      SecretKey secretKey = SecretKey(secretKeyBytes);
      SecretBox secretBox = SecretBox(data, mac: Mac(secretBoxMacBytes), nonce: secretBoxNonceBytes);
      result = await aesGcm.decrypt(secretBox, secretKey: secretKey);
    }
  }

  // get keystore
  replyTo.send(result);
  // close
  port.close();
}
