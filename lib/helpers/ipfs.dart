import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

class IpfsHelper with Tag {
  static List<String> _writeableGateway = [
    'infura-ipfs.io:5001',
    // 'ipfs.infura.io:5001', // vpn
    // 'dweb.link:5001', // only read
    // 'cf-ipfs.com:5001', // only read
  ];

  static List<String> _readableGateway = [
    'infura-ipfs.io:5001',
    'cf-ipfs.com:5001',
    // 'dweb.link', // vpn
    // 'ipfs.infura.io', // vpn
    // 'ipfs.io', // vpn
    // 'gateway.ipfs.io' // disable
    // 'cloudflare-ipfs.com', // disable
  ];

  static const String _upload_address = "api/v0/add";
  static const String _download_address = "api/v0/cat";
  static const String _peers = "api/v0/swarm/peers"; // TODO:GG 有用吗？包括其他没考虑进来的

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

  void uploadFile(
    String id,
    String filePath, {
    bool encrypt = true,
    bool base64 = false,
    Function(String, double)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) {
    if (base64) {
      // TODO:GG base64
    }
    if (encrypt) {
      // TODO:GG 加密
    }

    // http
    _uploadFile(
      id,
      filePath,
      onProgress: (msgId, total, count) {
        double percent = total > 0 ? (count / total) : -1;
        onProgress?.call(msgId, percent);
      },
      onSuccess: (msgId, result) => onSuccess?.call(msgId, result),
      onError: (msgId) => onError?.call(msgId),
    );
  }

  void downloadFile(
    String id,
    String ipfsHash,
    int ipfsLength,
    String savePath, {
    bool encrypt = true,
    bool base64 = false,
    Function(String, double)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) {
    if (base64) {
      // TODO:GG base64
    }
    if (encrypt) {
      // TODO:GG 加密
    }

    // http
    _downloadFile(
      id,
      ipfsHash,
      ipfsLength,
      savePath,
      onProgress: (msgId, total, count) {
        double percent = total > 0 ? (count / total) : -1;
        onProgress?.call(msgId, percent);
      },
      onSuccess: (msgId, result) => onSuccess?.call(msgId, result),
      onError: (msgId) => onError?.call(msgId),
    );
  }

  Future<Map<String, dynamic>?> _uploadFile(
    String id,
    String filePath, {
    Function(String, int, int)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      onError?.call("file no exist");
      return null;
    }
    String ipAddress = await _getGateway2Write();

    // http
    Response? response;
    try {
      response = await _dio.post(
        'https://$ipAddress/$_upload_address',
        data: FormData.fromMap({'path': MultipartFile.fromFileSync(filePath)}),
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
      logger.w("$TAG - uploadFile - fail - code:${response?.statusCode} - msg:${response?.statusMessage}");
      onError?.call("response is null");
      return null;
    }
    logger.i("$TAG - uploadFile - success - code:${response.statusCode} - msg:${response.statusMessage} - result:$results");

    // result
    results["id"] = id;
    onSuccess?.call(id, results); // await
    return results;
  }

  Future<Map<String, dynamic>?> _downloadFile(
    String id,
    String ipfsHash,
    int ipfsLength,
    String savePath, {
    Function(String, int, int)? onProgress,
    Function(String, Map<String, dynamic>)? onSuccess,
    Function(String)? onError,
  }) async {
    if (ipfsHash.isEmpty || savePath.isEmpty) {
      onError?.call("hash is empty");
      return null;
    }
    String ipAddress = await _getGateway2Read();

    // http
    Response? response;
    try {
      response = await _dio.post(
        'https://$ipAddress/$_download_address',
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
      logger.w("$TAG - _downloadFile - fail - code:${response?.statusCode} - msg:${response?.statusMessage}");
      onError?.call("response is null");
      return null;
    }
    logger.i("$TAG - _downloadFile - success - code:${response.statusCode} - msg:${response.statusMessage} - options:${response.requestOptions}");

    // save
    try {
      File file = File(savePath);
      if (!file.existsSync()) {
        await file.create(recursive: true);
      } else {
        await file.delete();
        await file.create(recursive: true);
      }
      await file.writeAsBytes(responseData, flush: true);
    } catch (e) {
      handleError(e);
    }

    // result
    Map<String, dynamic> results = Map();
    results["id"] = id;
    results["path"] = savePath;
    results["ipfsHash"] = ipfsHash;
    onSuccess?.call(id, results); // await
    return results;
  }

  Future encryption() async {
    //
  }

  Future decrypt() async {
    //
  }
}
