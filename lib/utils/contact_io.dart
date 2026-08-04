import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storages/contact.dart';

class ContactIO {
  /// Export all friend contacts to a JSON file.
  /// Priority: show save dialog -> Downloads (if available) -> app private dir.
  /// Returns the absolute file path if successful; otherwise null.
  static Future<String?> exportFriendsAsJson() async {
    try {
      final String fileName = 'contacts_${DateTime.now().millisecondsSinceEpoch}.json';
      // 1) Build JSON content
      final String jsonText = await _buildFriendsJson();

      // 2) Try save dialog (user picks path)
      try {
        final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonText));
        String? pickedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save contacts',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes,
        );
        if (pickedPath != null && pickedPath.isNotEmpty) {
          // On Android/iOS, file has been saved by the picker using provided bytes.
          // Some platforms still return the picked path; return it for consistency.
          return pickedPath;
        }
      } catch (e, st) {
        // ignore and fallback
        handleError(e, st);
      }

      // 3) Try system Downloads (Desktop/macOS/Windows; may be null on mobile)
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          final savePath = p.join(dir.path, fileName);
          final out = File(savePath);
          if (!await out.exists()) {
            await out.create(recursive: true);
          }
          await out.writeAsString(jsonText, flush: true);
          return out.path;
        }
      } catch (e, st) {
        // ignore and fallback
        handleError(e, st);
      }

      // 4) Fallback to app private dir
      String filePath = await Path.createFile(
        clientCommon.getPublicKey(),
        DirType.download,
        fileName.replaceAll('.json', ''),
        fileExt: 'json',
      );
      File file = File(filePath);
      await file.writeAsString(jsonText, flush: true);
      return file.path;
    } catch (e, st) {
      handleError(e, st);
      return null;
    }
  }

  static Future<String> _buildFriendsJson() async {
    const int pageSize = 200;
    List<ContactSchema> friends = [];
    for (int offset = 0; true; offset += pageSize) {
      List<ContactSchema> result = await contactCommon.queryList(type: ContactType.friend, offset: offset, limit: pageSize);
      friends.addAll(result);
      if (result.length < pageSize) break;
    }
    List<Map<String, dynamic>> items = friends.map((e) => e.toMap()).toList();
    Map<String, dynamic> exportPayload = {
      "version": 1,
      "type": "contacts",
      "count": items.length,
      "items": items,
    };
    return const JsonEncoder.withIndent('  ').convert(exportPayload);
  }

  /// Import contacts from a JSON file previously exported by [exportFriendsAsJson].
  /// Merge strategy:
  /// - If address not exists: add as friend
  /// - If exists: update fields (type->friend, names, remark, wallet, top, options, data merge)
  /// Returns the number of contacts added or changed.
  static Future<int> importContactsFromJsonFile(File? file) async {
    if (file == null || !await file.exists()) return 0;
    int importedCount = 0;
    try {
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      List items = (data["items"] is List) ? (data["items"] as List) : [];
      for (var i = 0; i < items.length; i++) {
        var e = items[i];
        if (e is! Map) continue;
        try {
          ContactSchema schema = ContactSchema.fromMap(e as Map);
          if (schema.address.isEmpty) continue;
          if (schema.type == ContactType.me) continue; // skip self data
          schema.type = ContactType.friend;
          ContactSchema? exist = await contactCommon.query(schema.address, fetchWalletAddress: false);
          if (exist == null) {
            await contactCommon.add(schema, fetchWalletAddress: true, notify: true);
            importedCount++;
            continue;
          }
          bool changed = false;
          if (exist.type == ContactType.me) {
            // never modify self-contact
            continue;
          }
          if (exist.type != ContactType.friend) {
            await contactCommon.setType(schema.address, ContactType.friend, notify: true);
            changed = true;
          }
          // full name
          String newFirst = (schema.firstName.isNotEmpty) ? schema.firstName : exist.firstName;
          String newLast = (schema.lastName.isNotEmpty) ? schema.lastName : exist.lastName;
          if (newFirst != exist.firstName || newLast != exist.lastName) {
            await ContactStorage.instance.setFullName(schema.address, newFirst, newLast);
            changed = true;
          }
          // remark
          if (schema.remarkName.isNotEmpty && schema.remarkName != exist.remarkName) {
            await contactCommon.setOtherRemarkName(schema.address, schema.remarkName, notify: true);
            changed = true;
          }
          // wallet address
          if (schema.walletAddress.isNotEmpty && schema.walletAddress != exist.walletAddress) {
            await contactCommon.setWalletAddress(schema.address, schema.walletAddress, notify: true);
            changed = true;
          }
          // top
          if (schema.isTop != exist.isTop) {
            await contactCommon.setTop(schema.address, schema.isTop, notify: true);
            changed = true;
          }
          // options
          if (schema.options.notificationOpen != exist.options.notificationOpen) {
            await contactCommon.setNotificationOpen(schema.address, schema.options.notificationOpen, notify: true);
            changed = true;
          }
          if (schema.options.deleteAfterSeconds != exist.options.deleteAfterSeconds ||
              schema.options.updateBurnAfterAt != exist.options.updateBurnAfterAt) {
            await contactCommon.setOptionsBurn(schema.address, schema.options.deleteAfterSeconds, schema.options.updateBurnAfterAt, notify: true);
            changed = true;
          }
          // merge custom data (shallow add/overwrite)
          if (schema.data.isNotEmpty) {
            await ContactStorage.instance.setData(schema.address, schema.data);
            changed = true;
          }
          if (changed) importedCount++;
        } catch (e) {
          // ignore invalid
        }
      }
    } catch (e, st) {
      handleError(e, st);
    }
    return importedCount;
  }
}


