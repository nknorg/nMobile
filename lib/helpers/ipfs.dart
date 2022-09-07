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
  static List<Map<String, dynamic>> _writeableGateway = [
    {
      "protocol": "http",
      "ip": '64.225.88.71',
      "port": "80",
      "uri": 'ipfs/v0/add',
      "headers": {HttpHeaders.contentLengthHeader: -1},
      "body": "Binary",
    },
    {
      "protocol": "https",
      "ip": 'infura-ipfs.io',
      "port": "5001",
      "uri": "api/v0/add",
      "headers": {HttpHeaders.authorizationHeader: "Basic ${base64Encode(utf8.encode('$INFURA_PROJECT_ID:$INFURA_API_KEY_SECRET'))}"},
      "body": "FormData",
    },
    // 'ipfs.infura.io:5001', // vpn
    // 'dweb.link:5001', // only read
    // 'cf-ipfs.com:5001', // only read
  ];

  static List<Map<String, dynamic>> _readableGateway = [
    {
      "protocol": "http",
      "ip": '64.225.88.71',
      "port": "80",
      "uri": 'api/v0/cat',
      "headers": null,
    },
    {
      "protocol": "https",
      "ip": 'infura-ipfs.io',
      "port": "5001",
      "uri": "api/v0/cat",
      "headers": {HttpHeaders.authorizationHeader: "Basic ${base64Encode(utf8.encode('$INFURA_PROJECT_ID:$INFURA_API_KEY_SECRET'))}"},
    },
    // 'cf-ipfs.com:5001', // ??
    // 'dweb.link:5001', // vpn
    // 'ipfs.infura.io:5001', // vpn
    // 'ipfs.io:5001', // vpn
    // 'gateway.ipfs.io:5001' // disable
    // 'cloudflare-ipfs.com:5001', // disable
  ];

  // infura project
  static const String INFURA_PROJECT_ID = "";
  static const String INFURA_API_KEY_SECRET = "";

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

  String _getUrlFromGateway(Map<String, dynamic> gateway) {
    return "${gateway['protocol']}://${gateway["ip"]}:${gateway["port"]}/${gateway["uri"]}";
  }

  int _getIndexFromGateways(List<Map<String, dynamic>> gateways, String ip) {
    int index = -1;
    for (var i = 0; i < gateways.length; i++) {
      if (ip.trim() == gateways[i]["ip"]?.toString().trim()) {
        index = i;
        break;
      }
    }
    return index;
  }

  Future uploadFile(
    String id,
    String filePath, {
    bool encrypt = true,
    Function(double)? onProgress,
    Function(Map<String, dynamic>)? onSuccess,
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

    // body
    Uint8List bodyBinary = await File(filePath).readAsBytes(); // TODO:GG 会卡？下载会不会卡？
    Stream<List<int>> bodyStream = Stream.fromIterable(bodyBinary.map((e) => [e]));
    FormData bodyFormData = FormData.fromMap({'path': MultipartFile.fromFileSync(filePath)});

    // queue
    _uploadQueue.add(() async {
      for (var i = 0; i < _writeableGateway.length; i++) {
        bool isLastTimes = i == (_writeableGateway.length - 1);
        bool canBreak = false;
        Completer completer = Completer();
        // url
        Map<String, dynamic> gateway = _writeableGateway[i];
        String url = _getUrlFromGateway(gateway);
        Map<String, dynamic>? headers = gateway['headers'];
        if (headers?.containsKey(HttpHeaders.contentLengthHeader) == true) {
          headers?[HttpHeaders.contentLengthHeader] = bodyBinary.length;
        }
        var body = (gateway["body"] == "FormData") ? bodyFormData : bodyStream;
        logger.i("$TAG - uploadFile - try - times:$i - url:$url");
        // http
        _uploadFile(
          url,
          body,
          fileLen,
          headerParams: headers,
          onProgress: (total, count) {
            double percent = total > 0 ? (count / total) : -1;
            onProgress?.call(percent);
          },
          onSuccess: (ipfsHash) {
            Map<String, dynamic> result = Map();
            result.addAll({"id": id, KEY_IP: gateway["ip"], KEY_HASH: ipfsHash});
            if (encrypt) result.addAll({KEY_ENCRYPT: 1}..addAll(cryptParams ?? Map()));
            onSuccess?.call(result);
            if (encrypt) File(filePath).delete(); // await
            canBreak = true;
            if (!completer.isCompleted) completer.complete();
          },
          onError: (retry) {
            if (isLastTimes || !retry) onError?.call("http wrong");
            if ((isLastTimes || !retry) && encrypt) File(filePath).delete(); // await
            canBreak = !retry;
            if (!completer.isCompleted) completer.complete();
          },
        );
        await completer.future;
        if (canBreak) break;
      }
    }, id: id);
  }

  void downloadFile(
    String id,
    String ipfsHash,
    int ipfsLength,
    String savePath, {
    String? ipAddress,
    bool decrypt = true,
    Map<String, dynamic>? decryptParams,
    Function(double)? onProgress,
    Function()? onSuccess,
    Function(String)? onError,
  }) {
    if (ipfsHash.isEmpty || savePath.isEmpty) {
      onError?.call("hash is empty");
      return null;
    }

    // queue
    _downloadQueue.add(() async {
      int index = _getIndexFromGateways(_readableGateway, ipAddress ?? "");
      for (var i = 0; i < _readableGateway.length; i++) {
        bool isLastTimes = i == (_readableGateway.length - 1);
        bool canBreak = false;
        Completer completer = Completer();
        // url
        int realIndex = (index >= 0) ? ((i == 0) ? index : ((i == index) ? 0 : i)) : i;
        Map<String, dynamic> gateway = _readableGateway[realIndex];
        String url = _getUrlFromGateway(gateway);
        Map<String, dynamic>? headers = gateway['headers'];
        logger.i("$TAG - downloadFile - try - times:$i - url:$url");
        // http
        _downloadFile(
          url,
          ipfsHash,
          ipfsLength,
          headerParams: headers,
          onProgress: (total, count) {
            double percent = total > 0 ? (count / total) : -1;
            onProgress?.call(percent);
          },
          onSuccess: (data) async {
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
              if (isLastTimes) onError?.call("decrypt fail");
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
                onSuccess?.call();
              } catch (e, st) {
                handleError(e, st);
                if (isLastTimes) onError?.call("save file fail");
              }
            }
            canBreak = true;
            if (!completer.isCompleted) completer.complete();
          },
          onError: (retry) {
            if (isLastTimes || !retry) onError?.call("http wrong");
            canBreak = !retry;
            if (!completer.isCompleted) completer.complete();
          },
        );
        await completer.future;
        if (canBreak) break;
      }
    }, id: id);
  }

  Future _uploadFile(
    String url,
    dynamic body,
    int ipfsLength, {
    Map<String, dynamic>? headerParams,
    Function(int, int)? onProgress,
    Function(String)? onSuccess,
    Function(bool)? onError,
  }) async {
    // header
    Map<String, dynamic> headers = {
      // Headers.contentLengthHeader: ipfsLength,
    }..addAll(headerParams ?? Map());

    // http
    Response? response;
    try {
      int lastProgress = 0;
      response = await _dio.post(
        url,
        data: body,
        options: Options(headers: headers), // responseType: ResponseType.json,
        onSendProgress: (count, total) {
          if ((count - lastProgress) > 1000) {
            lastProgress = count;
            logger.v("$TAG - _uploadFile - onSendProgress - count:$count - total:$total");
            onProgress?.call(total, count);
          }
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
      onError?.call(true);
      return null;
    } catch (e, st) {
      handleError(e, st);
      onError?.call(true);
      return null;
    }

    // response
    String? ipfsHash;
    var headerHash = response.headers["ipfs-hash"];
    if ((headerHash is List) && ((headerHash as List).isNotEmpty)) {
      ipfsHash = (headerHash as List)[0];
    } else if (headerHash is String) {
      ipfsHash = headerHash?.toString();
    } else {
      ipfsHash = response.data?["Hash"];
    }
    if ((ipfsHash == null) || (ipfsHash.isEmpty)) {
      logger.e("$TAG - _uploadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - url:$url - options:${response.requestOptions}");
      onError?.call(true);
      return null;
    }
    logger.i("$TAG - _uploadFile - success - state_code:${response.statusCode} - state_msg:${response.statusMessage} - url:$url - options:${response.requestOptions}");
    onSuccess?.call(ipfsHash); // await
  }

  Future _downloadFile(
    String url,
    String ipfsHash,
    int ipfsLength, {
    Map<String, dynamic>? headerParams,
    Function(int, int)? onProgress,
    Function(Uint8List)? onSuccess,
    Function(bool)? onError,
  }) async {
    // header
    Map<String, dynamic> headers = {
      // Headers.contentLengthHeader: ipfsLength,
    }..addAll(headerParams ?? Map());

    // http
    Response? response;
    try {
      int lastProgress = 0;
      response = await _dio.post(
        url,
        queryParameters: {'arg': ipfsHash},
        options: Options(headers: headers, responseType: ResponseType.bytes),
        onReceiveProgress: (count, total) {
          if ((count - lastProgress) > 1000) {
            lastProgress = count;
            int totalCount = (total > 0) ? total : ipfsLength;
            logger.v("$TAG - _downloadFile - onReceiveProgress - count:$count - total:$totalCount");
            onProgress?.call(totalCount, count);
          }
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
      onError?.call(true);
      return null;
    } catch (e, st) {
      handleError(e, st);
      onError?.call(true);
      return null;
    }

    // response
    Uint8List? responseData = response.data;
    if ((responseData == null) || (responseData.isEmpty)) {
      logger.e("$TAG - _downloadFile - fail - state_code:${response.statusCode} - state_msg:${response.statusMessage} - url:$url - options:${response.requestOptions}");
      onError?.call(response.statusCode != 200);
      return null;
    }
    logger.i("$TAG - _downloadFile - success - state_code:${response.statusCode} - state_msg:${response.statusMessage} - url:$url - options:${response.requestOptions}");
    onSuccess?.call(responseData); // await
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
