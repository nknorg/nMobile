import 'package:dio/dio.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/news.dart';

class Api {
  Dio dio;

  Api() {
    BaseOptions options = new BaseOptions(
      baseUrl: "https://www.xx.com/api",
      connectTimeout: 5000,
      receiveTimeout: 3000,
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
      list.add(NewsSchema(
          title: item['title'],
          image: item['image_url'] ?? '',
          time: item['created_at'],
          desc: item['fancy_title'],
          author: item['last_poster_username'],
          newsId: item['id'],
          readedCount: item['views']));
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
      list.add(NewsSchema(
          title: item['title'],
          image: item['image_url'] ?? '',
          time: item['created_at'],
          desc: item['fancy_title'],
          author: item['last_poster_username'],
          newsId: item['id'],
          readedCount: item['views']));
    }
    return list;
  }
}
