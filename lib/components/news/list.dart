import 'package:flutter/material.dart';
import 'package:nmobile/components/news/item.dart';
import 'package:nmobile/schemas/news.dart';

class NewsList extends StatelessWidget {
  final List<NewsSchema> _newsSchemas;

  NewsList(this._newsSchemas);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      itemCount: this._newsSchemas.length,
      itemBuilder: (BuildContext context, int index) {
        return NewsListItem(_newsSchemas[index]);
      },
    );
  }

}
