import 'dart:convert';
import 'dart:typed_data';

import 'package:common_utils/common_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:nmobile/helpers/encryption.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/news.dart';
import 'package:nmobile/tweetnacl/tweetnaclfast.dart';

import 'ed2curve.dart';
import 'utils.dart';

class Api {
  Dio dio;
  Uint8List mySecretKey;
  Uint8List myPublicKey;
  Uint8List otherPubkey;
  Uint8List sharedKey;
  Api({this.mySecretKey, this.myPublicKey, this.otherPubkey}) {
    if (mySecretKey == null && myPublicKey == null && otherPubkey == null) {
    } else {
      this.sharedKey = computeSharedKey(convertSecretKey(mySecretKey), convertPublicKey(otherPubkey));
    }

    BaseOptions options = new BaseOptions(
      connectTimeout: 30000,
      receiveTimeout: 10000,
    );
    dio = new Dio(options);
  }

  Future<List<NewsSchema>> getNews() async {
    var enUrl = 'https://forum.nkn.org/c/community/news.json';
    var zhUrl = 'https://forum.nkn.org/c/chinese/xinwen.json';
    Response res = await dio.get(Global.locale == 'zh' ? zhUrl : enUrl);
    var data = res.data['topic_list']['topics'];
    List<NewsSchema> list = new List<NewsSchema>();
    for (var item in data) {
      list.add(NewsSchema(title: item['title'], image: item['image_url'] ?? '', time: item['created_at'], desc: item['fancy_title'], author: item['last_poster_username'], newsId: item['id'], readedCount: item['views']));
    }

    return list;
  }

  Future<List<NewsSchema>> getBanner() async {
    var enUrl = 'https://forum.nkn.org/c/community/pinned/49.json';
    var zhUrl = 'https://forum.nkn.org/c/chinese/48-category.json';
    Response res = await dio.get(Global.locale == 'zh' ? zhUrl : enUrl);
    var data = res.data['topic_list']['topics'];
    List<NewsSchema> list = new List<NewsSchema>();
    for (var item in data) {
      list.add(NewsSchema(title: item['title'], image: item['image_url'] ?? '', time: item['created_at'], desc: item['fancy_title'], author: item['last_poster_username'], newsId: item['id'], readedCount: item['views']));
    }
    return list;
  }

  encryptData(data) {
    var nonce = randomBytes(Box.nonceLength);
    var encrypted = encrypt(utf8.encode(data), nonce, sharedKey);
    return base64.encode(nonce + encrypted);
  }

  decryptData(data) {
    Uint8List dataBase64 = base64.decode(data);
    var nonce = dataBase64.sublist(0, Box.nonceLength);
    var message = dataBase64.sublist(Box.nonceLength);
    var decrypted = decrypt(message, nonce, sharedKey);
    return utf8.decode(decrypted);
  }

  Future get(url) async {
    try {
      Response res = await dio.get(url);
      if (res.statusCode >= 200 && res.statusCode < 300 && res.data != null) {
        return res.data;
      }
    } catch (e) {
      print(e);
    }
  }

  Future post(url, data, {bool isEncrypted}) async {
//    LogUtil.v(data);
    if (isEncrypted) {
      var encData = encryptData(jsonEncode(data));
      try {
        var params = {'pub_key': hexEncode(myPublicKey), 'data': encData};
        LogUtil.v(params);
        Response res = await dio.post(
          url,
          data: params,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            contentType: 'application/json',
            validateStatus: (_) => true,
          ),
        );
        if (res.statusCode >= 200 && res.statusCode < 300 && res.data != null) {
          var msg;
          LogUtil.v(res);
          if (res.data is String) {
            msg = decryptData(res.data);
          } else {
            if (res.data['success'] && res.data['result'] != null) {
              msg = decryptData(res.data['result']);
              LogUtil.v(msg);
            }
          }

          return jsonDecode(msg);
        } else {
          LogUtil.v('===========');
        }
      } catch (e) {
        debugPrintStack();
        print(e);
      }
    } else {
      try {
        Response res = await dio.post(url, data: data);
        if (res.statusCode >= 200 && res.statusCode < 300 && res.data != null) {
          return res.data;
        }
      } catch (e) {
        print(e);
      }
    }
  }
}
