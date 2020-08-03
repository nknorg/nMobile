import 'dart:io';
import 'dart:typed_data';

import 'package:bs58check/bs58check.dart';
import 'package:common_utils/common_utils.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/tweetnacl/tweetnaclfast.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/credentials.dart';

const ADDRESS_GEN_PREFIX = '02b825';
const ADDRESS_GEN_PREFIX_LEN = ADDRESS_GEN_PREFIX.length ~/ 2;
const UINT160_LEN = 20;
const CHECKSUM_LEN = 4;

const SEED_LENGTH = 32;

const ADDRESS_LEN = ADDRESS_GEN_PREFIX_LEN + UINT160_LEN + CHECKSUM_LEN;

String hexEncode(List<int> raw) {
  return hex.encode(raw).toLowerCase();
}

List<int> hexDecode(String s) {
  return hex.decode(s);
}

Uint8List randomBytes([len = SEED_LENGTH]) {
  return TweetNaclFast.randombytes(len);
}

String getPublicKeyByClientAddr(String addr) {
  int n = addr.lastIndexOf('.');
  if (n < 0) {
    return addr;
  } else {
    return addr.substring(n + 1);
  }
}

String addressStringToProgramHash(String address) {
  var addressBytes = base58.decode(address);
  var programHashBytes = addressBytes.sublist(ADDRESS_GEN_PREFIX_LEN, addressBytes.length - CHECKSUM_LEN);
  return hexEncode(programHashBytes);
}

String getAddressStringVerifyCode(String address) {
  var addressBytes = base58.decode(address);
  var verifyBytes = addressBytes.sublist(addressBytes.length - CHECKSUM_LEN);

  return hexEncode(verifyBytes);
}

List<int> genAddressVerifyBytesFromProgramHash(String programHash) {
  programHash = ADDRESS_GEN_PREFIX + programHash;
  var verifyBytes = doubleSha256Hex(programHash);
  return verifyBytes.sublist(0, CHECKSUM_LEN);
}

String genAddressVerifyCodeFromProgramHash(String programHash) {
  var verifyBytes = genAddressVerifyBytesFromProgramHash(programHash);
  return hexEncode(verifyBytes);
}

bool verifyAddress(String address) {
  try {
    List addressBytes = base58.decode(address);
    if (addressBytes.length != ADDRESS_LEN) {
      return false;
    }
    var addressPrefixBytes = addressBytes.sublist(0, ADDRESS_GEN_PREFIX_LEN);
    var addressPrefix = hexEncode(addressPrefixBytes);
    if (addressPrefix != ADDRESS_GEN_PREFIX) {
      return false;
    }
    var programHash = addressStringToProgramHash(address);
    var addressVerifyCode = getAddressStringVerifyCode(address);
    var programHashVerifyCode = genAddressVerifyCodeFromProgramHash(programHash);
    return addressVerifyCode == programHashVerifyCode;
  } catch (e) {
    return false;
  }
}

bool isValidEthAddress(String address) {
  try {
    EthereumAddress.fromHex(address);
    return true;
  }catch (e) {
    return false;
  }
}

Future<File> compressAndGetFile(String accountPubkey, File file) async {
  final dir = Global.applicationRootDirectory;

  final targetPath = createRandomWebPFile(accountPubkey);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  var result = await FlutterImageCompress.compressAndGetFile(file.absolute.path, targetPath, quality: 30, minWidth: 640, minHeight: 1024, format: CompressFormat.jpeg);
  return result;
}

String createRandomWebPFile(String accountPubkey) {
  var value = new DateTime.now().millisecondsSinceEpoch.toString();
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  String path = join(rootDir.path, dir.path, value.toString() + '_temp.jpeg');
  return path;
}

String createFileCachePath(String accountPubkey, File file) {
  String name = hexEncode(md5.convert(file.readAsBytesSync()).bytes);
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  String fullName = file?.path?.split('/')?.last;
  String fileExt;
  int index = fullName.lastIndexOf('.');
  if (index > -1) {
    fileExt = fullName?.split('.')?.last;
  }
  String path = join(rootDir.path, dir.path, name + '.' + fileExt);
  return path;
}

String createContactFilePath(String accountPubkey, File file) {
  String name = hexEncode(md5.convert(file.readAsBytesSync()).bytes);
  Directory rootDir = Global.applicationRootDirectory;
  String p = join(rootDir.path, accountPubkey, 'contact');
  Directory dir = Directory(p);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  } else {}
  String fullName = file?.path?.split('/')?.last;
  String fileExt;
  int index = fullName.lastIndexOf('.');
  if (index > -1) {
    fileExt = fullName?.split('.')?.last;
  }
  String path = join(rootDir.path, dir.path, name + '.' + fileExt);
  return path;
}

