class NewsSchema {
  String title;
  String image;
  String time;
  String desc;
  String author;
  num newsId;
  num readedCount;

  NewsSchema(
      {this.title,
      this.image,
      this.time,
      this.desc,
      this.author,
      this.newsId,
      this.readedCount});

  NewsSchema.fromJson(Map v) {
    title = v['title'];
    image = v['image'];
    time = v['time'];
    desc = v['desc'];
    author = v['author'];
    newsId = v['newsId'];
    readedCount = v['readedCount'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['title'] = this.title;
    data['image'] = this.image;
    data['time'] = this.time;
    data['desc'] = this.desc;
    data['author'] = this.author;
    data['newsId'] = this.newsId;
    data['readedCount'] = this.readedCount;
    return data;
  }
}
