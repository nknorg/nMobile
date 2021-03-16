import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/schemas/news.dart';

class NewsListItem extends StatelessWidget {
  final NewsSchema _newsSchema;

  NewsListItem(this._newsSchema);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.network(
        _newsSchema.image,
        width: 100,
      ),
      title: Text(_newsSchema.title),
      subtitle: Text(
          DateFormat('yyyy-MM-dd').format(DateTime.parse(_newsSchema.time))),
      onTap: () => {},
    );
  }
}
