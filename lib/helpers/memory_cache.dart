import 'dart:async';

class CacheEntry {
  int? invalid;
  String key;
  dynamic val;

  CacheEntry({required this.key, required this.val, this.invalid});
}

class MemoryCache {
  static const String KEY_DRAFT = 'draft';

  // ignore: close_sinks
  StreamController<String> _draftUpdateController = StreamController<String>.broadcast();
  StreamSink<String> get _draftUpdateSink => _draftUpdateController.sink;
  Stream<String> get draftUpdateStream => _draftUpdateController.stream;

  Map<String, CacheEntry> _cacheMap = {};

  MemoryCache();

  put(String key, dynamic value) {
    CacheEntry cacheEntry = CacheEntry(key: key, val: value, invalid: 0);
    _cacheMap[key] = cacheEntry;
  }

  get(String key) {
    CacheEntry? cacheEntry = _cacheMap[key];
    if (cacheEntry == null) {
      return null;
    }
    return cacheEntry.val;
  }

  remove(String key) {
    _cacheMap.remove(key);
  }

  // draft
  getDraft(String? targetId) {
    if (targetId == null) return null;
    return get('$targetId:$KEY_DRAFT');
  }

  setDraft(String? targetId, String draft) {
    if (targetId == null) return;
    put('$targetId:$KEY_DRAFT', draft);
    _draftUpdateSink.add(targetId);
  }

  removeDraft(String? targetId) {
    if (targetId == null) return;
    remove('$targetId:$KEY_DRAFT');
    _draftUpdateSink.add(targetId);
  }
}
