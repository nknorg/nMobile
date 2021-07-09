import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:photo_view/photo_view.dart';

class PhotoScreen extends BaseStateFulWidget {
  static final String routeName = "/photo";
  static final String argFilePath = "file_path";
  static final String argNetUrl = "net_url";

  static Future go(BuildContext context, {String? filePath, String? netUrl}) {
    if ((filePath == null || filePath.isEmpty) && (netUrl == null || netUrl.isEmpty)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argFilePath: filePath,
      argNetUrl: netUrl,
    });
  }

  final Map<String, dynamic>? arguments;

  PhotoScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends BaseStateFulWidgetState<PhotoScreen> with SingleTickerProviderStateMixin {
  static const int TYPE_FILE = 1;
  static const int TYPE_NET = 2;

  int? _contentType;
  String? _content;

  @override
  void onRefreshArguments() {
    String? filePath = widget.arguments![PhotoScreen.argFilePath];
    String? netUrl = widget.arguments![PhotoScreen.argNetUrl];
    if (filePath != null && filePath.isNotEmpty) {
      _contentType = TYPE_FILE;
      _content = filePath;
    } else if (netUrl != null && netUrl.isNotEmpty) {
      _contentType = TYPE_NET;
      _content = netUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (this._contentType == TYPE_FILE) {
      provider = FileImage(File(this._content ?? ""));
    } else if (this._contentType == TYPE_NET) {
      provider = NetworkImage(this._content ?? "");
    }

    return Layout(
      headerColor: Colors.black,
      borderRadius: BorderRadius.zero,
      header: Header(
        backgroundColor: Colors.black,
        // TODO:GG image save to album
        // actions: [
        //   PopupMenuButton(
        //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        //     icon: Asset.iconSvg('more', width: 24),
        //     onSelected: (int result) async {
        //       switch (result) {
        //         case 0:
        //           // File file = File(widget.arguments);
        //           // print(file.path);
        //           // bool exist = await file.exists();
        //           // if (exist) {
        //           //   try {
        //           //     String name = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString();
        //           //     final Uint8List bytes = await file.readAsBytes();
        //           //     bool success = await ImageSave.saveImage(bytes, 'jpeg', albumName: name);
        //           //     if (success) {
        //           //       showToast(NL10ns.of(context).success);
        //           //     } else {
        //           //       showToast(NL10ns.of(context).failure);
        //           //     }
        //           //   } catch (e) {
        //           //     showToast(NL10ns.of(context).failure);
        //           //   }
        //           // } else {
        //           //   showToast(NL10ns.of(context).failure);
        //           // }
        //           break;
        //       }
        //     },
        //     itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        //       PopupMenuItem<int>(
        //         value: 0,
        //         child: Label(
        //           _localizations.save_to_album,
        //           type: LabelType.display,
        //         ),
        //       ),
        //     ],
        //   )
        // ],
      ),
      body: InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        child: PhotoView(
          imageProvider: provider,
        ),
      ),
    );
  }
}
