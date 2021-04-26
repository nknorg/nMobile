
import 'dart:io';

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
