import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/contact_io.dart';
import 'package:nmobile/helpers/error.dart';

class ContactHomeEmptyLayout extends BaseStateFulWidget {
  @override
  _ContactHomeEmptyLayoutState createState() => _ContactHomeEmptyLayoutState();
}

class _ContactHomeEmptyLayoutState extends BaseStateFulWidgetState<ContactHomeEmptyLayout> {
  @override
  void onRefreshArguments() {}

  Future<void> _importContacts() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: Platform.isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: Platform.isAndroid ? null : ["json"],
      );
      if (result == null || result.files.isEmpty) return;
      String? path = result.files.first.path;
      if (path == null) return;
      File picked = File(path);
      if (!path.toLowerCase().endsWith('.json')) {
        if (!mounted) return;
        Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: Settings.appContext));
        return;
      }
      if (!await picked.exists()) {
        if (!mounted) return;
        Toast.show(Settings.locale((s) => s.file_not_exist, ctx: Settings.appContext));
        return;
      }
      Loading.show();
      int imported = await ContactIO.importContactsFromJsonFile(picked);
      Loading.dismiss();
      if (!mounted) return;
      Toast.show('${Settings.locale((s) => s.success, ctx: Settings.appContext)} ($imported)');
    } catch (e, st) {
      Loading.dismiss();
      handleError(e, st);
      if (!mounted) return;
      Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: Settings.appContext));
    }
  }

  @override
  Widget build(BuildContext context) {
    double imgSize = Settings.screenWidth() / 2;

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        title: Settings.locale((s) => s.my_contact, ctx: context),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, ContactAddScreen.routeName);
            },
            icon: Asset.iconSvg(
              'user-plus',
              // color: application.theme.backgroundLightColor,
              width: 24,
            ),
          ),
          PopupMenuButton<int>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: Asset.iconSvg('more', width: 24),
            onSelected: (int result) {
              if (result == 1) {
                _importContacts();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 1,
                child: Label(Settings.locale((s) => s.import_contacts, ctx: context), type: LabelType.display),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Asset.image("contact/no-contact.png", width: imgSize, height: imgSize),
              SizedBox(height: 30),
              Column(
                children: <Widget>[
                  Label(
                    Settings.locale((s) => s.contact_no_contact_title, ctx: context),
                    type: LabelType.h2,
                    textAlign: TextAlign.center,
                    maxLines: 10,
                  ),
                  SizedBox(height: 50),
                  Label(
                    Settings.locale((s) => s.contact_no_contact_desc, ctx: context),
                    type: LabelType.bodySmall,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 10,
                  )
                ],
              ),
              SizedBox(height: 96),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Button(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Asset.iconSvg('user-plus', color: application.theme.backgroundLightColor, width: 24),
                            SizedBox(width: 24),
                            Label(
                              Settings.locale((s) => s.add_contact, ctx: context),
                              type: LabelType.h3,
                              color: application.theme.fontLightColor,
                            )
                          ],
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, ContactAddScreen.routeName);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
