import 'dart:io';

@deprecated
Future<double> getTotalSizeOfCacheFile(final FileSystemEntity file) async {
  if (file is File) {
    int length = await file.length();
    return double.tryParse(length.toString()) ?? 0;
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    double total = 0;
    for (final FileSystemEntity child in children) {
      if (RegExp(r'[0-9a-f]{64}(/[^/]+)?$').hasMatch(child.path) || (child.path == "cache")) {
        total += await getTotalSizeOfCacheFile(child);
      }
    }
    return total;
  }
  return 0;
}

@deprecated
Future<double> getTotalSizeOfDbFile(final FileSystemEntity file) async {
  if (file is File) {
    int length = await file.length();
    return double.tryParse(length.toString()) ?? 0;
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    double total = 0;
    for (final FileSystemEntity child in children) {
      if (RegExp(r'.*\.db$').hasMatch(child.path)) {
        total += await getTotalSizeOfCacheFile(child);
      }
    }
    return total;
  }
  return 0;
}

@deprecated
Future<void> clearCacheFile(final FileSystemEntity file) async {
  if (file is File) {
    await file.delete();
  }
  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    for (final FileSystemEntity child in children) {
      if (RegExp(r'[0-9a-f]{64}(/[^/]+)?$').hasMatch(child.path) || (child.path == "cache")) {
        await clearCacheFile(child);
      }
    }
  }
}

@deprecated
Future<void> clearDbFile(final FileSystemEntity file) async {
  if (file is File) {
    await file.delete();
  }

  if (file is Directory) {
    final List<FileSystemEntity> children = file.listSync();
    for (final FileSystemEntity child in children) {
      if (RegExp(r'.*\.db$').hasMatch(child.path)) {
        await clearDbFile(child);
      }
    }
  }
}
