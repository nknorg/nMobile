import 'dart:async';

class _QueuedFuture<T> {
  final String? id;
  final Future<T?> Function() func;
  final Completer completer;
  final Duration? timeout;
  Function? onComplete;

  _QueuedFuture(this.id, this.func, this.completer, {this.timeout, this.onComplete});

  bool _timedOut = false;

  Future<void> execute() async {
    try {
      T? result;
      Timer? timeoutTimer;
      if (timeout != null) {
        timeoutTimer = Timer(timeout!, () {
          _timedOut = true;
          onComplete?.call();
        });
      }
      result = await func();
      timeoutTimer?.cancel();
      completer.complete(result);
      await Future.microtask(() {});
    } catch (e) {
      completer.completeError(e);
    } finally {
      if (!_timedOut) onComplete?.call();
    }
  }
}

class ParallelQueue {
  final List<_QueuedFuture> _queues = [];
  final List<Completer<void>> _completeListeners = [];

  final List<String> _delays = [];
  final List<String> _delaysDel = [];

  final String tag;
  final Function(String, bool)? onLog;

  int parallel;
  int _lastProcessId = 0;
  Set<int> activeItems = {};

  final Duration? interval;
  final Duration? timeout;

  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  ParallelQueue(this.tag, {this.parallel = 1, this.interval, this.timeout, this.onLog});

  int get length => _delays.length + _queues.length;

  Future get onComplete {
    final completer = Completer();
    _completeListeners.add(completer);
    return completer.future;
  }

  void cancel() {
    _isCancelled = true;
    _queues.removeWhere((item) => item.completer.isCompleted);
  }

  Future<T?> add<T>(Future<T?> Function() func, {String? id, Duration? delay, bool priority = false}) async {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - add - isCancelled - tag:$tag", true);
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
      _queues.insert(0, item);
    } else {
      _queues.add(item);
    }
    unawaited(_process());
    return await completer.future;
  }

  bool deleteDelays(String id) {
    bool deleted = false;
    _delays.removeWhere((element) {
      deleted = (element == id) || deleted;
      return deleted;
    });
    _delaysDel.add(id);
    return deleted;
  }

  bool contains(String id) {
    bool find = false;
    _delays.forEach((element) {
      find = (element == id) || find;
    });
    _queues.forEach((element) {
      find = (element.id == id) || find;
    });
    return find;
  }

  Future<void> _process() async {
    if (activeItems.length < parallel) {
      _onQueueNext();
    } else {
      this.onLog?.call("ParallelQueue - _process - on next full - tag:$tag - parallel:$parallel - actives:${activeItems.length}", false);
    }
  }

  void _onQueueNext() {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next cancel - tag:$tag", true);
    } else if (_queues.isNotEmpty && (activeItems.length < parallel)) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next ok - tag:$tag - parallel:$parallel - actives:${activeItems.length}", false);
      final processId = _lastProcessId;
      activeItems.add(processId);
      final item = _queues.first;
      _lastProcessId++;
      _queues.remove(item);
      item.onComplete = () async {
        this.onLog?.call("ParallelQueue - _onQueueNext - on next complete - tag:$tag - id:${item.id}", false);
        activeItems.remove(processId);
        if (interval != null) await Future.delayed(interval!);
        _onQueueNext();
      };
      unawaited(item.execute());
    } else if (activeItems.isEmpty && _queues.isEmpty) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next complete all - tag:$tag", false);
      for (final completer in _completeListeners) {
        if (completer.isCompleted != true) {
          completer.complete();
        }
      }
      _completeListeners.clear();
    }
  }
}

// Don't throw analysis error on unawaited future.
void unawaited(Future<void> future) {}
