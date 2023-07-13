import 'dart:async';

class _QueuedFuture<T> {
  final String? id;
  final Future<T?> Function() func;
  final Completer completer;
  final Duration? timeout;
  Function(bool)? onComplete;

  _QueuedFuture(this.id, this.func, this.completer, {this.timeout, this.onComplete});

  bool _timedOut = false;

  Future<void> execute() async {
    try {
      T? result;
      Timer? timeoutTimer;
      if (timeout != null) {
        timeoutTimer = Timer(timeout!, () {
          _timedOut = true;
          onComplete?.call(true);
        });
      }
      result = await func();
      timeoutTimer?.cancel();
      completer.complete(result);
      await Future.microtask(() {});
    } catch (e) {
      completer.completeError(e);
    } finally {
      if (!_timedOut) onComplete?.call(false);
    }
  }
}

class ParallelQueue {
  final List<_QueuedFuture> _queue = [];
  final Map<String, Completer<void>> _completeListeners = {};

  final List<String> _delays = [];
  final List<String> _delaysDel = [];

  final String tag;
  final Function(String, bool)? onLog;

  int parallel;
  int _lastProcessId = 0;
  Set<int> _activeItems = {};

  final Duration? interval;
  final Duration? timeout;

  bool _isPause = false;
  bool get isPause => _isPause;

  ParallelQueue(this.tag, {this.parallel = 1, this.interval, this.timeout, this.onLog});

  int get length => _delays.length + _queue.length + _activeItems.length;

  Future onComplete(String key, {bool completeWhenEmpty = true}) {
    if ((length <= 0) && completeWhenEmpty) {
      return Future.delayed(Duration(seconds: 0));
    }
    Completer? completer = _completeListeners[key];
    if (completer == null) {
      completer = Completer();
      _completeListeners[key] = completer;
    }
    if ((length <= 0) && completeWhenEmpty) {
      return Future.delayed(Duration(seconds: 0));
    }
    return completer.future;
  }

  bool isOnComplete(String key) {
    return _completeListeners[key] != null;
  }

  void run({bool clear = false}) {
    this.onLog?.call("ParallelQueue - run - clear:$clear - tag:$tag - lastProcessId:$_lastProcessId - actives:${_activeItems.length} - queues:${_queue.length} - parallel:$parallel", false);
    _isPause = false;
    if (clear) {
      _lastProcessId = 0;
      _activeItems.clear();
      _queue.clear();
      _delays.clear();
      _delaysDel.clear();
    }
    unawaited(_process());
  }

  void pause() {
    this.onLog?.call("ParallelQueue - pause - tag:$tag - lastProcessId:$_lastProcessId - actives:${_activeItems.length} - queues:${_queue.length} - parallel:$parallel", false);
    _isPause = true;
    _queue.removeWhere((item) => item.completer.isCompleted);
  }

  Future<T?> add<T>(Future<T?> Function() func, {String? id, Duration? delay, bool priority = false}) async {
    if (isPause) {
      this.onLog?.call("ParallelQueue - add - isPause - tag:$tag", true);
      return null;
    }
    if (id != null && id.isNotEmpty && delay != null) {
      _delays.add(id);
      await Future.delayed(delay);
      if (_delaysDel.contains(id)) {
        _delaysDel.remove(id);
        return null;
      } else if (_delays.contains(id)) {
        _delays.remove(id);
      } else {
        return null;
      }
    }
    final completer = Completer<T?>();
    final item = _QueuedFuture<T>(id, func, completer, timeout: timeout);
    if (priority) {
      if (_queue.length > 0) {
        _queue.insert(1, item);
      } else {
        _queue.insert(0, item);
      }
    } else {
      _queue.add(item);
    }
    unawaited(_process());
    return await completer.future;
  }

  bool contains(String id) {
    bool find = false;
    _delays.forEach((element) {
      find = (element == id) || find;
    });
    _queue.forEach((element) {
      find = (element.id == id) || find;
    });
    return find;
  }

  void deleteDelays(String id) {
    _delays.removeWhere((element) {
      return element == id;
    });
    _delaysDel.add(id);
  }

  void delete(String id) {
    deleteDelays(id);
    _queue.removeWhere((element) {
      return element.id == id;
    });
  }

  Future<void> _process() async {
    if (_activeItems.length < parallel) {
      while (true) if (!(await _onQueueNext())) break;
    } else {
      this.onLog?.call("ParallelQueue - _process - full - tag:$tag - parallel:$parallel - actives:${_activeItems.length}", false);
    }
  }

  Future<bool> _onQueueNext() async {
    if (isPause) {
      this.onLog?.call("ParallelQueue - _onQueueNext - isPause - tag:$tag - lastProcessId:$_lastProcessId", true);
      return false;
    } else if (_queue.isNotEmpty && (_activeItems.length < parallel)) {
      this.onLog?.call("ParallelQueue - _onQueueNext - run - tag:$tag - lastProcessId:$_lastProcessId - actives:${_activeItems.length} - queues:${_queue.length} - parallel:$parallel", false);
      final item = _queue.first;
      _queue.remove(item);
      if (_lastProcessId >= 2147483640) _lastProcessId = 0;
      final processId = _lastProcessId;
      _activeItems.add(processId);
      _lastProcessId++;
      Completer c = Completer();
      item.onComplete = (timeout) async {
        _activeItems.remove(processId);
        this.onLog?.call("ParallelQueue - _onQueueNext - ${timeout ? "timeout" : "complete"} - tag:$tag - _lastProcessId:$_lastProcessId - actives:${_activeItems.length} - queues:${_queue.length} - id:${item.id}", timeout);
        if (interval != null) await Future.delayed(interval!);
        c.complete();
      };
      unawaited(item.execute());
      await c.future;
      return true;
    } else if (_activeItems.isEmpty && _queue.isEmpty) {
      this.onLog?.call("ParallelQueue - _onQueueNext - total_complete - tag:$tag - _lastProcessId:$_lastProcessId", false);
      _completeListeners.forEach((key, value) {
        if (value.isCompleted != true) {
          value.complete();
        }
      });
      _completeListeners.clear();
      return !(_activeItems.isEmpty && _queue.isEmpty);
    } else {
      this.onLog?.call("ParallelQueue - _onQueueNext - continue - tag:$tag - _lastProcessId:$_lastProcessId - actives:${_activeItems.length} - queues:${_queue.length}", false);
    }
    return false;
  }
}

// Don't throw analysis error on unawaited future.
void unawaited(Future<void> future) {}