String getCachePath(String accountPubkey) {
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
}

String getContactCachePath(String accountPubkey) {
  String root = getCachePath(accountPubkey);
  Directory dir = Directory(join(root, 'contact'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
}

String getTmpPath() {
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, 'tmp'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
}

String getFileName(String path) {
  return path?.split('/')?.last;
}

String getLocalPath(String accountPubkey, String path) {
  return join(accountPubkey, getFileName(path));
}

String getLocalContactPath(String accountPubkey, String path) {
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey, 'contact'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  return join(accountPubkey, 'contact', getFileName(path));
}

launchURL(String url) async {
  if (await canLaunch(url)) {
    await launch(url, forceSafariVC: false);
  } else {
    throw 'Could not launch $url';
  }
}

Future<double> getTotalSizeOfCacheFile(final FileSystemEntity file) async {
  if (file is File) {
    int length = await file.length();
    return double.parse(length.toString());
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    double total = 0;
    if (children != null)
      for (final FileSystemEntity child in children) {
        if (RegExp(r'[0-9a-f]{64}(/[^/]+)?$').hasMatch(child.path)) {
          total += await getTotalSizeOfCacheFile(child);
        }
      }
    return total;
  }
  return 0;
}

Future<void> clearCacheFile(final FileSystemEntity file) async {
  if (file is File) {
    file.deleteSync();
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    if (children != null)
      for (final FileSystemEntity child in children) {
        if (RegExp(r'[0-9a-f]{64}(/[^/]+)?$').hasMatch(child.path)) {
          await clearCacheFile(child);
        }
      }
  }
}

Future<double> getTotalSizeOfDbFile(final FileSystemEntity file) async {
  if (file is File) {
    int length = await file.length();
    return double.parse(length.toString());
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    double total = 0;
    if (children != null)
      for (final FileSystemEntity child in children) {
        if (RegExp(r'.*\.db$').hasMatch(child.path)) {
          total += await getTotalSizeOfCacheFile(child);
        }
      }
    return total;
  }
  return 0;
}

Future<void> clearDbFile(final FileSystemEntity file) async {
  if (file is File) {
    file.deleteSync();
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    if (children != null)
      for (final FileSystemEntity child in children) {
        if (RegExp(r'.*\.db$').hasMatch(child.path)) {
          await clearDbFile(child);
        }
      }
  }
}

Duration blockToExpiresTime(int blockCount) {
  int dayInSeconds = 86400;
  int totalSeconds = dayInSeconds ~/ 4000 * blockCount;
  return Duration(seconds: totalSeconds);
}

bool isPrivateTopic(String topic) {
  if (RegExp(r'\.[0-9a-f]{64}$').hasMatch(topic)) {
    return true;
  }
  return false;
}

String getOwnerPubkeyByTopic(String topic) {
  int index = topic.lastIndexOf('.');
  if (index > -1) {
    return topic.substring(index + 1);
  }
  return null;
}

DateTime getStartOfDay(DateTime time) {
  String formattedDate = DateUtil.formatDate(time, isUtc: false, format: 'yyyy-MM-dd');
  DateTime newDate = DateTime.parse(formattedDate);
  return newDate;
}

DateTime getEndOfDay(DateTime time) {
  String formattedDate = DateUtil.formatDate(time, isUtc: false, format: 'yyyy-MM-dd');
  DateTime newDate = DateTime.parse(formattedDate + " 23:59:59");
  return newDate;
}

int getTimestampLatest(bool phase, int day) {
  String newHours;
  DateTime now = new DateTime.now();
  DateTime sixtyDaysFromNow = now.add(new Duration(days: day));
  String formattedDate = DateUtil.formatDate(sixtyDaysFromNow, isUtc: false, format: 'yyyy-MM-dd');
  if (phase) {
    newHours = formattedDate + ' 00:00:00';
  } else {
    newHours = formattedDate + ' 23:59:59';
  }

  DateTime newDate = DateTime.parse(newHours);
//  String newFormattedDate = DateUtil.formatDate(newDate,
//      isUtc: false, format: 'yyyy-MM-dd HH:mm:ss');
  int timeStamp = newDate.millisecondsSinceEpoch;
  return timeStamp;
}
